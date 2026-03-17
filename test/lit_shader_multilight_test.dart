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
