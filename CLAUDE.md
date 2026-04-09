# CLAUDE.md — lit_ui

A physically-inspired lighting and materials system for Flutter UI. Widgets derive their gradients, borders, shadows, and per-pixel surface detail automatically from a configurable scene of light sources and PBR-inspired materials.

## Build & Test

```bash
cd packages/lit_ui
flutter pub get
flutter test                          # 120 unit tests
flutter test test/light_types_test.dart  # Single file
```

## Architecture

### Four-Layer Design

1. **Light Definition** (`light_types.dart`) — Four immutable light types extending `SceneLight`:
   - `DirectionalLight` — Parallel rays (sunlight). Uniform direction/intensity everywhere.
   - `PointLight` — Omnidirectional from a point with inverse-power falloff.
   - `SpotLight` — Cone-shaped with soft/hard edge control.
   - `AreaLight` — Soft rectangular source, gentler falloff than PointLight.

2. **Scene Management** (`light_scene.dart`, `light_theme.dart`) — `LightScene` holds an ordered list of lights plus `ambientSky`/`ambientGround` colors for hemisphere ambient lighting (default white = no tint). `LightTheme` (InheritedWidget) provides the scene to descendants.

3. **Materials & Profiles** (`surface_material.dart`, `surface_profile.dart`, `material_theme.dart`) — `SurfaceMaterial` describes PBR-inspired properties (roughness, metallic, fresnel, sheen, clearcoat, translucency). `SurfaceProfile` defines procedural heightmaps (grooves, dimples, noise). `LitMaterialTheme` provides preset overrides to the widget subtree.

4. **Resolution & Rendering** (`light_resolver.dart`, `lighting_math.dart`, `lit_shader.dart`) — `LightResolver` blends all lights in a single pass into a `ResolvedLight`. `LightingEngine` computes fill gradients, border sweeps, and shadows for the Canvas fallback. `LitShader` provides GPU-accelerated per-pixel lighting via a GLSL fragment shader supporting up to 4 simultaneous lights, SDF-based border rendering, hemisphere ambient, normal map textures, and translucency.

### Shader System

`LitShader.load()` must be called once at app startup (async). After loading, widgets with a `material` set automatically use the GPU shader path:

- **Unified fill + border** in a single draw call using SDF rounded rect geometry
- **Per-pixel Blinn-Phong lighting** with diffuse, specular, fresnel, sheen, clearcoat
- **Up to 4 simultaneous lights** accumulated additively
- **Hemisphere ambient** (sky/ground tint based on surface normal)
- **Normal map textures** for hand-authored surface detail
- **Translucency** with alpha separation (highlights stay opaque)
- **Inset shadow bands** for concave/etched border effects (outer + inner shadow with independent intensity and width)
- **Canvas fallback** when shader isn't loaded (SweepGradient borders, gradient fills)

Uniform layout: 62 float uniforms + 1 image sampler. See `lit_shader.dart` doc comment for the full index table.

### Materials

| Preset | Character |
|--------|-----------|
| `SurfaceMaterial.polishedMetal` | Tight bright highlights, base-color-tinted specular |
| `SurfaceMaterial.matte` | Broad even light, white highlights, gentle gradients |
| `SurfaceMaterial.fuzzy` | Scattered light, velvet sheen at edges |
| `SurfaceMaterial.glossy` | Smooth dielectric, strong fresnel, sharp specular |
| `SurfaceMaterial.lacquered` | Rough base with glossy clearcoat layer |
| `SurfaceMaterial.glass` | Transparent, strong fresnel edges, sharp specular |
| `SurfaceMaterial.frostedGlass` | Translucent with diffused light, backdrop blur |

### Surface Profiles

| Pattern | Description |
|---------|-------------|
| `SurfaceProfile.flat` | No texture (default) |
| `SurfaceProfile.grooves()` | Parallel sinusoidal ridges |
| `SurfaceProfile.dimples()` | 2D sine grid (egg-crate) |
| `SurfaceProfile.noise()` | Hash-based pseudo-random bumps |

### Angle Convention

