import 'package:flutter/material.dart';
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
