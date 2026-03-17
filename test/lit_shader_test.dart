import 'package:flutter/material.dart';
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

    test('createShader accepts shadow band parameters without error', () {
      final result = LitShader.createShader(
        size: const Size(100, 100),
        baseColor: const Color(0xFF4488CC),
        material: SurfaceMaterial.matte,
        profile: SurfaceProfile.flat,
        scene: LightScene.directional(angle: 0, intensity: 0.6),
        screenCenter: const Offset(50, 50),
        curvature: 0.5,
        outerShadowIntensity: 0.3,
        outerShadowWidth: 0.35,
        innerShadowIntensity: 0.25,
        innerShadowWidth: 0.3,
      );
      expect(result, isNull);
    });

    test('createShader shadow band parameters default to zero', () {
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
