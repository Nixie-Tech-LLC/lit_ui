# Shader-First Rendering Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand lit_ui's interpolation layer beyond gradient/border/shadow by making the GLSL shader the primary rendering path, adding multi-light support, unified fill+border rendering, hemisphere ambient, normal map textures, and glass/translucency — while maintaining live-update performance.

**Architecture:** The shader evolves in 6 additive tiers. Each tier extends the uniform layout and GLSL logic without breaking the previous tier. The Canvas gradient path remains as a fallback when the shader isn't loaded. Widget painters check `LitShader.isLoaded` and delegate to the shader when available, falling back to the existing Canvas code otherwise.

**Tech Stack:** Flutter FragmentProgram API, GLSL ES (via `#include <flutter/runtime_effect.glsl>`), Skia/Impeller GPU pipeline, Flutter `BackdropFilter` (Tier 6).

**Baseline:** 99 tests passing. All work happens in `packages/lit_ui/`.

**Run commands from:** `cd packages/lit_ui` (all paths below are relative to this directory)

---

## File Structure

### New files
| File | Responsibility |
|------|---------------|
| `test/shader_trigger_test.dart` | Tests that shader triggers for material-only widgets (Tier 1) |
| `test/lit_shader_multilight_test.dart` | Tests for multi-light uniform binding (Tier 2) |
| `test/light_scene_ambient_test.dart` | Tests for LightScene ambient properties (Tier 4) |
| `test/surface_material_translucency_test.dart` | Tests for translucency property + glass preset (Tier 6) |

### Modified files
| File | Change |
|------|--------|
| `shaders/lit_surface.frag` | Tiers 1-6: multi-light loop, SDF border, ambient, normal map sampler, translucency output |
| `lib/src/lit_shader.dart` | Tiers 1-6: updated uniform layout, border/ambient/normal-map/translucency params |
| `lib/src/lit_surface.dart` | Tiers 1,3: shader triggers on material (not just profile), delegates border to shader |
| `lib/src/lit_button.dart` | Tiers 1,3: same shader trigger + border delegation |
| `lib/src/light_scene.dart` | Tier 4: ambient sky/ground color properties |
| `lib/src/surface_material.dart` | Tier 6: translucency property + glass preset |
| `lib/src/light_resolver.dart` | Tier 4: pass ambient through to ResolvedLight |
| `test/surface_material_test.dart` | Tier 6: tests for translucency + glass preset |

---

## Chunk 1: Shader as Default Fill (Tier 1)

**Why:** Currently the shader only activates when `profile != flat`. This means materials' fresnel, sheen, clearcoat, and specular concentration have *zero visual effect* on the Canvas path. By triggering the shader whenever a material is set (even with a flat profile), all 5 PBR properties become visible on every widget.

### Task 1: Update shader trigger condition in LitSurface

**Files:**
- Modify: `lib/src/lit_surface.dart:181`

- [ ] **Step 1: Change the shader trigger condition**

The current condition at line 181 is:
```dart
if (profile != null && profile!.pattern != SurfacePattern.flat && LitShader.isLoaded) {
```

Change to: trigger the shader when *either* a material is set *or* a non-flat profile is set, and the shader is loaded:
```dart
final useShader = LitShader.isLoaded &&
    (material != null ||
     (profile != null && profile!.pattern != SurfacePattern.flat));
if (useShader) {
```

Update the `LitShader.createShader` call to use defaults when material/profile are null:
```dart
if (useShader) {
  final shader = LitShader.createShader(
    size: size,
    baseColor: baseColor,
    material: material ?? SurfaceMaterial.matte,
    profile: profile ?? SurfaceProfile.flat,
    scene: scene,
    screenCenter: screenCenter,
    curvature: curvature,
  );
```

- [ ] **Step 2: Run tests to verify nothing breaks**

