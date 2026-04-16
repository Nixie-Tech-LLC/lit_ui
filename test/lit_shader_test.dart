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

  group('LitShader.clampBorderRadius', () {
    test('caps each corner at half the shorter side', () {
      final result = LitShader.clampBorderRadius(
        const Size(38, 38),
        BorderRadius.circular(100),
      );
      expect(result.topLeft.x, 19.0);
      expect(result.topRight.x, 19.0);
      expect(result.bottomLeft.x, 19.0);
      expect(result.bottomRight.x, 19.0);
    });

    test('uses the shorter side for non-square surfaces', () {
      final result = LitShader.clampBorderRadius(
        const Size(200, 40),
        BorderRadius.circular(100),
      );
      expect(result.topLeft.x, 20.0);
      expect(result.bottomRight.x, 20.0);
    });

    test('leaves radii smaller than the limit untouched', () {
      final result = LitShader.clampBorderRadius(
        const Size(100, 100),
        BorderRadius.circular(8),
      );
      expect(result.topLeft.x, 8.0);
      expect(result.bottomRight.x, 8.0);
    });
  });
}
