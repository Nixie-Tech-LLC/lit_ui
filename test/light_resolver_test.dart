import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/src/light_types.dart';
import 'package:lit_ui/src/light_scene.dart';
import 'package:lit_ui/src/light_resolver.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  bool offsetClose(Offset a, Offset b, {double eps = 1e-6}) =>
      (a - b).distance < eps;

  // ── Single point light ─────────────────────────────────────────────────────

  group('single PointLight', () {
    test('direction points toward the light', () {
      // Light is directly above-left: position (0, 0), surface at (100, 100).
      final scene = LightScene(lights: [
        PointLight(
          position: const Offset(0, 0),
          height: 200,
          intensity: 1.0,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: const Offset(100, 100),
      );
      // XY delta from surface to light: (0-100, 0-100) = (-100, -100)
      // Normalised: (-1/sqrt2, -1/sqrt2)
      final expected = const Offset(-100, -100) / math.sqrt(2 * 100 * 100);
      expect(offsetClose(resolved.direction, expected), isTrue,
          reason: 'direction should point toward the light');
    });

    test('intensity is non-zero', () {
      final scene = LightScene(lights: [
        PointLight(
          position: const Offset(100, 100),
          height: 200,
          intensity: 0.8,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: const Offset(100, 100),
      );
      expect(resolved.intensity, greaterThan(0));
    });
  });

  // ── Two equal lights on opposite sides ────────────────────────────────────

  group('two equal lights on opposite sides', () {
    test('horizontal directions cancel — resultant direction is near zero or vertical', () {
      // Light A: to the left at (-200, 0); Light B: to the right at (200, 0).
      // Surface at origin. Both have the same intensity and are equidistant.
      const surface = Offset(0, 0);
      final scene = LightScene(lights: [
        PointLight(
          position: const Offset(-200, 0),
          height: 100,
          intensity: 0.6,
        ),
        PointLight(
          position: const Offset(200, 0),
          height: 100,
          intensity: 0.6,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: surface,
      );
      // X components should cancel — dx close to 0.
      expect(resolved.direction.dx.abs(), lessThan(1e-6),
          reason: 'x components must cancel due to symmetry');
    });
  });

  // ── Closer point light dominates ──────────────────────────────────────────

  group('closer PointLight dominates', () {
    test('direction biased toward closer light', () {
      // Both lights are on the x-axis but at different distances.
      // Close light: (50, 0), Far light: (500, 0). Same intensity.
      const surface = Offset(0, 0);
      final scene = LightScene(lights: [
        PointLight(
          position: const Offset(50, 0),
          height: 50,
          intensity: 1.0,
        ),
        PointLight(
          position: const Offset(-500, 0),
          height: 50,
          intensity: 1.0,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: surface,
      );
      // The close light is to the right (+x) and gets higher intensityAt,
      // so the blended direction should have dx > 0.
      expect(resolved.direction.dx, greaterThan(0),
          reason: 'closer light contributes more, dx should be positive');
    });
  });

  // ── DirectionalLight produces same result regardless of position ──────────

  group('DirectionalLight position-independence', () {
    test('resolved direction is the same at any surfaceCenter', () {
      final scene = LightScene(lights: [
        DirectionalLight(angle: math.pi / 3, intensity: 0.7),
      ]);
      final r1 = LightResolver.resolve(
          scene: scene, surfaceCenter: const Offset(0, 0));
      final r2 = LightResolver.resolve(
          scene: scene, surfaceCenter: const Offset(400, 300));
      final r3 = LightResolver.resolve(
          scene: scene, surfaceCenter: const Offset(-200, 800));

      expect(offsetClose(r1.direction, r2.direction), isTrue);
      expect(offsetClose(r1.direction, r3.direction), isTrue);
      expect(r1.intensity, closeTo(r2.intensity, 1e-9));
    });
  });

  // ── Empty scene returns zero ───────────────────────────────────────────────

  group('empty scene', () {
    test('returns ResolvedLight.zero', () {
      final scene = LightScene(lights: const []);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: const Offset(100, 100),
      );
      expect(resolved.intensity, equals(0.0));
      expect(resolved.direction, equals(Offset.zero));
      expect(resolved.elevation, equals(0.0));
    });
  });

  // ── LightScene.directional factory ────────────────────────────────────────

  group('LightScene.directional factory', () {
    test('wraps a single DirectionalLight', () {
      final scene = LightScene.directional(angle: 0, intensity: 0.5);
      expect(scene.lights.length, equals(1));
      expect(scene.lights.first, isA<DirectionalLight>());
      final dl = scene.lights.first as DirectionalLight;
      expect(dl.angle, equals(0.0));
      expect(dl.intensity, equals(0.5));
      expect(dl.color, equals(const Color(0xFFFFFFFF)));
    });
  });

  // ── LightScene equality ───────────────────────────────────────────────────

  group('LightScene equality', () {
    test('two scenes with identical lights are equal', () {
      final a = LightScene(lights: [DirectionalLight(angle: 0, intensity: 0.5)]);
      final b = LightScene(lights: [DirectionalLight(angle: 0, intensity: 0.5)]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('scenes with different lights are not equal', () {
      final a = LightScene(lights: [DirectionalLight(angle: 0, intensity: 0.5)]);
      final b = LightScene(lights: [DirectionalLight(angle: 1, intensity: 0.5)]);
      expect(a, isNot(equals(b)));
    });
  });

  // ── Mixed: DirectionalLight + PointLight ──────────────────────────────────

  group('mixed DirectionalLight + PointLight', () {
    test('blended direction is between the two individual directions', () {
      // Directional light from the right (angle = pi/2 → direction (1, 0)).
      // Point light from the top (position above surface → direction (0, -1)).
      const surface = Offset(200, 200);
      final scene = LightScene(lights: [
        DirectionalLight(angle: math.pi / 2, intensity: 0.5), // from right
        PointLight(
          position: const Offset(200, 0),  // directly above surface
          height: 100,
          intensity: 0.5,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: surface,
      );
      // Directional contributes dx > 0; PointLight contributes dy < 0.
      // The blend should have dx > 0 and dy < 0.
      expect(resolved.direction.dx, greaterThan(0),
          reason: 'directional light pushes dx positive');
      expect(resolved.direction.dy, lessThan(0),
          reason: 'point light above pushes dy negative');
    });

    test('blended color is not pure white when one light is colored', () {
      const surface = Offset(0, 0);
      final scene = LightScene(lights: [
        DirectionalLight(
          angle: 0,
          intensity: 0.8,
          color: const Color(0xFFFF0000), // red
        ),
        PointLight(
          position: const Offset(0, 0),
          height: 100,
          intensity: 0.8,
          color: const Color(0xFF0000FF), // blue
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: surface,
      );
      // Blended color must not be pure white — has non-trivial R and B.
      expect(resolved.color.r, greaterThan(0));
      expect(resolved.color.b, greaterThan(0));
    });

    test('elevation is between 0 and 1', () {
      const surface = Offset(100, 100);
      final scene = LightScene(lights: [
        DirectionalLight(angle: 0, intensity: 0.6),
        PointLight(
          position: const Offset(100, 100),
          height: 400,
          intensity: 0.6,
        ),
      ]);
      final resolved = LightResolver.resolve(
        scene: scene,
        surfaceCenter: surface,
      );
      expect(resolved.elevation, greaterThanOrEqualTo(0.0));
      expect(resolved.elevation, lessThanOrEqualTo(1.0));
    });
  });

  // ── ResolvedLight.zero ─────────────────────────────────────────────────────

  group('ResolvedLight.zero', () {
    test('has zero intensity, zero direction, zero elevation', () {
      final z = ResolvedLight.zero;
      expect(z.intensity, equals(0.0));
      expect(z.direction, equals(Offset.zero));
      expect(z.elevation, equals(0.0));
    });
  });
}
