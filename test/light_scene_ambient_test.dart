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
