# Materials & Surface Profiles Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add PBR-inspired material properties and GPU-accelerated surface profiles to lit_ui widgets so surfaces respond to light with distinct physical character (metallic, matte, fuzzy, etc.) and per-pixel texture variation (grooves, dimples, noise).

**Architecture:** Materials are pure Dart data classes with derived lighting multipliers. Surface profiles define procedural heightmaps via parameters (pattern type, frequency, amplitude, angle). A GLSL fragment shader runs on the GPU to compute per-pixel normals from the profile and apply material-aware lighting to the fill. Borders and shadows stay Canvas-based (edge-only, no per-pixel work needed).

**Tech Stack:** Flutter FragmentProgram API, GLSL ES 1.0 fragment shaders, Skia/Impeller GPU pipeline.

---

## File Structure

### New files
| File | Responsibility |
|------|---------------|
| `lib/src/surface_material.dart` | **Rewrite** — PBR material data class (roughness, metallic, fresnel, sheen, clearcoat) with derived lighting multipliers |
| `lib/src/surface_profile.dart` | Profile data class — pattern type enum + frequency/amplitude/angle params |
| `shaders/lit_surface.frag` | GLSL fragment shader — per-pixel normal perturbation + material-aware lighting |
| `lib/src/lit_shader.dart` | Shader loader + uniform binder — loads FragmentProgram, converts material/profile/light to uniforms |
| `test/surface_material_test.dart` | Unit tests for material derived values |
| `test/surface_profile_test.dart` | Unit tests for profile validation |

### Modified files
| File | Change |
|------|--------|
| `pubspec.yaml` | Add `flutter: shaders:` entry for the .frag file |
| `lib/lit_ui.dart` | Export new files |
| `lib/src/lit_surface.dart` | Accept `SurfaceMaterial` and `SurfaceProfile`, use shader for fill when profile is set |
| `lib/src/lit_button.dart` | Accept `SurfaceMaterial` and `SurfaceProfile`, use shader for fill when profile is set |
| `lib/src/lit_input_border.dart` | Accept `SurfaceMaterial`, use material-derived values for border/shadow calculations |
| `lib/src/lit_edge_border.dart` | Accept `SurfaceMaterial`, use material-derived values for border calculations |
| `lib/src/debug/light_debug_controller.dart` | Add material and profile state |
| `lib/src/debug/light_debug_overlay.dart` | Add material preset picker and profile editor |

---

## Chunk 1: SurfaceMaterial

### Task 1: Rewrite SurfaceMaterial with PBR properties

**Files:**
- Rewrite: `lib/src/surface_material.dart`
- Create: `test/surface_material_test.dart`

- [ ] **Step 1: Write failing tests for material properties and derived values**

