import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/src/lighting_math.dart';
import 'package:lit_ui/src/light_resolver.dart';

void main() {
  // ── computeResolved: light from top ───────────────────────────────────────

  group('computeResolved — light from top', () {
    // direction Offset(0, -1): unit vector pointing FROM surface TOWARD the
    // light, which is above the surface (negative y in Flutter coords).
    const lightFromTop = ResolvedLight(
      direction: Offset(0, -1),
      intensity: 1.0,
      color: Color(0xFFFFFFFF),
      elevation: 0.6,
    );

    test('top face is lighter than bottom face when curvature > 0', () {
      final result = LightingEngine.computeResolved(
        light: lightFromTop,
        baseColor: const Color(0xFF888888),
        curvature: 0.5,
      );

      // lightFaceColor corresponds to the gradient begin (light side),
      // darkFaceColor to gradient end (shadow side).
      final lightL = HSLColor.fromColor(result.lightFaceColor).lightness;
      final darkL = HSLColor.fromColor(result.darkFaceColor).lightness;

      expect(lightL, greaterThan(darkL),
          reason: 'light face should be brighter than dark face');
    });

    test('gradient begin is at top (negative y alignment)', () {
      final result = LightingEngine.computeResolved(
        light: lightFromTop,
        baseColor: const Color(0xFF888888),
        curvature: 0.5,
      );

      // Light comes from top → gradient begins at top → Alignment(0, -1).
      expect(result.gradientBegin, equals(const Alignment(0, -1)));
      expect(result.gradientEnd, equals(const Alignment(0, 1)));
    });

    test('shadow offset is downward (positive y) for light from top', () {
      final result = LightingEngine.computeResolved(
        light: lightFromTop,
        baseColor: const Color(0xFF888888),
        surfaceElevation: 8,
      );

      // Shadow is cast opposite to light direction (light from top → shadow
      // falls downward → positive dy).
      expect(result.shadowOffset.dy, greaterThan(0),
          reason: 'shadow should fall downward when light is above');
      expect(result.shadowOffset.dx, closeTo(0.0, 1e-9),
          reason: 'no horizontal shadow component for perfectly top light');
    });
  });

  // ── computeResolved: zero intensity ───────────────────────────────────────

  group('computeResolved — zero intensity', () {
    test('light face equals dark face (no gradient) when intensity is 0', () {
      const noLight = ResolvedLight(
        direction: Offset(0, -1),
        intensity: 0.0,
        color: Color(0xFFFFFFFF),
        elevation: 0.6,
      );

      final result = LightingEngine.computeResolved(
        light: noLight,
        baseColor: const Color(0xFF888888),
        curvature: 0.5,
      );

      expect(result.lightFaceColor, equals(result.darkFaceColor),
          reason: 'zero intensity means no fill gradient difference');
    });
  });

  // ── computeResolved: zero curvature ───────────────────────────────────────

  group('computeResolved — zero curvature', () {
    test('light face equals dark face when curvature is 0', () {
      const light = ResolvedLight(
        direction: Offset(0.7071, -0.7071), // top-right
        intensity: 1.0,
        color: Color(0xFFFFFFFF),
        elevation: 0.6,
      );

      final result = LightingEngine.computeResolved(
        light: light,
        baseColor: const Color(0xFF4488CC),
        curvature: 0.0,
      );

      expect(result.lightFaceColor, equals(result.darkFaceColor),
          reason: 'flat surface (curvature=0) has no fill gradient');
    });
  });

  // ── computeResolved: shadow direction ─────────────────────────────────────

  group('computeResolved — shadow direction matches opposite of light', () {
    test('light from right → shadow points left (negative x)', () {
      const lightFromRight = ResolvedLight(
        direction: Offset(1, 0),
        intensity: 1.0,
        color: Color(0xFFFFFFFF),
        elevation: 0.0, // horizontal light → maximum shadow distance
      );

      final result = LightingEngine.computeResolved(
        light: lightFromRight,
        baseColor: const Color(0xFF888888),
        surfaceElevation: 8,
      );

      expect(result.shadowOffset.dx, lessThan(0),
          reason: 'light from right → shadow offset is to the left (dx < 0)');
      expect(result.shadowOffset.dy, closeTo(0.0, 1e-9),
          reason: 'no vertical shadow for purely horizontal light');
    });

    test('light from bottom-left → shadow points top-right', () {
      // Normalised direction for bottom-left: (-0.7071, 0.7071).
      const lightFromBottomLeft = ResolvedLight(
        direction: Offset(-0.7071, 0.7071),
        intensity: 1.0,
        color: Color(0xFFFFFFFF),
        elevation: 0.0,
      );

      final result = LightingEngine.computeResolved(
        light: lightFromBottomLeft,
        baseColor: const Color(0xFF888888),
        surfaceElevation: 8,
      );

      // Shadow is opposite: dx > 0 (right), dy < 0 (up = negative y).
      expect(result.shadowOffset.dx, greaterThan(0));
      expect(result.shadowOffset.dy, lessThan(0));
    });
  });
}