All angles are **clockwise from top (12 o'clock)** in radians:
- `0` = top, `π/2` = right, `π` = bottom, `3π/2` = left

### Direction Semantics

`directionAt(surfacePoint)` returns a unit vector **FROM the surface TOWARD the light**.

### Elevation Model

- `DirectionalLight` → fixed elevation `0.6`
- Positional lights → `height / 800`, clamped to `[0, 1]`

## Widgets

| Widget | Purpose |
|--------|---------|
| `LitButton` | Interactive button with per-light shadows, fill gradients, hover state |
| `LitSurface` | Container/background with lighting-derived border and fill |
| `LitEdgeBorder` | Decorative top + left border with sweep gradient |
| `LitInputBorder` | Concave inset border for input fields with shader-rendered shadow bands (`outerShadowIntensity`, `outerShadowWidth`, `innerShadowIntensity`, `innerShadowWidth`) |

All widgets accept an optional `scene` parameter; if omitted they read from `LightTheme.of(context)`.

When a `material` is set and the shader is loaded, `LitButton`, `LitSurface`, and `LitInputBorder` render via GPU draw calls using SDF-based rounded rect geometry. The Canvas-based SweepGradient border and gradient fill remain as the fallback.

### Common Widget Parameters

- `baseColor` — Surface color before lighting
- `elevation` — Shadow distance multiplier
- `curvature` — Fill gradient strength (`0` = flat, `1` = very convex)
- `fillContrast` / `borderContrast` — Multipliers for gradient depth
- `borderRadius`, `borderWidth`, `padding` — Standard layout params
- `material` — PBR surface material; when set, the GLSL shader renders fill+border
- `profile` — Procedural heightmap for per-pixel normal perturbation
- `normalMap` — Optional `ui.Image` normal map texture for per-pixel surface detail (requires shader)

## Debug System

- `LightDebugOverlay` — Wrap the app to get an interactive panel for adding/editing/removing lights at runtime
- `LightDebugController` — ChangeNotifier managing debug UI state, light selection, cursor-follow mode

```dart
LightDebugOverlay(
  enabled: kDebugMode,
  defaultScene: LightScene.directional(angle: 0, intensity: 0.65),
  child: MyApp(),
)
```

## Usage

```dart
import 'package:lit_ui/lit_ui.dart';

// Load shader at startup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LitShader.load();
  runApp(MyApp());
}

// Provide a light scene with ambient
LightTheme(
  scene: LightScene(
    lights: [
      DirectionalLight(angle: 0, intensity: 0.6),
      PointLight(position: Offset(300, 150), height: 200, intensity: 0.4),
    ],
    ambientSky: Color(0xFFE8F0FF),
    ambientGround: Color(0xFFFFF0E0),
  ),
  child: MyApp(),
)

// Widgets with materials get per-pixel GPU lighting
LitButton(
  onTap: () {},
  baseColor: Colors.blue,
  material: SurfaceMaterial.glossy,
  child: Text('Click me'),
)

// Glass surface with backdrop blur
LitSurface(
  baseColor: Colors.white,
  material: SurfaceMaterial.frostedGlass,
  child: Text('Frosted panel'),
)
```

## Exports (from `lit_ui.dart`)

`SceneLight`, `DirectionalLight`, `PointLight`, `SpotLight`, `AreaLight`, `LightScene`, `LightTheme`, `LightResolver`, `ResolvedLight`, `LightingEngine`, `SurfaceLighting`, `LitButton`, `LitSurface`, `LitEdgeBorder`, `LitInputBorder`, `LightDebugController`, `LightDebugOverlay`, `SurfaceMaterial`, `SurfaceProfile`, `SurfacePattern`, `LitShader`, `LitMaterialTheme`, `Light` (deprecated)

## Code Style

- Single quotes for strings
- All light/material/profile classes are `const` and immutable
- Override `==` and `hashCode` for all data/light classes
- `dart:math as math` for trig
- HSL color space for lightness adjustments
- Custom painting via `CustomPaint` / `Canvas` (fallback) or `FragmentShader` (primary)

## Dependencies

- `flutter_animate` — used for hover transitions in `LitButton`

## Known Sharp Edges

- The deprecated `Light` class in `light.dart` predates the `SceneLight` hierarchy — use `SceneLight` subclasses for new code
- Light heights are in arbitrary pixel units; elevation is normalized internally
- `LitShader.load()` is async; widgets fall back to Canvas rendering until loaded
- Shader supports max 4 lights; lights beyond 4 are handled by the Canvas fallback only
- `normalMap` requires a pre-loaded `ui.Image` — load it before passing to widgets
- After modifying the `.frag` shader, run `flutter clean` to clear the compiled shader cache
- `LitShader` always binds a 1x1 dummy image to sampler 0 when no `normalMap` is provided — CanvasKit/web crashes on unbound samplers even in unreachable branches
- SDF border rendering may show subtle artifacts at the border/fill transition zone — tunable via smoothstep thresholds in `lit_surface.frag`