```dart
// test/surface_material_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('SurfaceMaterial', () {
    group('core properties', () {
      test('custom material stores all properties', () {
        const m = SurfaceMaterial(
          roughness: 0.5,
          metallic: 0.8,
          fresnel: 0.6,
          sheen: 0.0,
          clearcoat: 0.0,
        );
        expect(m.roughness, 0.5);
        expect(m.metallic, 0.8);
        expect(m.fresnel, 0.6);
        expect(m.sheen, 0.0);
        expect(m.clearcoat, 0.0);
      });

      test('equality and hashCode', () {
        const a = SurfaceMaterial(
          roughness: 0.5, metallic: 0.8, fresnel: 0.6, sheen: 0.0, clearcoat: 0.0,
        );
        const b = SurfaceMaterial(
          roughness: 0.5, metallic: 0.8, fresnel: 0.6, sheen: 0.0, clearcoat: 0.0,
        );
        const c = SurfaceMaterial(
          roughness: 0.9, metallic: 0.0, fresnel: 0.1, sheen: 0.7, clearcoat: 0.0,
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(equals(c)));
      });
    });

    group('presets', () {
      test('metallic has low roughness and high metallic', () {
        expect(SurfaceMaterial.metallic.roughness, lessThan(0.3));
        expect(SurfaceMaterial.metallic.metallic, greaterThan(0.7));
      });

      test('matte has high roughness and zero metallic', () {
        expect(SurfaceMaterial.matte.roughness, greaterThan(0.5));
        expect(SurfaceMaterial.matte.metallic, 0.0);
      });

      test('fuzzy has high roughness and high sheen', () {
        expect(SurfaceMaterial.fuzzy.roughness, greaterThan(0.7));
        expect(SurfaceMaterial.fuzzy.sheen, greaterThan(0.5));
      });
    });

    group('derived values', () {
      test('metallic fillContrast is higher than fuzzy', () {
        expect(
          SurfaceMaterial.metallic.fillContrast,
          greaterThan(SurfaceMaterial.fuzzy.fillContrast),
        );
      });

      test('metallic borderContrast is higher than matte', () {
        expect(
          SurfaceMaterial.metallic.borderContrast,
          greaterThan(SurfaceMaterial.matte.borderContrast),
        );
      });

      test('fuzzy shadowBlurSigma is higher than metallic', () {
        expect(
          SurfaceMaterial.fuzzy.shadowBlurSigma,
          greaterThan(SurfaceMaterial.metallic.shadowBlurSigma),
        );
      });

      test('metallic highlightTint is high (tints highlights with base color)', () {
        expect(SurfaceMaterial.metallic.highlightTint, greaterThan(0.5));
      });

      test('matte highlightTint is zero (white highlights)', () {
        expect(SurfaceMaterial.matte.highlightTint, 0.0);
      });

      test('fresnel strength decreases with roughness', () {
        const smooth = SurfaceMaterial(
          roughness: 0.1, metallic: 0.0, fresnel: 0.8, sheen: 0.0, clearcoat: 0.0,
        );
        const rough = SurfaceMaterial(
          roughness: 0.9, metallic: 0.0, fresnel: 0.8, sheen: 0.0, clearcoat: 0.0,
        );
        expect(smooth.effectiveFresnel, greaterThan(rough.effectiveFresnel));
      });

      test('all derived values are in 0-1 range for all presets', () {
        for (final m in [SurfaceMaterial.metallic, SurfaceMaterial.matte, SurfaceMaterial.fuzzy]) {
          expect(m.fillContrast, inInclusiveRange(0.0, 1.0));
          expect(m.borderContrast, inInclusiveRange(0.0, 1.0));
          expect(m.highlightTint, inInclusiveRange(0.0, 1.0));
          expect(m.effectiveFresnel, inInclusiveRange(0.0, 1.0));
          expect(m.effectiveSheen, inInclusiveRange(0.0, 1.0));
          expect(m.shadowBlurSigma, greaterThanOrEqualTo(0.0));
          expect(m.insetShadowIntensity, inInclusiveRange(0.0, 1.0));
        }
      });
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `flutter test test/surface_material_test.dart`
Expected: Compilation errors — missing properties/methods on SurfaceMaterial.

- [ ] **Step 3: Rewrite SurfaceMaterial**

```dart
// lib/src/surface_material.dart

/// Describes how a surface responds to light using PBR-inspired properties.
///
/// Five core properties control the material's appearance:
/// - [roughness] — micro-surface bumpiness (highlight spread)
/// - [metallic] — whether highlights are white (0) or base-color-tinted (1)
/// - [fresnel] — edge brightness boost at grazing angles
/// - [sheen] — soft diffuse glow at edges (fuzzy/velvet materials)
/// - [clearcoat] — second glossy specular layer on top
///
/// Widgets read the derived getters ([fillContrast], [borderContrast], etc.)
/// to modulate their lighting calculations.
class SurfaceMaterial {
  const SurfaceMaterial({
    required this.roughness,
    required this.metallic,
    required this.fresnel,
    required this.sheen,
    required this.clearcoat,
  });

  /// Micro-surface roughness (0 = mirror-smooth, 1 = fully diffuse).
  /// Controls highlight spread: low → tight hotspot, high → broad wash.
  final double roughness;

  /// Metallic factor (0 = dielectric/plastic, 1 = metal).
  /// Metallic surfaces tint their highlights with the base color
  /// and have no diffuse fill component.
  final double metallic;

  /// Fresnel edge brightness (0 = none, 1 = strong).
  /// Modulated by roughness — rough surfaces scatter Fresnel away.
  final double fresnel;

  /// Sheen intensity (0 = none, 1 = strong velvet/fuzz glow).
  /// Adds soft diffuse edge glow, different from sharp Fresnel.
  final double sheen;

