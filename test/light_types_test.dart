import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/src/light_types.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns true when two Offsets are close enough (within [eps]).
  bool offsetClose(Offset a, Offset b, {double eps = 1e-9}) {
    return (a - b).distance < eps;
  }

  // ── DirectionalLight ─────────────────────────────────────────────────────

  group('DirectionalLight', () {
    test('angle=0 (light from top) returns direction (0, -1)', () {
      final light = DirectionalLight(angle: 0, intensity: 1.0);
      final dir = light.directionAt(const Offset(100, 200));
      expect(dir.dx, closeTo(0.0, 1e-9));
      expect(dir.dy, closeTo(-1.0, 1e-9));
    });

    test('angle=pi/2 (light from right) returns direction (1, 0)', () {
      final light = DirectionalLight(angle: math.pi / 2, intensity: 1.0);
      final dir = light.directionAt(const Offset(50, 50));
      expect(dir.dx, closeTo(1.0, 1e-9));
      expect(dir.dy, closeTo(0.0, 1e-9));
    });

    test('angle=pi (light from bottom) returns direction (0, 1)', () {
      final light = DirectionalLight(angle: math.pi, intensity: 1.0);
      final dir = light.directionAt(const Offset(0, 0));
      expect(dir.dx, closeTo(0.0, 1e-9));
      expect(dir.dy, closeTo(1.0, 1e-9));
    });

    test('angle=3*pi/2 (light from left) returns direction (-1, 0)', () {
      final light =
          DirectionalLight(angle: 3 * math.pi / 2, intensity: 1.0);
      final dir = light.directionAt(const Offset(0, 0));
      expect(dir.dx, closeTo(-1.0, 1e-9));
      expect(dir.dy, closeTo(0.0, 1e-9));
    });

    test('direction is the same regardless of surfacePoint', () {
      final light = DirectionalLight(angle: math.pi / 4, intensity: 0.8);
      final d1 = light.directionAt(const Offset(0, 0));
      final d2 = light.directionAt(const Offset(500, 300));
      final d3 = light.directionAt(const Offset(-100, 900));
      expect(offsetClose(d1, d2), isTrue);
      expect(offsetClose(d1, d3), isTrue);
    });

    test('directionAt returns a unit vector', () {
      final light = DirectionalLight(angle: 1.23, intensity: 0.6);
      final dir = light.directionAt(const Offset(200, 150));
      expect(dir.distance, closeTo(1.0, 1e-9));
    });

    test('intensityAt returns constant intensity', () {
      final light = DirectionalLight(angle: 0, intensity: 0.7);
      expect(light.intensityAt(const Offset(0, 0)), equals(0.7));
      expect(light.intensityAt(const Offset(1000, 1000)), equals(0.7));
    });

    test('equality and hashCode', () {
      final a = DirectionalLight(angle: 1.0, intensity: 0.5);
      final b = DirectionalLight(angle: 1.0, intensity: 0.5);
      final c = DirectionalLight(angle: 2.0, intensity: 0.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ── PointLight ───────────────────────────────────────────────────────────

  group('PointLight', () {
    test('direction points from surfacePoint toward light position', () {
      // Light is directly to the right of the surface point.
      final light = PointLight(
        position: const Offset(200, 100),
        height: 100,
        intensity: 1.0,
      );
      final dir = light.directionAt(const Offset(100, 100));
      // XY delta: (200-100, 100-100) = (100, 0) → normalized = (1, 0)
      expect(dir.dx, closeTo(1.0, 1e-9));
      expect(dir.dy, closeTo(0.0, 1e-9));
    });

    test('direction points upward when light is directly above', () {
      final light = PointLight(
        position: const Offset(100, 0),
        height: 200,
        intensity: 1.0,
      );
      // Surface directly below the light (same XY), so XY delta is (0, -100).
      // That means direction is toward smaller y, i.e., dy < 0 (upward in
      // screen coords). Normalized: (0, -1).
      final dir = light.directionAt(const Offset(100, 100));
      expect(dir.dx, closeTo(0.0, 1e-9));
      expect(dir.dy, closeTo(-1.0, 1e-9));
    });

    test('direction is a unit vector', () {
      final light = PointLight(
        position: const Offset(300, 400),
        height: 150,
        intensity: 1.0,
      );
      final dir = light.directionAt(const Offset(100, 100));
      expect(dir.distance, closeTo(1.0, 1e-9));
    });

    test('intensity falls off with distance', () {
      final light = PointLight(
        position: const Offset(100, 100),
        height: 100,
        intensity: 1.0,
        falloff: 2.0,
      );
      // Close point — directly below the light (dist3d == height → full intensity).
      final closeIntensity = light.intensityAt(const Offset(100, 100));
      // Far point — much further away.
      final farIntensity = light.intensityAt(const Offset(500, 100));
      expect(closeIntensity, greaterThan(farIntensity));
    });

    test('directly below light (dist3d == height) gives full intensity', () {
      final light = PointLight(
        position: const Offset(100, 100),
        height: 100,
        intensity: 0.8,
        falloff: 1.0,
      );
      // Surface point at same XY as light position → xy dist = 0 →
      // dist3d = height → intensity / pow(1, 1) = 0.8.
      final i = light.intensityAt(const Offset(100, 100));
      expect(i, closeTo(0.8, 1e-9));
    });

    test('height affects angle (steepness) of illumination', () {
      // With a low-height light, points to the side still get high intensity
      // because the 3d distance doesn't grow as fast relative to height.
      // Actually, higher height means points to the side fall off more gently.
      final highLight = PointLight(
        position: const Offset(100, 100),
        height: 500,
        intensity: 1.0,
        falloff: 1.0,
      );
      final lowLight = PointLight(
        position: const Offset(100, 100),
        height: 50,
        intensity: 1.0,
        falloff: 1.0,
      );
      final sidePoint = const Offset(250, 100); // 150 px to the right
      // Both have same XY offset (150 px), but different heights.
      // dist3d(high) = sqrt(150^2 + 500^2); normalized = dist3d/500 = sqrt(1+0.09)
      // dist3d(low)  = sqrt(150^2 + 50^2);  normalized = dist3d/50  = sqrt(9+1)
      // high gives better intensity at the side point.
      expect(highLight.intensityAt(sidePoint),
          greaterThan(lowLight.intensityAt(sidePoint)));
    });

    test('equality and hashCode', () {
      final a = PointLight(
          position: const Offset(1, 2), height: 10, intensity: 0.5);
      final b = PointLight(
          position: const Offset(1, 2), height: 10, intensity: 0.5);
      final c = PointLight(
          position: const Offset(3, 4), height: 10, intensity: 0.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ── SpotLight ─────────────────────────────────────────────────────────────

  group('SpotLight', () {
    test('full intensity at the center of the cone', () {
      // Spot pointing straight down (positive y in screen coords).
      final light = SpotLight(
        position: const Offset(100, 0),
        height: 100,
        direction: const Offset(0, 1),
        coneAngle: math.pi / 4, // 45 deg half-angle
        softEdge: 0.1,
        falloff: 1.0,
        intensity: 1.0,
      );
      // Point directly below the spot → on-axis → full cone attenuation.
      final i = light.intensityAt(const Offset(100, 100));
      expect(i, greaterThan(0.5));
    });

    test('zero intensity outside the cone', () {
      // Spot pointing straight down (dy = 1) from Offset(100, 0).
      final light = SpotLight(
        position: const Offset(100, 0),
        height: 100,
        direction: const Offset(0, 1),
        coneAngle: math.pi / 8, // narrow 22.5 deg half-angle
        softEdge: 0.0,
        falloff: 1.0,
        intensity: 1.0,
      );
      // Point far to the side — well outside cone.
      final i = light.intensityAt(const Offset(1000, 100));
      expect(i, equals(0.0));
    });

    test('directionAt returns a unit vector', () {
      final light = SpotLight(
        position: const Offset(200, 200),
        height: 100,
        direction: const Offset(0, 1),
        coneAngle: math.pi / 4,
        softEdge: 0.1,
        falloff: 1.0,
        intensity: 1.0,
      );
      final dir = light.directionAt(const Offset(100, 100));
      expect(dir.distance, closeTo(1.0, 1e-9));
    });

    test('equality and hashCode', () {
      final a = SpotLight(
        position: const Offset(1, 2),
        height: 10,
        direction: const Offset(0, 1),
        coneAngle: 0.5,
        softEdge: 0.1,
        falloff: 1.0,
        intensity: 0.9,
      );
      final b = SpotLight(
        position: const Offset(1, 2),
        height: 10,
        direction: const Offset(0, 1),
        coneAngle: 0.5,
        softEdge: 0.1,
        falloff: 1.0,
        intensity: 0.9,
      );
      final c = SpotLight(
        position: const Offset(3, 4),
        height: 10,
        direction: const Offset(0, 1),
        coneAngle: 0.5,
        softEdge: 0.1,
        falloff: 1.0,
        intensity: 0.9,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ── AreaLight ─────────────────────────────────────────────────────────────

  group('AreaLight', () {
    test('intensity falls off with distance', () {
      final light = AreaLight(
        position: const Offset(100, 100),
        height: 100,
        size: const Size(50, 50),
        intensity: 1.0,
      );
      final near = light.intensityAt(const Offset(100, 100));
      final far = light.intensityAt(const Offset(1000, 100));
      expect(near, greaterThan(far));
    });

    test('softer falloff than equivalent PointLight at same distance', () {
      // AreaLight has a larger effective "normalization distance" than a point
      // light of the same height, so the same far point gets higher intensity
      // from the area light (it falls off more gently).
      const position = Offset(100, 100);
      const height = 100.0;
      const sidePoint = Offset(300, 100); // 200 px away

      final areaLight = AreaLight(
        position: position,
        height: height,
        size: const Size(200, 200), // large area → large halfDiagonal
        intensity: 1.0,
      );
      final pointLight = PointLight(
        position: position,
        height: height,
        intensity: 1.0,
        falloff: 1.0,
      );

      final areaI = areaLight.intensityAt(sidePoint);
      final pointI = pointLight.intensityAt(sidePoint);
      expect(areaI, greaterThan(pointI));
    });

    test('directionAt returns a unit vector', () {
      final light = AreaLight(
        position: const Offset(200, 200),
        height: 100,
        size: const Size(100, 100),
        intensity: 1.0,
      );
      final dir = light.directionAt(const Offset(100, 100));
      expect(dir.distance, closeTo(1.0, 1e-9));
    });

    test('equality and hashCode', () {
      final a = AreaLight(
        position: const Offset(1, 2),
        height: 10,
        size: const Size(50, 50),
        intensity: 0.5,
      );
      final b = AreaLight(
        position: const Offset(1, 2),
        height: 10,
        size: const Size(50, 50),
        intensity: 0.5,
      );
      final c = AreaLight(
        position: const Offset(3, 4),
        height: 10,
        size: const Size(50, 50),
        intensity: 0.5,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ── SceneLight interface ──────────────────────────────────────────────────

  group('SceneLight interface', () {
    test('all light types are SceneLight', () {
      final lights = <SceneLight>[
        DirectionalLight(angle: 0, intensity: 1.0),
        PointLight(
            position: const Offset(0, 0), height: 100, intensity: 1.0),
        SpotLight(
          position: const Offset(0, 0),
          height: 100,
          direction: const Offset(0, 1),
          coneAngle: 0.5,
          softEdge: 0.1,
          falloff: 1.0,
          intensity: 1.0,
        ),
        AreaLight(
          position: const Offset(0, 0),
          height: 100,
          size: const Size(50, 50),
          intensity: 1.0,
        ),
      ];
      expect(lights.length, equals(4));
    });

    test('all light types have a color property', () {
      final d = DirectionalLight(angle: 0, intensity: 1.0);
      final p =
          PointLight(position: const Offset(0, 0), height: 100, intensity: 1.0);
      expect(d.color, equals(Colors.white));
      expect(p.color, equals(Colors.white));
    });

    test('custom color is preserved', () {
      final light = DirectionalLight(
          angle: 0, intensity: 1.0, color: Colors.amber);
      expect(light.color, equals(Colors.amber));
    });
  });
}
