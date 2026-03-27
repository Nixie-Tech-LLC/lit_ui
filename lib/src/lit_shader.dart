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
/// Uniform layout (62 floats):
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
/// | 45    | uBorderWidth    | borderWidth                       |
/// | 46-49 | uBorderRadius   | topLeft, topRight, bottomRight, bottomLeft |
/// | 50-52 | uAmbientSky     | ambientSky r/g/b                          |
/// | 53-55 | uAmbientGround  | ambientGround r/g/b                       |
/// | 56    | uUseNormalMap   | 0.0 = procedural, 1.0 = texture            |
/// | 57    | uTranslucency   | material.translucency                      |
/// | 58    | uOuterShadowIntensity   | outerShadowIntensity (0.0 default)         |
/// | 59    | uOuterShadowWidth       | outerShadowWidth (0.0 default)             |
/// | 60    | uInnerShadowIntensity   | innerShadowIntensity (0.0 default)         |
/// | 61    | uInnerShadowWidth       | innerShadowWidth (0.0 default)             |
/// | 62    | uOverlay                | overlay (0.0 default)                      |
///
/// Sampler layout:
///
/// | Index | Name        | Source     |
/// |-------|-------------|------------|
/// | 0     | uNormalMap  | normalMap  |
class LitShader {
  LitShader._();

  static ui.FragmentProgram? _program;

  /// A 1x1 flat-normal image (128,128,255 = normal facing viewer) used as
  /// a dummy sampler binding when no normal map is provided. Some GPU
  /// backends (notably CanvasKit on web) crash if a declared sampler2D
  /// has no image bound, even when the texture() call is in an unreachable branch.
  static ui.Image? _flatNormalImage;

  /// Maximum number of lights the shader supports.
  static const maxLights = 4;

  /// Loads the fragment shader from the package asset bundle.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops once the
  /// program has been loaded successfully.
  static Future<void> load() async {
    if (_program != null) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/lit_ui/shaders/lit_surface.frag',
      );
    } catch (_) {
      // Shader compilation failed (e.g. unsupported platform).
      // Widgets will fall back to Canvas rendering.
      return;
    }
    // Create a 1x1 flat-normal dummy image for unbound sampler slots.
    // Some GPU backends (CanvasKit/web) crash if a declared sampler2D
    // has no image bound, even in unreachable shader branches.
    if (_flatNormalImage == null) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
      canvas.drawColor(const Color(0xFF8080FF), BlendMode.src);
      final picture = recorder.endRecording();
      _flatNormalImage = await picture.toImage(1, 1);
      picture.dispose();
    }
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
    double borderWidth = 0.0,
    BorderRadius borderRadius = BorderRadius.zero,
    ui.Image? normalMap,
    double outerShadowIntensity = 0.0,
    double outerShadowWidth = 0.0,
    double innerShadowIntensity = 0.0,
    double innerShadowWidth = 0.0,
    bool overlay = false,
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

    // ── Border (uniforms 45-49) ──
    shader.setFloat(45, borderWidth);
    shader.setFloat(46, borderRadius.topLeft.x);
    shader.setFloat(47, borderRadius.topRight.x);
    shader.setFloat(48, borderRadius.bottomRight.x);
    shader.setFloat(49, borderRadius.bottomLeft.x);

    // ── Ambient (uniforms 50-55) ──
    shader.setFloat(50, scene.ambientSky.r);
    shader.setFloat(51, scene.ambientSky.g);
    shader.setFloat(52, scene.ambientSky.b);
    shader.setFloat(53, scene.ambientGround.r);
    shader.setFloat(54, scene.ambientGround.g);
    shader.setFloat(55, scene.ambientGround.b);

    // ── Normal map (uniform 56 + sampler 0) ──
    // Always bind a sampler image — some GPU backends (CanvasKit/web) crash
    // if a declared sampler2D has no image bound, even in unreachable branches.
    shader.setFloat(56, normalMap != null ? 1.0 : 0.0);
    shader.setImageSampler(0, normalMap ?? _flatNormalImage!);

    // ── Translucency (uniform 57) ──
    shader.setFloat(57, material.translucency);

    // ── Inset shadow bands (uniforms 58-61) ──
    shader.setFloat(58, outerShadowIntensity);
    shader.setFloat(59, outerShadowWidth);
    shader.setFloat(60, innerShadowIntensity);
    shader.setFloat(61, innerShadowWidth);

    // ── Overlay (uniform 62) ──
    shader.setFloat(62, overlay ? 1.0 : 0.0);

    return shader;
  }
}