  /// Clearcoat layer intensity (0 = none, 1 = full glossy topcoat).
  /// Adds a second sharp highlight on top of the base material.
  final double clearcoat;

  // ── Presets ──────────────────────────────────────────────────────────────

  /// Polished metal — tight bright highlights tinted with base color.
  static const metallic_ = SurfaceMaterial(
    roughness: 0.15,
    metallic: 0.95,
    fresnel: 0.8,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  // Use a getter so the public API is `SurfaceMaterial.metallic`
  static const SurfaceMaterial metallic = metallic_;

  /// Standard matte — broad even highlights, white, no edge effects.
  static const matte = SurfaceMaterial(
    roughness: 0.7,
    metallic: 0.0,
    fresnel: 0.1,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  /// Felt / velvet / fabric — scattered light, strong sheen at edges.
  static const fuzzy = SurfaceMaterial(
    roughness: 0.85,
    metallic: 0.0,
    fresnel: 0.05,
    sheen: 0.7,
    clearcoat: 0.0,
  );

  /// Glossy plastic — smooth, white highlights, moderate Fresnel.
  static const glossy = SurfaceMaterial(
    roughness: 0.1,
    metallic: 0.0,
    fresnel: 0.6,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  /// Lacquered / car paint — matte base with glossy topcoat.
  static const lacquered = SurfaceMaterial(
    roughness: 0.6,
    metallic: 0.0,
    fresnel: 0.3,
    sheen: 0.0,
    clearcoat: 0.9,
  );

  // ── Derived values for widgets ──────────────────────────────────────────

  /// Fill gradient contrast multiplier (0–1).
  /// Low roughness + high reflectivity → strong gradient.
  double get fillContrast {
    final reflectivity = 0.3 + metallic * 0.7; // metals reflect more
    return reflectivity * (1.0 - roughness * 0.7);
  }

  /// Border highlight contrast multiplier (0–1).
  double get borderContrast {
    final specularSharpness = 1.0 - roughness;
    final reflectivity = 0.3 + metallic * 0.7;
    return (reflectivity * (0.4 + specularSharpness * 0.6)).clamp(0.0, 1.0);
  }

  /// How much to tint highlights with the base color (0 = white, 1 = full tint).
  /// Metals tint fully; dielectrics don't.
  double get highlightTint => metallic;

  /// Effective Fresnel strength after roughness attenuation.
  double get effectiveFresnel => (fresnel * (1.0 - roughness * 0.8)).clamp(0.0, 1.0);

  /// Effective sheen after clamping.
  double get effectiveSheen => sheen.clamp(0.0, 1.0);

  /// Maximum border lighten amount (0–1 lightness offset).
  double get maxBorderLighten {
    final specularSharpness = 1.0 - roughness;
    return 0.3 + specularSharpness * 0.4;
  }

  /// Maximum border darken amount (positive value, 0–1).
  double get maxBorderDarken {
    return 0.05 + (1.0 - roughness) * 0.15;
  }

  /// Shadow blur sigma. Rough → broad, sharp → tight.
  double get shadowBlurSigma => 0.5 + roughness * 3.0;

  /// Inset shadow opacity multiplier (0–1).
  double get insetShadowIntensity {
    final sharpness = 1.0 - roughness;
    return (0.15 + sharpness * 0.2).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceMaterial &&
          roughness == other.roughness &&
          metallic == other.metallic &&
          fresnel == other.fresnel &&
          sheen == other.sheen &&
          clearcoat == other.clearcoat;

  @override
  int get hashCode => Object.hash(roughness, metallic, fresnel, sheen, clearcoat);

  @override
  String toString() =>
      'SurfaceMaterial(roughness: $roughness, metallic: $metallic, '
      'fresnel: $fresnel, sheen: $sheen, clearcoat: $clearcoat)';
}
```

Note: The `metallic` preset uses an intermediate `metallic_` constant to avoid naming conflict with the `metallic` property. Alternatively, rename the preset to something like `polishedMetal` if the naming feels awkward — the plan reviewer may have an opinion here.

- [ ] **Step 4: Run tests — verify they pass**

Run: `flutter test test/surface_material_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/surface_material.dart test/surface_material_test.dart
git commit -m "feat(lit_ui): rewrite SurfaceMaterial with PBR properties"
```

---

## Chunk 2: SurfaceProfile

### Task 2: Create SurfaceProfile data class

**Files:**
- Create: `lib/src/surface_profile.dart`
- Create: `test/surface_profile_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/surface_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('SurfaceProfile', () {
    test('flat profile has zero amplitude', () {
      expect(SurfaceProfile.flat.amplitude, 0.0);
    });

    test('grooves profile has non-zero frequency and amplitude', () {
      final p = SurfaceProfile.grooves();
      expect(p.frequency, greaterThan(0));
      expect(p.amplitude, greaterThan(0));
      expect(p.pattern, SurfacePattern.grooves);
    });

    test('custom profile stores all parameters', () {
      const p = SurfaceProfile(
        pattern: SurfacePattern.dimples,
        frequency: 20.0,
        amplitude: 0.6,
        angle: 1.57,
      );
      expect(p.pattern, SurfacePattern.dimples);
      expect(p.frequency, 20.0);
      expect(p.amplitude, 0.6);
      expect(p.angle, 1.57);
    });

    test('equality', () {
      const a = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 12.0,
        amplitude: 0.4,
        angle: 0.0,
      );
      const b = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 12.0,
        amplitude: 0.4,
        angle: 0.0,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('pattern enum has expected values', () {
      expect(SurfacePattern.values, containsAll([
        SurfacePattern.flat,
        SurfacePattern.grooves,
        SurfacePattern.dimples,
        SurfacePattern.noise,
      ]));
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `flutter test test/surface_profile_test.dart`
Expected: Compilation errors — SurfaceProfile doesn't exist.

- [ ] **Step 3: Implement SurfaceProfile**

```dart
// lib/src/surface_profile.dart

/// The type of repeating heightmap pattern on a surface.
///
/// Each pattern is implemented as a procedural function in the GLSL shader.
/// The Dart enum serves as an index passed as a uniform.
enum SurfacePattern {
  /// No texture — uniform curvature (default behavior).
  flat,

  /// Parallel sinusoidal ridges (brushed metal, corduroy).
  grooves,

  /// 2D sine grid (hammered metal, textured plastic).
  dimples,

  /// Hash-based pseudo-random undulation (felt, rough stone).
  noise,
}

/// Defines the surface geometry that modulates how light plays across a widget.
///
/// A [SurfaceProfile] parameterises a procedural heightmap. The GLSL shader
/// derives per-pixel normals from the heightmap and uses them in the
/// lighting equation instead of the flat [curvature] value.
///
/// [pattern] selects the heightmap function.
/// [frequency] controls how tight the texture is (cycles per 100px).
/// [amplitude] controls how deep the texture is (0 = flat, 1 = maximum).
/// [angle] rotates the pattern in radians (relevant for [grooves]).
class SurfaceProfile {
  const SurfaceProfile({
    required this.pattern,
    this.frequency = 12.0,
    this.amplitude = 0.4,
    this.angle = 0.0,
  });

  final SurfacePattern pattern;
  final double frequency;
  final double amplitude;
  final double angle;

  // ── Convenience constructors ──

  /// No texture.
  static const flat = SurfaceProfile(
    pattern: SurfacePattern.flat,
    amplitude: 0.0,
  );

  /// Parallel ridges. [frequency] = ridges per 100px, [angle] = grain direction.
  const SurfaceProfile.grooves({
    double frequency = 12.0,
    double amplitude = 0.4,
    double angle = 0.0,
  }) : this(
          pattern: SurfacePattern.grooves,
          frequency: frequency,
          amplitude: amplitude,
          angle: angle,
        );

  /// 2D sine dimples.
  const SurfaceProfile.dimples({
    double frequency = 10.0,
    double amplitude = 0.3,
  }) : this(
          pattern: SurfacePattern.dimples,
          frequency: frequency,
          amplitude: amplitude,
          angle: 0.0,
        );

  /// Pseudo-random noise.
  const SurfaceProfile.noise({
    double frequency = 8.0,
    double amplitude = 0.5,
  }) : this(
          pattern: SurfacePattern.noise,
          frequency: frequency,
          amplitude: amplitude,
          angle: 0.0,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceProfile &&
          pattern == other.pattern &&
          frequency == other.frequency &&
          amplitude == other.amplitude &&
          angle == other.angle;

  @override
  int get hashCode => Object.hash(pattern, frequency, amplitude, angle);

  @override
  String toString() =>
      'SurfaceProfile(pattern: $pattern, frequency: $frequency, '
      'amplitude: $amplitude, angle: $angle)';
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `flutter test test/surface_profile_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/surface_profile.dart test/surface_profile_test.dart
git commit -m "feat(lit_ui): add SurfaceProfile data class with pattern types"
```

---

## Chunk 3: GLSL Shader + Loader

### Task 3: Write the GLSL fragment shader

**Files:**
- Create: `shaders/lit_surface.frag`
- Modify: `pubspec.yaml` (add shader asset)

The shader computes per-pixel lighting by:
1. Deriving a local normal from the profile heightmap (finite differences)
2. Computing diffuse + specular response using material properties
3. Outputting the lit surface color

- [ ] **Step 1: Add shader entry to pubspec.yaml**

Add under the `flutter:` key:

```yaml
flutter:
  shaders:
    - shaders/lit_surface.frag
```

- [ ] **Step 2: Write the fragment shader**

```glsl
// shaders/lit_surface.frag
#version 460 core

#include <flutter/runtime_effect.glsl>

// ── Uniforms ──
// Surface
uniform vec2 uSize;           // Widget size in pixels
uniform vec4 uBaseColor;      // RGBA base color
// Material (PBR)
uniform float uRoughness;     // 0–1
uniform float uMetallic;      // 0–1
uniform float uFresnel;       // 0–1 (pre-attenuated by roughness on Dart side)
uniform float uSheen;         // 0–1
uniform float uClearcoat;     // 0–1
// Profile
uniform float uPatternType;   // 0=flat, 1=grooves, 2=dimples, 3=noise
uniform float uFrequency;     // cycles per 100px
uniform float uAmplitude;     // 0–1
uniform float uAngle;         // rotation radians
// Light (up to 4 lights — first light for now)
uniform vec2 uLightDir;       // unit vector FROM surface TOWARD light
uniform float uLightIntensity;
uniform vec4 uLightColor;
// Curvature (base widget curvature, modulated by profile)
uniform float uCurvature;

out vec4 fragColor;

// ── Heightmap functions ──

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f); // smoothstep
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Rotate point by angle
vec2 rotate(vec2 p, float a) {
  float ca = cos(a);
  float sa = sin(a);
  return vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
}

float heightAt(vec2 uv) {
  int pat = int(uPatternType + 0.5);
  if (pat == 0) return 0.0; // flat

  vec2 p = rotate(uv * uSize, uAngle);
  float freq = uFrequency * 6.2832 / 100.0; // cycles/100px → radians/px

  if (pat == 1) {
    // Grooves — sin along one axis
    return sin(p.x * freq) * uAmplitude;
  } else if (pat == 2) {
    // Dimples — sin grid
    return sin(p.x * freq) * sin(p.y * freq) * uAmplitude;
  } else {
    // Noise
    float nFreq = uFrequency / 100.0;
    return (valueNoise(p * nFreq) * 2.0 - 1.0) * uAmplitude;
  }
}

// Derive normal via finite differences
vec3 normalAt(vec2 uv) {
  float eps = 1.0 / max(uSize.x, uSize.y);
  float hc = heightAt(uv);
  float hx = heightAt(uv + vec2(eps, 0.0));
  float hy = heightAt(uv + vec2(0.0, eps));
  // Tangent vectors
  vec3 tx = vec3(eps * uSize.x, 0.0, (hx - hc) * uCurvature);
  vec3 ty = vec3(0.0, eps * uSize.y, (hy - hc) * uCurvature);
  return normalize(cross(tx, ty));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // ── Normal ──
  vec3 N = normalAt(uv);
  // Light direction in 3D (assume light is elevated)
  vec3 L = normalize(vec3(uLightDir, 0.6));
  // View direction (straight on for 2D UI)
  vec3 V = vec3(0.0, 0.0, 1.0);
  vec3 H = normalize(L + V); // half-vector

  // ── Diffuse ──
  float NdotL = max(dot(N, L), 0.0);
  // Metals have no diffuse
  float diffuseStrength = (1.0 - uMetallic) * NdotL * uLightIntensity;

  // ── Specular (Blinn-Phong with roughness-derived exponent) ──
  float shininess = mix(4.0, 256.0, pow(1.0 - uRoughness, 2.0));
  float NdotH = max(dot(N, H), 0.0);
  float spec = pow(NdotH, shininess);
  float specStrength = spec * uLightIntensity;

  // Specular color: white for dielectrics, base-tinted for metals
  vec3 specColor = mix(vec3(1.0), uBaseColor.rgb, uMetallic);

  // ── Fresnel (Schlick approx) ──
  float NdotV = max(dot(N, V), 0.0);
  float fresnelTerm = uFresnel * pow(1.0 - NdotV, 5.0);

  // ── Sheen (soft edge glow) ──
  float sheenTerm = uSheen * pow(1.0 - NdotV, 2.0) * uLightIntensity;

  // ── Clearcoat (second specular layer, always sharp + white) ──
  float ccShininess = 128.0; // always glossy
  float ccSpec = pow(NdotH, ccShininess) * uClearcoat * uLightIntensity;

  // ── Compose ──
  vec3 base = uBaseColor.rgb;
  vec3 litColor = base * (0.15 + diffuseStrength * 0.85); // ambient + diffuse
  litColor += specColor * specStrength * 0.5;               // specular
  litColor += vec3(fresnelTerm * 0.15);                     // fresnel
  litColor += base * sheenTerm * 0.3;                        // sheen
  litColor += vec3(ccSpec * 0.3);                            // clearcoat

  // Tint by light color
  litColor *= mix(vec3(1.0), uLightColor.rgb, uLightIntensity * 0.5);

  fragColor = vec4(clamp(litColor, 0.0, 1.0), uBaseColor.a);
}
```

- [ ] **Step 3: Verify shader compiles with flutter build**

Run: `flutter build web --release 2>&1 | head -20` (from the admin-panel root, or `flutter test` in the lit_ui package to trigger shader compilation)

Note: If the shader fails to compile, check the GLSL version and `#include` syntax. Flutter expects `#include <flutter/runtime_effect.glsl>` and uses `FlutterFragCoord()` instead of `gl_FragCoord`.

- [ ] **Step 4: Commit**

```bash
git add shaders/lit_surface.frag pubspec.yaml
git commit -m "feat(lit_ui): add GLSL fragment shader for lit surface rendering"
```

### Task 4: Create LitShader loader

**Files:**
- Create: `lib/src/lit_shader.dart`

This is the Dart bridge: loads the FragmentProgram once, provides a method to create a configured `FragmentShader` with all uniforms set from material + profile + lights.

- [ ] **Step 1: Implement LitShader**

```dart
// lib/src/lit_shader.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'light_types.dart';
import 'light_scene.dart';
import 'surface_material.dart';
import 'surface_profile.dart';

/// Loads and configures the lit_surface fragment shader.
///
/// Call [load] once at startup. Then use [createShader] to get a configured
/// [FragmentShader] for use in a [Paint.shader].
class LitShader {
  LitShader._();

  static ui.FragmentProgram? _program;

  /// Load the shader program. Safe to call multiple times — loads only once.
  static Future<void> load() async {
    _program ??= await ui.FragmentProgram.fromAsset('packages/lit_ui/shaders/lit_surface.frag');
  }

  /// Whether the shader has been loaded.
  static bool get isLoaded => _program != null;

  /// Create a configured fragment shader.
  ///
  /// Returns null if [load] hasn't been called yet.
  /// Falls back gracefully — widgets can use their existing Canvas-based
  /// rendering when the shader isn't available.
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
    int i = 0;

    // Surface
    shader.setFloat(i++, size.width);
    shader.setFloat(i++, size.height);
    shader.setFloat(i++, baseColor.r);
    shader.setFloat(i++, baseColor.g);
    shader.setFloat(i++, baseColor.b);
    shader.setFloat(i++, baseColor.a);

    // Material
    shader.setFloat(i++, material.roughness);
    shader.setFloat(i++, material.metallic);
    shader.setFloat(i++, material.effectiveFresnel);
    shader.setFloat(i++, material.effectiveSheen);
    shader.setFloat(i++, material.clearcoat);

    // Profile
    shader.setFloat(i++, profile.pattern.index.toDouble());
    shader.setFloat(i++, profile.frequency);
    shader.setFloat(i++, profile.amplitude);
    shader.setFloat(i++, profile.angle);

    // Light — use first light for now, or combine
    // TODO: extend to multi-light (pass up to 4 lights as uniform arrays)
    double dirX = 0, dirY = -1, intensity = 0;
    double lightR = 1, lightG = 1, lightB = 1, lightA = 1;
    if (scene.lights.isNotEmpty) {
      final light = scene.lights.first;
      final dir = light.directionAt(screenCenter);
      dirX = dir.dx;
      dirY = dir.dy;
      intensity = light.intensityAt(screenCenter);
      lightR = light.color.r;
      lightG = light.color.g;
      lightB = light.color.b;
      lightA = light.color.a;
    }
    shader.setFloat(i++, dirX);
    shader.setFloat(i++, dirY);
    shader.setFloat(i++, intensity);
    shader.setFloat(i++, lightR);
    shader.setFloat(i++, lightG);
    shader.setFloat(i++, lightB);
    shader.setFloat(i++, lightA);

    // Curvature
    shader.setFloat(i++, curvature);

    return shader;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/lit_shader.dart
git commit -m "feat(lit_ui): add LitShader loader for fragment shader uniforms"
```

---

## Chunk 4: Widget Integration

### Task 5: Add material + profile to LitSurface

**Files:**
- Modify: `lib/src/lit_surface.dart`

- [ ] **Step 1: Add `material` and `profile` parameters to LitSurface**

Add to the constructor:
```dart
this.material,
this.profile,
```

Add fields:
```dart
final SurfaceMaterial? material;
final SurfaceProfile? profile;
```

- [ ] **Step 2: Update the painter to use material-derived values**

In `_LitSurfacePainter`, when `material` is provided:
- Replace hardcoded `bLighten = 0.4 * borderContrast` with `material.maxBorderLighten * material.borderContrast`
- Replace `bDarken = -0.06 * borderContrast` with `-material.maxBorderDarken * material.borderContrast`
- Use `material.fillContrast` instead of the `fillContrast` param

When `profile` is provided and `LitShader.isLoaded`:
- Replace the Canvas-based fill gradient with a shader-painted rect:
```dart
final shader = LitShader.createShader(
  size: size,
  baseColor: baseColor,
  material: effectiveMaterial,
  profile: effectiveProfile,
  scene: scene,
  screenCenter: screenCenter,
  curvature: curvature,
);
if (shader != null) {
  final shaderPaint = Paint()..shader = shader;
  canvas.drawRRect(innerRRect, shaderPaint);
} else {
  // Fallback to existing Canvas gradient code
}
```

- [ ] **Step 3: Run existing tests — nothing should break**

Run: `flutter test`
Expected: All 46 existing tests pass (no widget tests exist; this is a non-breaking additive change with optional params).

- [ ] **Step 4: Commit**

```bash
git add lib/src/lit_surface.dart
git commit -m "feat(lit_ui): LitSurface accepts material + profile, uses shader for fill"
```

### Task 6: Add material + profile to LitButton

**Files:**
- Modify: `lib/src/lit_button.dart`

Same pattern as Task 5: add optional `material` and `profile` params, update the painter to use material-derived values for borders/shadows, and use the shader for fill when profile is set.

- [ ] **Step 1: Add params and update painter** (same pattern as LitSurface)
- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit**

```bash
git add lib/src/lit_button.dart
git commit -m "feat(lit_ui): LitButton accepts material + profile"
```

### Task 7: Add material to LitInputBorder

**Files:**
- Modify: `lib/src/lit_input_border.dart`

LitInputBorder is concave — no fill shader needed. But material affects:
- Border lighten/darken ranges (`maxBorderLighten`, `maxBorderDarken`)
- Inset shadow blur sigma (`shadowBlurSigma`) and opacity (`insetShadowIntensity`)
- Shadow-facing edge behavior (fuzzy materials scatter light → less aggressive darken)

- [ ] **Step 1: Add `material` param**
- [ ] **Step 2: Replace hardcoded values with material-derived ones**

```dart
final effectiveMaterial = material ?? SurfaceMaterial.matte;
final maxLighten = effectiveMaterial.maxBorderLighten * borderContrast;
final maxDarken = -effectiveMaterial.maxBorderDarken * borderContrast;
// ...
final blurSigma = effectiveMaterial.shadowBlurSigma;
final shadowOpacity = (effectiveMaterial.insetShadowIntensity * dot * dot * intensity * borderContrast).clamp(0.0, 0.25);
```

- [ ] **Step 3: Run tests, commit**

```bash
git add lib/src/lit_input_border.dart
git commit -m "feat(lit_ui): LitInputBorder accepts material for border/shadow tuning"
```

### Task 8: Add material to LitEdgeBorder

**Files:**
- Modify: `lib/src/lit_edge_border.dart`

Same pattern — material controls `maxLighten`/`maxDarken` for the edge border.

- [ ] **Step 1: Add `material` param, update painter**
- [ ] **Step 2: Run tests, commit**

```bash
git add lib/src/lit_edge_border.dart
git commit -m "feat(lit_ui): LitEdgeBorder accepts material"
```

---

## Chunk 5: Exports + Debug Overlay

### Task 9: Update exports

**Files:**
- Modify: `lib/lit_ui.dart`

- [ ] **Step 1: Add exports**

```dart
export 'src/surface_material.dart';
export 'src/surface_profile.dart';
export 'src/lit_shader.dart';
```

- [ ] **Step 2: Run `flutter analyze`, commit**

```bash
flutter analyze
git add lib/lit_ui.dart
git commit -m "chore(lit_ui): export surface_material, surface_profile, lit_shader"
```

### Task 10: Add material/profile controls to debug overlay

**Files:**
- Modify: `lib/src/debug/light_debug_controller.dart`
- Modify: `lib/src/debug/light_debug_overlay.dart`

- [ ] **Step 1: Add material and profile state to controller**

```dart
SurfaceMaterial _material = SurfaceMaterial.matte;
SurfaceMaterial get material => _material;

SurfaceProfile _profile = SurfaceProfile.flat;
SurfaceProfile get profile => _profile;

void setMaterial(SurfaceMaterial m) { _material = m; notifyListeners(); }
void setProfile(SurfaceProfile p) { _profile = p; notifyListeners(); }
```

- [ ] **Step 2: Add material preset picker row to the expanded panel**

A row of labeled chips: `Metallic`, `Matte`, `Fuzzy`, `Glossy`, `Lacquered` — same pattern as the existing `_AddLightRow` / `_BlendModeSelector`.

- [ ] **Step 3: Add profile type picker + sliders for frequency/amplitude/angle**

Profile picker: `Flat`, `Grooves`, `Dimples`, `Noise` chips.
Sliders for frequency (1–50), amplitude (0–1), angle (0–360).

- [ ] **Step 4: Run analyze + tests, commit**

```bash
flutter analyze
flutter test
git add lib/src/debug/light_debug_controller.dart lib/src/debug/light_debug_overlay.dart
git commit -m "feat(lit_ui): debug overlay material/profile picker"
```

---

## Chunk 6: Integration Test

### Task 11: Write integration test verifying shader loads and renders

**Files:**
- Create: `test/lit_shader_test.dart`

- [ ] **Step 1: Write test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('LitShader', () {
    test('isLoaded is false before load', () {
      expect(LitShader.isLoaded, false);
    });

    test('createShader returns null when not loaded', () {
      final result = LitShader.createShader(
        size: const Size(100, 100),
        baseColor: const Color(0xFF4488CC),
        material: SurfaceMaterial.matte,
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

- [ ] **Step 2: Run test, commit**

```bash
flutter test test/lit_shader_test.dart
git add test/lit_shader_test.dart
git commit -m "test(lit_ui): shader loader fallback tests"
```

---

## Notes

- **Shader loading is async.** Widgets must gracefully fall back to Canvas-based rendering when `LitShader.isLoaded` is false. The consuming app should call `await LitShader.load()` during startup (e.g., in `main()` before `runApp`).
- **Multi-light support** in the shader is deferred — the initial version passes only the first light. The TODO in `LitShader.createShader` marks where to extend this. Canvas-based border/shadow painting already handles multi-light.
- **The `metallic` naming conflict** (static preset vs instance property) needs resolution in Step 3 of Task 1. Options: rename preset to `polishedMetal`, or use a different naming convention for presets.
- **GLSL `#version 460 core`** may need adjustment per Flutter's backend. The `#include <flutter/runtime_effect.glsl>` directive and `FlutterFragCoord()` are Flutter-specific. Test on target platforms.