Run: `flutter test`
Expected: All 99 tests pass (this is a runtime-only change — shader isn't loaded in test env, so Canvas fallback runs).

### Task 2: Update shader trigger condition in LitButton

**Files:**
- Modify: `lib/src/lit_button.dart:292`

- [ ] **Step 1: Apply the same trigger change as Task 1**

Current condition at line 292:
```dart
if (profile != null && profile!.pattern != SurfacePattern.flat && LitShader.isLoaded) {
```

Change to:
```dart
final useShader = LitShader.isLoaded &&
    (material != null ||
     (profile != null && profile!.pattern != SurfacePattern.flat));
if (useShader) {
  final shader = LitShader.createShader(
    size: size,
    baseColor: effectiveBase,
    material: material ?? SurfaceMaterial.matte,
    profile: profile ?? SurfaceProfile.flat,
    scene: scene,
    screenCenter: screenCenter,
    curvature: curvature,
  );
```

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All 99 tests pass.

### Task 3: Write tests for the new trigger logic

**Files:**
- Create: `test/shader_trigger_test.dart`

These tests verify the *logic* of when to use the shader, not the shader rendering itself (can't test GPU rendering in unit tests).

- [ ] **Step 1: Write tests**

```dart
// test/shader_trigger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

/// Tests the shader trigger logic in isolation.
/// The actual shader isn't loaded in tests, so we verify the conditions
/// that would trigger it at runtime.
void main() {
  /// Helper: returns true when the shader *would* be triggered.
  /// Mirrors the condition in _LitSurfacePainter and _LitButtonPainter.
  bool wouldUseShader({
    required bool shaderLoaded,
    SurfaceMaterial? material,
    SurfaceProfile? profile,
  }) {
    return shaderLoaded &&
        (material != null ||
         (profile != null && profile.pattern != SurfacePattern.flat));
  }

  group('Shader trigger logic', () {
    test('triggers when material is set and shader is loaded', () {
      expect(
        wouldUseShader(
          shaderLoaded: true,
          material: SurfaceMaterial.matte,
        ),
        isTrue,
      );
    });

    test('triggers when non-flat profile is set and shader is loaded', () {
      expect(
        wouldUseShader(
          shaderLoaded: true,
          profile: const SurfaceProfile.grooves(),
        ),
        isTrue,
      );
    });

    test('triggers when both material and profile are set', () {
      expect(
        wouldUseShader(
          shaderLoaded: true,
          material: SurfaceMaterial.polishedMetal,
          profile: const SurfaceProfile.dimples(),
        ),
        isTrue,
      );
    });

    test('does NOT trigger when shader is not loaded', () {
      expect(
        wouldUseShader(
          shaderLoaded: false,
          material: SurfaceMaterial.matte,
          profile: const SurfaceProfile.grooves(),
        ),
        isFalse,
      );
    });

    test('does NOT trigger when only flat profile is set (no material)', () {
      expect(
        wouldUseShader(
          shaderLoaded: true,
          profile: SurfaceProfile.flat,
        ),
        isFalse,
      );
    });

    test('does NOT trigger when nothing is set', () {
      expect(
        wouldUseShader(shaderLoaded: true),
        isFalse,
      );
    });

    test('LitShader.createShader returns null when not loaded', () {
      // Existing test, but verify it still holds with flat profile
      final result = LitShader.createShader(
        size: const Size(100, 100),
        baseColor: const Color(0xFF4488CC),
        material: SurfaceMaterial.glossy,
        profile: SurfaceProfile.flat,
        scene: LightScene.directional(angle: 0, intensity: 0.6),
        screenCenter: const Offset(50, 50),
        curvature: 0.5,
      );
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/shader_trigger_test.dart`
Expected: All pass.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: 106 tests pass (99 existing + 7 new).

- [ ] **Step 4: Update CLAUDE.md**

Add to the "Widgets" section under "Common Widget Parameters":
```
- `material` — PBR surface material; when set, the GLSL shader renders the fill even without a `profile`
```

---

## Chunk 2: Multi-Light Shader (Tier 2)

**Why:** The GLSL shader currently only receives uniforms for the first light. Borders and shadows already handle multi-light via Canvas loops, but the fill ignores lights 2-N. This creates a visible fidelity mismatch.

**Uniform layout change:** Replace the single light block (uniforms 15-21) with a 4-light array. New layout:

| Index | Name | Notes |
|-------|------|-------|
| 0-1 | uSize | unchanged |
| 2-5 | uBaseColor | unchanged |
| 6-10 | material props | unchanged |
| 11-14 | profile props | unchanged |
| 15 | uNumLights | int (0-4) |
| 16-22 | light 0 | dir.x, dir.y, intensity, color.r, color.g, color.b, color.a |
| 23-29 | light 1 | same layout |
| 30-36 | light 2 | same layout |
| 37-43 | light 3 | same layout |
| 44 | uCurvature | moved from 22 |

Total: 45 uniforms (well within Flutter's limit).

### Task 4: Rewrite the GLSL shader with multi-light loop

**Files:**
- Modify: `shaders/lit_surface.frag`

- [ ] **Step 1: Rewrite the shader**

```glsl
#version 460 core

#include <flutter/runtime_effect.glsl>

// ── Uniforms ──────────────────────────────────────────────────────────────────
// Surface
uniform vec2 uSize;
uniform vec4 uBaseColor;
// Material (PBR)
uniform float uRoughness;
uniform float uMetallic;
uniform float uFresnel;
uniform float uSheen;
uniform float uClearcoat;
// Profile
uniform float uPatternType;
uniform float uFrequency;
uniform float uAmplitude;
uniform float uAngle;
// Lights (up to 4)
uniform float uNumLights;
// Light 0
uniform vec2 uLight0Dir;
uniform float uLight0Intensity;
uniform vec4 uLight0Color;
// Light 1
uniform vec2 uLight1Dir;
uniform float uLight1Intensity;
uniform vec4 uLight1Color;
// Light 2
uniform vec2 uLight2Dir;
uniform float uLight2Intensity;
uniform vec4 uLight2Color;
// Light 3
uniform vec2 uLight3Dir;
uniform float uLight3Intensity;
uniform vec4 uLight3Color;
// Curvature
uniform float uCurvature;

out vec4 fragColor;

// ── Heightmap functions ───────────────────────────────────────────────────────

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 rotate(vec2 p, float a) {
  float ca = cos(a);
  float sa = sin(a);
  return vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
}

float heightAt(vec2 uv) {
  int pat = int(uPatternType + 0.5);
  if (pat == 0) return 0.0;

  vec2 p = rotate(uv * uSize, uAngle);
  float freq = uFrequency * 6.2832 / 100.0;

  if (pat == 1) {
    return sin(p.x * freq) * uAmplitude;
  } else if (pat == 2) {
    return sin(p.x * freq) * sin(p.y * freq) * uAmplitude;
  } else {
    float nFreq = uFrequency / 100.0;
    return (valueNoise(p * nFreq) * 2.0 - 1.0) * uAmplitude;
  }
}

vec3 normalAt(vec2 uv) {
  float eps = 1.0 / max(uSize.x, uSize.y);
  float hc = heightAt(uv);
  float hx = heightAt(uv + vec2(eps, 0.0));
  float hy = heightAt(uv + vec2(0.0, eps));
  vec3 tx = vec3(eps * uSize.x, 0.0, (hx - hc) * uCurvature);
  vec3 ty = vec3(0.0, eps * uSize.y, (hy - hc) * uCurvature);
  return normalize(cross(tx, ty));
}

// ── Per-light shading ─────────────────────────────────────────────────────────

vec3 shadeLight(vec3 N, vec3 V, vec2 lightDir, float lightIntensity, vec3 lightColor) {
  if (lightIntensity < 0.001) return vec3(0.0);

  vec3 L = normalize(vec3(lightDir, 0.6));
  vec3 H = normalize(L + V);

  // Diffuse
  float NdotL = max(dot(N, L), 0.0);
  float diffuseStrength = (1.0 - uMetallic) * NdotL * lightIntensity;

  // Specular (Blinn-Phong)
  float shininess = mix(4.0, 256.0, pow(1.0 - uRoughness, 2.0));
  float NdotH = max(dot(N, H), 0.0);
  float spec = pow(NdotH, shininess);
  float specStrength = spec * lightIntensity;
  vec3 specColor = mix(vec3(1.0), uBaseColor.rgb, uMetallic);

  // Fresnel
  float NdotV = max(dot(N, V), 0.0);
  float fresnelTerm = uFresnel * pow(1.0 - NdotV, 5.0);

  // Sheen
  float sheenTerm = uSheen * pow(1.0 - NdotV, 2.0) * lightIntensity;

  // Clearcoat
  float ccSpec = pow(NdotH, 128.0) * uClearcoat * lightIntensity;

  // Compose this light's contribution
  vec3 contrib = uBaseColor.rgb * diffuseStrength * 0.3;
  contrib += specColor * specStrength * 0.25;
  contrib += vec3(fresnelTerm * 0.1);
  contrib += uBaseColor.rgb * sheenTerm * 0.15;
  contrib += vec3(ccSpec * 0.2);

  // Tint by light color
  contrib *= mix(vec3(1.0), lightColor, lightIntensity * 0.3);

  return contrib;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  vec3 N = normalAt(uv);
  vec3 V = vec3(0.0, 0.0, 1.0);

  // Base ambient — keeps surface close to baseColor even with no lights
  vec3 litColor = uBaseColor.rgb * 0.7;

  // Accumulate contributions from all active lights
  int numLights = int(uNumLights + 0.5);

  if (numLights > 0) {
    litColor += shadeLight(N, V, uLight0Dir, uLight0Intensity, uLight0Color.rgb);
  }
  if (numLights > 1) {
    litColor += shadeLight(N, V, uLight1Dir, uLight1Intensity, uLight1Color.rgb);
  }
  if (numLights > 2) {
    litColor += shadeLight(N, V, uLight2Dir, uLight2Intensity, uLight2Color.rgb);
  }
  if (numLights > 3) {
    litColor += shadeLight(N, V, uLight3Dir, uLight3Intensity, uLight3Color.rgb);
  }

  fragColor = vec4(clamp(litColor, 0.0, 1.0), uBaseColor.a);
}
```

### Task 5: Update LitShader uniform binding for multi-light

**Files:**
- Modify: `lib/src/lit_shader.dart`

- [ ] **Step 1: Rewrite LitShader.createShader with new uniform layout**

Replace the entire `createShader` method and update the doc comment:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'light_scene.dart';
import 'surface_material.dart';
import 'surface_profile.dart';

/// Dart bridge for the `lit_surface.frag` GLSL fragment shader.
///
/// Call [load] once at app startup (e.g. in `main()` after
/// `WidgetsFlutterBinding.ensureInitialized()`). After that, use
/// [createShader] to obtain a configured [ui.FragmentShader] ready to hand
/// to a [CustomPainter].
///
/// Uniform layout (45 floats):
///
/// | Index | Name            | Source                            |
/// |-------|-----------------|-----------------------------------|
/// | 0-1   | uSize           | size.width / size.height          |
/// | 2-5   | uBaseColor      | baseColor r/g/b/a                 |
/// | 6     | uRoughness      | material.roughness                |
/// | 7     | uMetallic       | material.metallic                 |
/// | 8     | uFresnel        | material.effectiveFresnel         |
/// | 9     | uSheen          | material.effectiveSheen           |
/// | 10    | uClearcoat      | material.clearcoat                |
/// | 11    | uPatternType    | profile.pattern.index             |
/// | 12    | uFrequency      | profile.frequency                 |
/// | 13    | uAmplitude      | profile.amplitude                 |
/// | 14    | uAngle          | profile.angle                     |
/// | 15    | uNumLights      | min(scene.lights.length, 4)       |
/// | 16-22 | light 0         | dir.x, dir.y, intensity, r,g,b,a  |
/// | 23-29 | light 1         | dir.x, dir.y, intensity, r,g,b,a  |
/// | 30-36 | light 2         | dir.x, dir.y, intensity, r,g,b,a  |
/// | 37-43 | light 3         | dir.x, dir.y, intensity, r,g,b,a  |
/// | 44    | uCurvature      | curvature                         |
class LitShader {
  LitShader._();

  static ui.FragmentProgram? _program;

  /// Maximum number of lights the shader supports.
  static const maxLights = 4;

  /// Loads the fragment shader from the package asset bundle.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops once the
  /// program has been loaded successfully.
  static Future<void> load() async {
    if (_program != null) return;
    _program = await ui.FragmentProgram.fromAsset(
      'packages/lit_ui/shaders/lit_surface.frag',
    );
  }

  /// Whether [load] has been called and the shader program is ready.
  static bool get isLoaded => _program != null;

  /// Creates a [ui.FragmentShader] with all uniforms populated.
  ///
  /// Returns `null` if [load] has not been called yet (or if it failed).
  static ui.FragmentShader? createShader({
    required Size size,
    required Color baseColor,
    required SurfaceMaterial material,
    required SurfaceProfile profile,
    required LightScene scene,
    required Offset screenCenter,
    required double curvature,
  }) {
    if (_program == null) return null;

    final shader = _program!.fragmentShader();

    // ── Surface (uniforms 0-5) ──
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, baseColor.r);
    shader.setFloat(3, baseColor.g);
    shader.setFloat(4, baseColor.b);
    shader.setFloat(5, baseColor.a);

    // ── Material (uniforms 6-10) ──
    shader.setFloat(6, material.roughness);
    shader.setFloat(7, material.metallic);
    shader.setFloat(8, material.effectiveFresnel);
    shader.setFloat(9, material.effectiveSheen);
    shader.setFloat(10, material.clearcoat);

    // ── Profile (uniforms 11-14) ──
    shader.setFloat(11, profile.pattern.index.toDouble());
    shader.setFloat(12, profile.frequency);
    shader.setFloat(13, profile.amplitude);
    shader.setFloat(14, profile.angle);

    // ── Lights (uniforms 15-43) ──
    final numLights = scene.lights.length.clamp(0, maxLights);
    shader.setFloat(15, numLights.toDouble());

    for (var i = 0; i < maxLights; i++) {
      final base = 16 + i * 7;
      if (i < scene.lights.length) {
        final light = scene.lights[i];
        final dir = light.directionAt(screenCenter);
        final intensity = light.intensityAt(screenCenter);
        shader.setFloat(base + 0, dir.dx);
        shader.setFloat(base + 1, dir.dy);
        shader.setFloat(base + 2, intensity);
        shader.setFloat(base + 3, light.color.r);
        shader.setFloat(base + 4, light.color.g);
        shader.setFloat(base + 5, light.color.b);
        shader.setFloat(base + 6, light.color.a);
      } else {
        // Zero out unused light slots
        for (var j = 0; j < 7; j++) {
          shader.setFloat(base + j, 0.0);
        }
      }
    }

    // ── Curvature (uniform 44) ──
    shader.setFloat(44, curvature);

    return shader;
  }
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass (shader isn't loaded in tests, so createShader returns null).

### Task 6: Write multi-light shader tests

**Files:**
- Create: `test/lit_shader_multilight_test.dart`

- [ ] **Step 1: Write tests**

```dart
// test/lit_shader_multilight_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('LitShader multi-light', () {
    test('maxLights is 4', () {
      expect(LitShader.maxLights, 4);
    });

    test('createShader returns null when not loaded (multi-light scene)', () {
      final scene = LightScene(lights: [
        const DirectionalLight(angle: 0, intensity: 0.6),
        PointLight(
          position: const Offset(100, 100),
          height: 200,
          intensity: 0.4,
        ),
        const DirectionalLight(angle: 1.57, intensity: 0.3),
      ]);

      final result = LitShader.createShader(
        size: const Size(200, 200),
        baseColor: const Color(0xFF4488CC),
        material: SurfaceMaterial.polishedMetal,
        profile: SurfaceProfile.flat,
        scene: scene,
        screenCenter: const Offset(100, 100),
        curvature: 0.5,
      );
      expect(result, isNull);
    });

    test('createShader returns null with empty scene', () {
      final result = LitShader.createShader(
        size: const Size(100, 100),
        baseColor: const Color(0xFF4488CC),
        material: SurfaceMaterial.matte,
        profile: SurfaceProfile.flat,
        scene: const LightScene(lights: []),
        screenCenter: const Offset(50, 50),
        curvature: 0.0,
      );
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Update CLAUDE.md**

Update the "Architecture" section's "Resolution & Rendering" bullet to mention multi-light shader support:
```
3. **Resolution & Rendering** (`light_resolver.dart`, `lighting_math.dart`, `lit_shader.dart`) — `LightResolver` blends all lights in a single pass into a `ResolvedLight`. `LightingEngine` computes fill gradients, border sweeps, and shadows from the resolved light. `LitShader` provides GPU-accelerated per-pixel lighting via a GLSL fragment shader supporting up to 4 simultaneous lights.
```

Also update the "Known Sharp Edges" section — remove the "Screen-space only" edge and add:
```
- Shader supports up to 4 lights; lights beyond 4 are handled by the Canvas fallback only
```

---

## Chunk 3: Unified Fill + Border Shader (Tier 3)

**Why:** Borders currently use 8-sample SweepGradient — no per-pixel specular, no fresnel, no material variation. By computing a signed distance field (SDF) for the rounded rect inside the shader, we can determine per-pixel whether we're in the border zone or fill zone and apply appropriate normals to each.

**Uniform additions:** `uBorderWidth` (1 float) + `uBorderRadius` (4 floats, per-corner) = 5 new uniforms. Total: 50.

### Task 7: Extend shader with SDF border rendering

**Files:**
- Modify: `shaders/lit_surface.frag`

- [ ] **Step 1: Add border uniforms and SDF functions to the shader**

Add after the `uCurvature` uniform:

```glsl
// Border
uniform float uBorderWidth;
uniform vec4 uBorderRadius; // top-left, top-right, bottom-right, bottom-left
```

Add SDF helper functions before `main()`:

```glsl
// ── Rounded rect SDF ──────────────────────────────────────────────────────────

/// Signed distance to a rounded rect centered at the origin.
/// Returns negative inside, zero on edge, positive outside.
float roundedRectSDF(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

/// Pick the corner radius for the current quadrant.
float cornerRadius(vec2 p) {
  // uBorderRadius: x=topLeft, y=topRight, z=bottomRight, w=bottomLeft
  if (p.x < 0.0) {
    return p.y < 0.0 ? uBorderRadius.x : uBorderRadius.w;
  } else {
    return p.y < 0.0 ? uBorderRadius.y : uBorderRadius.z;
  }
}

/// Compute the outward-facing edge normal at a point near the border.
/// Uses the gradient of the SDF.
vec3 borderNormal(vec2 p, vec2 halfSize, float r) {
  float eps = 1.0;
  float d0 = roundedRectSDF(p, halfSize, r);
  float dx = roundedRectSDF(p + vec2(eps, 0.0), halfSize, r) - d0;
  float dy = roundedRectSDF(p + vec2(0.0, eps), halfSize, r) - d0;
  // The SDF gradient points outward; the border lip faces outward.
  // We treat the border as a tiny convex ridge, so its normal tilts
  // outward from the surface plane.
  vec2 grad = normalize(vec2(dx, dy));
  // Mix between outward tilt (edge-like) and surface-facing (flat).
  // More tilt = border catches more light from the side.
  return normalize(vec3(grad * 0.6, 1.0));
}
```

- [ ] **Step 2: Update `main()` to use border-aware rendering**

Replace `main()`:

```glsl
void main() {
  vec2 fragPos = FlutterFragCoord().xy;
  vec2 uv = fragPos / uSize;
  vec2 center = uSize * 0.5;
  vec2 p = fragPos - center;
  vec2 halfSize = center;

  float r = cornerRadius(p);

  // SDF: negative = inside shape, positive = outside
  float outerDist = roundedRectSDF(p, halfSize, r);
  float innerDist = roundedRectSDF(p, halfSize - vec2(uBorderWidth), max(r - uBorderWidth, 0.0));

  // Outside the outer rounded rect — fully transparent
  if (outerDist > 0.5) {
    fragColor = vec4(0.0);
    return;
  }

  // Anti-alias the outer edge
  float outerAlpha = 1.0 - smoothstep(-0.5, 0.5, outerDist);

  // Determine if we're in the border zone or fill zone
  // borderBlend: 1.0 = fully in border, 0.0 = fully in fill
  float borderBlend = 1.0 - smoothstep(-0.5, 0.5, innerDist);

  // ── Normal ──
  vec3 fillNormal = normalAt(uv);
  vec3 edgeNormal = borderNormal(p, halfSize, r);
  vec3 N = mix(fillNormal, edgeNormal, borderBlend);

  vec3 V = vec3(0.0, 0.0, 1.0);

  // ── Accumulate lighting ──
  vec3 litColor = uBaseColor.rgb * 0.7; // ambient base

  int numLights = int(uNumLights + 0.5);
  if (numLights > 0) {
    litColor += shadeLight(N, V, uLight0Dir, uLight0Intensity, uLight0Color.rgb);
  }
  if (numLights > 1) {
    litColor += shadeLight(N, V, uLight1Dir, uLight1Intensity, uLight1Color.rgb);
  }
  if (numLights > 2) {
    litColor += shadeLight(N, V, uLight2Dir, uLight2Intensity, uLight2Color.rgb);
  }
  if (numLights > 3) {
    litColor += shadeLight(N, V, uLight3Dir, uLight3Intensity, uLight3Color.rgb);
  }

  // Border gets slightly different base tone (can be tuned)
  // In the border zone, lighten the base slightly to simulate the ridge catching light
  vec3 borderBase = uBaseColor.rgb * 1.05;
  vec3 finalBase = mix(uBaseColor.rgb, borderBase, borderBlend);

  // Recompute with the correct base for border
  vec3 finalColor = mix(litColor, litColor * (finalBase / max(uBaseColor.rgb, vec3(0.01))), borderBlend);

  fragColor = vec4(clamp(finalColor, 0.0, 1.0), uBaseColor.a * outerAlpha);
}
```

### Task 8: Update LitShader to pass border uniforms

**Files:**
- Modify: `lib/src/lit_shader.dart`

**Important:** The GLSL shader (Task 7) and the Dart uniform binding (this task) must be committed together. If deployed separately, the uniform layout will be mismatched.

- [ ] **Step 1: Add border parameters to createShader**

Add `borderWidth` and `borderRadius` parameters. Insert the border uniform block after the curvature uniform (after `shader.setFloat(44, curvature);`):

```dart
    // ── Border (uniforms 45-49) ──
    shader.setFloat(45, borderWidth);
    shader.setFloat(46, borderRadius.topLeft.x);
    shader.setFloat(47, borderRadius.topRight.x);
    shader.setFloat(48, borderRadius.bottomRight.x);
    shader.setFloat(49, borderRadius.bottomLeft.x);
```

Update the method signature to include the new optional params:

```dart
  static ui.FragmentShader? createShader({
    required Size size,
    required Color baseColor,
    required SurfaceMaterial material,
    required SurfaceProfile profile,
    required LightScene scene,
    required Offset screenCenter,
    required double curvature,
    double borderWidth = 0.0,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
```

Update the doc comment table to include uniforms 45-49.

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All pass (createShader returns null in test env).

**Important:** The GLSL shader (Task 7) and the Dart uniform binding (this task) must be applied together. If run separately, the uniform layout will be mismatched.

### Task 9: Update widget painters to use unified shader for fill+border

**Files:**
- Modify: `lib/src/lit_surface.dart`
- Modify: `lib/src/lit_button.dart`

- [ ] **Step 1: Update LitSurface painter**

When the shader is used, it now handles both fill AND border in a single draw call. The Canvas border code becomes the fallback.

In `_LitSurfacePainter.paint()`, restructure the painting logic:

```dart
@override
void paint(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  final outerRRect = borderRadius.toRRect(rect);
  final innerRRect = outerRRect.deflate(borderWidth);

  final useShader = LitShader.isLoaded &&
      (material != null ||
       (profile != null && profile!.pattern != SurfacePattern.flat));

  if (useShader) {
    // Unified shader handles fill + border + anti-aliased edges
    final shader = LitShader.createShader(
      size: size,
      baseColor: baseColor,
      material: material ?? SurfaceMaterial.matte,
      profile: profile ?? SurfaceProfile.flat,
      scene: scene,
      screenCenter: screenCenter,
      curvature: curvature,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
    );
    if (shader != null) {
      final shaderPaint = Paint()..shader = shader;
      canvas.drawRect(rect, shaderPaint);
      return;
    }
  }

  // ── Canvas fallback ──
  // Keep ALL existing code from `_LitSurfacePainter.paint()` starting at
  // `final hsl = HSLColor.fromColor(baseColor);` (current line 125)
  // through the end of `paint()` (current line 265).
  // This is the entire border SweepGradient + fill gradient logic — unchanged.
  final hsl = HSLColor.fromColor(baseColor);
  // ... (existing lines 127–265 of _LitSurfacePainter.paint() go here verbatim) ...
```

- [ ] **Step 2: Apply same pattern to LitButton painter**

In `_LitButtonPainter.paint()`, the shader call now covers fill+border. Shadows remain Canvas-based (drawn before the shader call).

**Merge instructions for `_LitButtonPainter.paint()`:**

1. Keep the existing shadow loop (current lines 173-189) as the first thing in `paint()`.
2. Keep the hover base color computation (current lines 283-289).
3. Insert the `useShader` check and `LitShader.createShader(...)` call (same as LitSurface above, with `borderWidth` and `borderRadius` params). If shader succeeds, `return`.
4. Keep ALL existing code from `final edgeBrightness = List.filled(8, 0.0);` (current line 193) through the end of `paint()` (current line 412) as the Canvas fallback.

```dart
@override
void paint(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  final outerRRect = borderRadius.toRRect(rect);
  final innerRRect = outerRRect.deflate(borderWidth);

  // ── Shadows (always Canvas — drawn behind everything) ──
  // (existing lines 173-189 unchanged)
  for (final light in scene.lights) {
    final intensity = light.intensityAt(screenCenter);
    if (intensity < 0.001) continue;
    final dir = light.directionAt(screenCenter);

    final shadowDistance = surfaceElevation * (1.0 - 0.5 * 0.8);
    final shadowBlur = material != null
        ? surfaceElevation * (1.5 - 0.5) * (1.0 + material!.roughness * 0.5)
        : surfaceElevation * (1.5 - 0.5);
    final shadowOffset = Offset(-dir.dx * shadowDistance, -dir.dy * shadowDistance);
    final shadowOpacity = (0.12 * intensity).clamp(0.0, 0.4);

    final shadowRRect = outerRRect.shift(shadowOffset);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: shadowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur * 0.5);
    canvas.drawRRect(shadowRRect, shadowPaint);
  }

  var effectiveBase = baseColor;
  if (isHovered) {
    final h = HSLColor.fromColor(effectiveBase);
    effectiveBase = h
        .withLightness((h.lightness + hoverLightenAmount).clamp(0.0, 1.0))
        .toColor();
  }

  // ── Shader path (unified fill + border) ──
  final useShader = LitShader.isLoaded &&
      (material != null ||
       (profile != null && profile!.pattern != SurfacePattern.flat));

  if (useShader) {
    final shader = LitShader.createShader(
      size: size,
      baseColor: effectiveBase,
      material: material ?? SurfaceMaterial.matte,
      profile: profile ?? SurfaceProfile.flat,
      scene: scene,
      screenCenter: screenCenter,
      curvature: curvature,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
    );
    if (shader != null) {
      canvas.drawRect(rect, Paint()..shader = shader);
      return;
    }
  }

  // ── Canvas fallback ──
  // Keep ALL existing code from `final edgeBrightness = List.filled(8, 0.0);`
  // (current line 193) through the end of `paint()` (current line 412).
  // This is the entire border SweepGradient + fill gradient logic — unchanged.
  final hsl = HSLColor.fromColor(effectiveBase);
  // ... (existing lines 193–412 of _LitButtonPainter.paint() go here verbatim) ...
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 4: Update CLAUDE.md**

Update the "Widgets" section to reflect that the shader now handles fill + border in a single pass:
```
When a `material` is set and the shader is loaded, `LitButton` and `LitSurface` render fill and border in a single GPU draw call using SDF-based rounded rect geometry. The Canvas-based SweepGradient border and gradient fill remain as the fallback.
```

---

## Chunk 4: Hemisphere Ambient (Tier 4)

**Why:** Unlighted regions are flat darkened base color. A hemisphere ambient model tints shadows with subtle sky/ground color variation based on surface normal direction, making shadows feel grounded instead of hollow.

**Uniform additions:** `uAmbientSky` (3 floats) + `uAmbientGround` (3 floats) = 6 new uniforms. Total: 56.

### Task 10: Add ambient properties to LightScene

**Files:**
- Modify: `lib/src/light_scene.dart`
- Create: `test/light_scene_ambient_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/light_scene_ambient_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('LightScene ambient', () {
    test('default ambient sky is white', () {
      final scene = LightScene.directional(angle: 0, intensity: 0.5);
      expect(scene.ambientSky, const Color(0xFFFFFFFF));
    });

    test('default ambient ground is white', () {
      final scene = LightScene.directional(angle: 0, intensity: 0.5);
      expect(scene.ambientGround, const Color(0xFFFFFFFF));
    });

    test('custom ambient colors are preserved', () {
      const sky = Color(0xFFCCDDFF);
      const ground = Color(0xFFFFEECC);
      final scene = LightScene(
        lights: [const DirectionalLight(angle: 0, intensity: 0.5)],
        ambientSky: sky,
        ambientGround: ground,
      );
      expect(scene.ambientSky, sky);
      expect(scene.ambientGround, ground);
    });

    test('equality includes ambient colors', () {
      final a = LightScene(
        lights: [const DirectionalLight(angle: 0, intensity: 0.5)],
        ambientSky: const Color(0xFFCCDDFF),
      );
      final b = LightScene(
        lights: [const DirectionalLight(angle: 0, intensity: 0.5)],
        ambientSky: const Color(0xFFCCDDFF),
      );
      final c = LightScene(
        lights: [const DirectionalLight(angle: 0, intensity: 0.5)],
        ambientSky: const Color(0xFFFF0000),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `flutter test test/light_scene_ambient_test.dart`
Expected: Compilation errors — `ambientSky` and `ambientGround` don't exist.

- [ ] **Step 3: Add ambient properties to LightScene**

```dart
class LightScene {
  const LightScene({
    required this.lights,
    this.ambientSky = const Color(0xFFFFFFFF),
    this.ambientGround = const Color(0xFFFFFFFF),
  });

  final List<SceneLight> lights;

  /// Sky-hemisphere ambient tint. Applied to surfaces whose normals
  /// point upward (toward the top of the screen).
  final Color ambientSky;

  /// Ground-hemisphere ambient tint. Applied to surfaces whose normals
  /// point downward (toward the bottom of the screen).
  final Color ambientGround;

  factory LightScene.directional({
    required double angle,
    double intensity = 0.5,
    Color color = const Color(0xFFFFFFFF),
    Color ambientSky = const Color(0xFFFFFFFF),
    Color ambientGround = const Color(0xFFFFFFFF),
  }) =>
      LightScene(
        lights: [
          DirectionalLight(angle: angle, intensity: intensity, color: color),
        ],
        ambientSky: ambientSky,
        ambientGround: ambientGround,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LightScene) return false;
    if (lights.length != other.lights.length) return false;
    if (ambientSky != other.ambientSky) return false;
    if (ambientGround != other.ambientGround) return false;
    for (var i = 0; i < lights.length; i++) {
      if (lights[i] != other.lights[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(lights), ambientSky, ambientGround);

  @override
  String toString() => 'LightScene(lights: $lights, ambientSky: $ambientSky, ambientGround: $ambientGround)';
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `flutter test test/light_scene_ambient_test.dart`
Expected: All pass.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All pass (new params have defaults, so existing call sites are unaffected).

### Task 11: Add ambient to shader and LitShader

**Files:**
- Modify: `shaders/lit_surface.frag`
- Modify: `lib/src/lit_shader.dart`

- [ ] **Step 1: Add ambient uniforms to GLSL shader**

After `uBorderRadius`:
```glsl
// Ambient
uniform vec3 uAmbientSky;
uniform vec3 uAmbientGround;
```

Replace the ambient base line in `main()`:
```glsl
// Hemisphere ambient: lerp between ground and sky based on normal Y
// N.z is dominant for flat surfaces (pointing at viewer), so use N.y
// which tilts when the surface has texture. For flat normals (0,0,1)
// this gives 0.5 = equal mix.
float skyBlend = N.y * 0.5 + 0.5; // remap [-1,1] to [0,1]
vec3 ambientColor = mix(uAmbientGround, uAmbientSky, skyBlend);
vec3 litColor = uBaseColor.rgb * 0.7 * ambientColor;
```

- [ ] **Step 2: Update LitShader to pass ambient uniforms**

Add `LightScene scene` ambient colors at uniforms 50-55:

```dart
// ── Ambient (uniforms 50-55) ──
shader.setFloat(50, scene.ambientSky.r);
shader.setFloat(51, scene.ambientSky.g);
shader.setFloat(52, scene.ambientSky.b);
shader.setFloat(53, scene.ambientGround.r);
shader.setFloat(54, scene.ambientGround.g);
shader.setFloat(55, scene.ambientGround.b);
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 4: Update CLAUDE.md**

Add to the "Scene Management" description:
```
`LightScene` also holds `ambientSky` and `ambientGround` colors for hemisphere ambient lighting (default white = no tint).
```

---

## Chunk 5: Normal Map Textures (Tier 5)

**Why:** Currently only procedural heightmaps generate surface normals. Normal map textures allow hand-authored detail — brushed metal from a photo, leather grain, fabric weave — while using the same lighting model.

**Implementation:** Use Flutter's `FragmentShader.setImageSampler()` to bind a `ui.Image` as `sampler2D`. A `uUseNormalMap` flag (1 float) tells the shader whether to sample the texture or use the procedural heightmap.

### Task 12: Add normal map support to shader

**Files:**
- Modify: `shaders/lit_surface.frag`

- [ ] **Step 1: Add normal map sampler and flag**

Add after ambient uniforms:
```glsl
// Normal map
uniform float uUseNormalMap; // 0.0 = procedural, 1.0 = texture
uniform sampler2D uNormalMap;
```

Update the normal computation in `main()`:
```glsl
  // ── Normal ──
  vec3 fillNormal;
  if (uUseNormalMap > 0.5) {
    // Sample normal map: RGB channels encode XYZ in tangent space
    // Convention: (128,128,255) = flat facing camera = (0,0,1)
    vec3 mapNormal = texture(uNormalMap, uv).rgb * 2.0 - 1.0;
    fillNormal = normalize(mapNormal);
  } else {
    fillNormal = normalAt(uv);
  }
```

### Task 13: Update LitShader to accept normal map image

**Files:**
- Modify: `lib/src/lit_shader.dart`

- [ ] **Step 1: Add normalMap parameter**

```dart
  static ui.FragmentShader? createShader({
    required Size size,
    required Color baseColor,
    required SurfaceMaterial material,
    required SurfaceProfile profile,
    required LightScene scene,
    required Offset screenCenter,
    required double curvature,
    double borderWidth = 0.0,
    BorderRadius borderRadius = BorderRadius.zero,
    ui.Image? normalMap,
  }) {
    // ... existing uniform setup ...

    // ── Normal map (uniform 56 + sampler 0) ──
    shader.setFloat(56, normalMap != null ? 1.0 : 0.0);
    if (normalMap != null) {
      shader.setImageSampler(0, normalMap);
    }

    return shader;
  }
```

- [ ] **Step 2: Add normalMap parameter to widget painters**

In `LitSurface` (`lib/src/lit_surface.dart`):

1. Add `import 'dart:ui' as ui;` at the top of the file.
2. Add field to `LitSurface` widget class:
   ```dart
   /// Optional normal map image for per-pixel surface detail.
   final ui.Image? normalMap;
   ```
3. Add `this.normalMap` to the constructor.
4. Pass `normalMap` through to `_LitSurfacePainter`:
   ```dart
   _LitSurfacePainter(
     // ... existing params ...
     normalMap: widget.normalMap,  // add this
   )
   ```
5. Add `this.normalMap` to `_LitSurfacePainter` constructor and field:
   ```dart
   final ui.Image? normalMap;
   ```
6. Pass it to `LitShader.createShader(normalMap: normalMap)` in the shader path.
7. Add `normalMap != oldDelegate.normalMap` to `shouldRepaint`.

In `LitButton` (`lib/src/lit_button.dart`): apply the same 7 changes.
The `normalMap` field goes on both `LitButton` (widget) and `_LitButtonPainter`.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 4: Update CLAUDE.md**

Add `normalMap` to the "Common Widget Parameters" list:
```
- `normalMap` — Optional `ui.Image` normal map texture for per-pixel surface detail (requires shader)
```

---

## Chunk 6: Translucency / Glass Surfaces (Tier 6)

**Why:** All surfaces are currently opaque. Adding a `translucency` property to `SurfaceMaterial` enables glass, frosted glass, and translucent surfaces. The shader outputs reduced alpha for the fill while keeping specular highlights at full opacity.

### Task 14: Add translucency to SurfaceMaterial

**Files:**
- Modify: `lib/src/surface_material.dart`
- Create: `test/surface_material_translucency_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/surface_material_translucency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('SurfaceMaterial translucency', () {
    test('default translucency is 0.0 (opaque)', () {
      expect(SurfaceMaterial.matte.translucency, 0.0);
      expect(SurfaceMaterial.polishedMetal.translucency, 0.0);
      expect(SurfaceMaterial.glossy.translucency, 0.0);
    });

    test('glass preset has high translucency', () {
      expect(SurfaceMaterial.glass.translucency, greaterThan(0.5));
    });

    test('glass preset has low roughness', () {
      expect(SurfaceMaterial.glass.roughness, lessThan(0.2));
    });

    test('glass preset has high fresnel', () {
      expect(SurfaceMaterial.glass.fresnel, greaterThan(0.7));
    });

    test('custom material stores translucency', () {
      const m = SurfaceMaterial(
        roughness: 0.1,
        metallic: 0.0,
        fresnel: 0.6,
        sheen: 0.0,
        clearcoat: 0.0,
        translucency: 0.5,
      );
      expect(m.translucency, 0.5);
    });

    test('equality includes translucency', () {
      const a = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.5,
      );
      const b = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.5,
      );
      const c = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.8,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('frostedGlass preset has moderate translucency and higher roughness', () {
      expect(SurfaceMaterial.frostedGlass.translucency, greaterThan(0.3));
      expect(SurfaceMaterial.frostedGlass.roughness, greaterThan(SurfaceMaterial.glass.roughness));
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `flutter test test/surface_material_translucency_test.dart`
Expected: Compilation errors — `translucency` doesn't exist, `glass`/`frostedGlass` presets missing.

- [ ] **Step 3: Add translucency property and glass presets**

In `lib/src/surface_material.dart`:

Add `translucency` field:
```dart
class SurfaceMaterial {
  const SurfaceMaterial({
    required this.roughness,
    required this.metallic,
    required this.fresnel,
    required this.sheen,
    required this.clearcoat,
    this.translucency = 0.0,
  });

  // ... existing fields ...

  /// Surface translucency (0 = fully opaque, 1 = fully transparent).
  ///
  /// Translucent surfaces let light pass through while still showing
  /// specular highlights and fresnel effects at full opacity.
  final double translucency;
```

Add presets:
```dart
  /// Clear glass — highly transparent, strong fresnel at edges, sharp specular.
  static const glass = SurfaceMaterial(
    roughness: 0.05,
    metallic: 0.0,
    fresnel: 0.9,
    sheen: 0.0,
    clearcoat: 0.0,
    translucency: 0.75,
  );

  /// Frosted glass — translucent with diffused light, softer highlights.
  static const frostedGlass = SurfaceMaterial(
    roughness: 0.4,
    metallic: 0.0,
    fresnel: 0.7,
    sheen: 0.0,
    clearcoat: 0.0,
    translucency: 0.5,
  );
```

Update `==` and `hashCode` to include `translucency`:
```dart
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceMaterial &&
          roughness == other.roughness &&
          metallic == other.metallic &&
          fresnel == other.fresnel &&
          sheen == other.sheen &&
          clearcoat == other.clearcoat &&
          translucency == other.translucency;

  @override
  int get hashCode => Object.hash(roughness, metallic, fresnel, sheen, clearcoat, translucency);
```

Update `toString`:
```dart
  @override
  String toString() =>
      'SurfaceMaterial(roughness: $roughness, metallic: $metallic, '
      'fresnel: $fresnel, sheen: $sheen, clearcoat: $clearcoat, '
      'translucency: $translucency)';
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `flutter test test/surface_material_translucency_test.dart`
Expected: All pass.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All pass (default translucency=0.0 preserves existing behavior).

### Task 15: Add translucency to shader output

**Files:**
- Modify: `shaders/lit_surface.frag`
- Modify: `lib/src/lit_shader.dart`

- [ ] **Step 1: Add translucency uniform to shader**

Add after `uUseNormalMap`:
```glsl
uniform float uTranslucency;
```

Replace the final `fragColor` assignment in `main()`. The translucency code must go AFTER the existing border blend computation (the `vec3 finalColor = mix(...)` line from Chunk 3), not before it:

```glsl
  // ... (existing border blend from Chunk 3) ...
  vec3 borderBase = uBaseColor.rgb * 1.05;
  vec3 finalBase = mix(uBaseColor.rgb, borderBase, borderBlend);
  vec3 finalColor = mix(litColor, litColor * (finalBase / max(uBaseColor.rgb, vec3(0.01))), borderBlend);

  // ── Translucency ──
  // Reduce base alpha but keep specular highlights visible.
  // Specular and fresnel contributions remain at full opacity
  // so the surface "catches light" even when transparent.
  float baseAlpha = uBaseColor.a * (1.0 - uTranslucency);

  // Separate the specular/highlight contributions from the diffuse base
  vec3 diffuseComponent = uBaseColor.rgb * 0.7 * ambientColor;
  vec3 highlightComponent = max(finalColor - diffuseComponent, vec3(0.0));

  // Highlights stay opaque, diffuse gets reduced alpha
  float highlightLum = dot(highlightComponent, vec3(0.299, 0.587, 0.114));
  float effectiveAlpha = mix(baseAlpha, uBaseColor.a, clamp(highlightLum * 2.0, 0.0, 1.0));

  fragColor = vec4(clamp(finalColor, 0.0, 1.0), effectiveAlpha * outerAlpha);
```

**Note:** This replaces the existing `fragColor = vec4(clamp(finalColor, ...), uBaseColor.a * outerAlpha);` line from Chunk 3. The key change is using `finalColor` (which includes border blend) instead of `litColor`, and applying `max(..., vec3(0.0))` to avoid negative highlight values from the border adjustment.

- [ ] **Step 2: Update LitShader to pass translucency uniform**

```dart
// ── Translucency (uniform 57) ──
shader.setFloat(57, material.translucency);
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All pass.

### Task 16: Add BackdropFilter support for translucent widgets

**Files:**
- Modify: `lib/src/lit_surface.dart`
- Modify: `lib/src/lit_button.dart`

- [ ] **Step 1: Wrap child in BackdropFilter when translucency > 0**

In `LitSurface.build()`, wrap the `CustomPaint` in a `ClipRRect` + `BackdropFilter` when the material has translucency:

```dart
@override
Widget build(BuildContext context) {
  final effectiveScene = scene ?? LightTheme.of(context);
  final effectiveMaterial = LitMaterialTheme.resolveOf(context, material);
  final effectiveProfile = profile ?? LitMaterialTheme.profileOf(context);
  final radius = borderRadius ?? BorderRadius.circular(10);
  final screenCenter = _getScreenCenter(context);
  final translucency = effectiveMaterial?.translucency ?? 0.0;

  // ... existing inspector registration ...

  Widget result = CustomPaint(
    painter: _LitSurfacePainter(/* ... existing params ... */),
    child: Padding(
      padding: (padding ?? EdgeInsets.zero) + EdgeInsets.all(borderWidth),
      child: child,
    ),
  );

  // Wrap in backdrop blur for translucent surfaces
  if (translucency > 0) {
    final sigma = 8.0 * translucency * (effectiveMaterial?.roughness ?? 0.0);
    result = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: result,
      ),
    );
  }

  return result;
}
```

Apply the same pattern to `LitButton`.

Note: `ImageFilter` is available through `package:flutter/material.dart` which is already imported in both files. No additional import needed.

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All pass.

### Task 17: Update LitMaterialTheme for new presets

**Files:**
- Modify: `lib/src/material_theme.dart`

- [ ] **Step 1: Add glass presets to the theme registry**

Add `'glass'` and `'frostedGlass'` to `presetKeys`, `presetDefaults`, and `presetLabels`:

```dart
static const presetKeys = ['metal', 'matte', 'fuzzy', 'glossy', 'lacquered', 'glass', 'frostedGlass'];

static const Map<String, SurfaceMaterial> presetDefaults = {
  'metal': SurfaceMaterial.polishedMetal,
  'matte': SurfaceMaterial.matte,
  'fuzzy': SurfaceMaterial.fuzzy,
  'glossy': SurfaceMaterial.glossy,
  'lacquered': SurfaceMaterial.lacquered,
  'glass': SurfaceMaterial.glass,
  'frostedGlass': SurfaceMaterial.frostedGlass,
};

static const Map<String, String> presetLabels = {
  'metal': 'Metal',
  'matte': 'Matte',
  'fuzzy': 'Fuzzy',
  'glossy': 'Glossy',
  'lacquered': 'Lacquer',
  'glass': 'Glass',
  'frostedGlass': 'Frosted',
};
```

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All pass.

### Task 18: Final integration test + CLAUDE.md update

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Final CLAUDE.md update**

Update `CLAUDE.md` to reflect the complete state after all 6 tiers. Key changes:

1. Update test count in "Build & Test" section
2. Add `SurfaceMaterial` presets list (including `glass`, `frostedGlass`) to a new "Materials" section
3. Add `SurfaceProfile` patterns to a new "Surface Profiles" section
4. Update "Exports" to include `SurfaceMaterial`, `SurfaceProfile`, `LitShader`, `LitMaterialTheme`
5. Add "Shader System" section documenting:
   - `LitShader.load()` must be called at startup
   - Shader renders fill + border in a single GPU pass when material is set
   - Supports up to 4 simultaneous lights
   - Canvas fallback when shader isn't loaded
   - 58 float uniforms + 1 image sampler
6. Update "Known Sharp Edges" to mention:
   - Shader supports max 4 lights; beyond that only Canvas path handles them
   - `LitShader.load()` is async; widgets fall back to Canvas until loaded
   - `normalMap` requires a pre-loaded `ui.Image`

---

## Notes

- **Uniform budget:** Final layout uses 58 float uniforms + 1 image sampler. Flutter supports ~100 float uniforms, so there's headroom for future additions.
- **Shader loading:** Consumers must call `await LitShader.load()` during startup. Without it, all widgets gracefully fall back to Canvas rendering.
- **Canvas fallback:** Every widget maintains its full Canvas-based rendering path. The shader is strictly an enhancement.
- **Performance:** One draw call per widget (shader path) vs N draw calls per widget (Canvas path with N lights). The shader path is strictly better for performance when available.
- **Breaking changes:** `SurfaceMaterial` gains a new `translucency` parameter (default 0.0) and `LightScene` gains `ambientSky`/`ambientGround` (default white). Both are backward-compatible. `LitShader.createShader` gains new optional parameters — also backward-compatible.
