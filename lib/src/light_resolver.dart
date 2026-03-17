import 'package:flutter/material.dart';

import 'light_types.dart';
import 'light_scene.dart';

// ── ResolvedLight ─────────────────────────────────────────────────────────────

/// The blended lighting result at a specific surface position.
///
/// Produced by [LightResolver.resolve].
class ResolvedLight {
  const ResolvedLight({
    required this.direction,
    required this.intensity,
    required this.color,
    required this.elevation,
  });

  /// Unit vector pointing FROM the surface TOWARD the dominant light direction.
  /// Zero vector when [intensity] is 0 (no lights or all lights at zero).
  final Offset direction;

  /// Combined intensity at the resolved position, in [0, 1].
  final double intensity;

  /// Blended color of all contributing lights.
  final Color color;

  /// Effective elevation of the dominant light, in [0, 1].
  ///
  /// Used for shadow computation:
  /// - 0   → light is horizontal (long shadows)
  /// - 1   → light is directly overhead (no shadow)
  ///
  /// PointLight / SpotLight / AreaLight derive elevation from `height / 800`
  /// clamped to [0, 1].  DirectionalLight defaults to 0.6.
  final double elevation;

  /// A resolved light with zero intensity — returned when the scene is empty.
  static const ResolvedLight zero = ResolvedLight(
    direction: Offset.zero,
    intensity: 0.0,
    color: Color(0xFFFFFFFF),
    elevation: 0.0,
  );

  @override
  String toString() => 'ResolvedLight('
      'direction: $direction, '
      'intensity: $intensity, '
      'color: $color, '
      'elevation: $elevation)';
}

// ── LightResolver ─────────────────────────────────────────────────────────────

/// Resolves a [LightScene] at a given [surfaceCenter] position into a single
/// [ResolvedLight] value by blending all scene lights in a single pass.
abstract final class LightResolver {
  LightResolver._();

  /// Resolve [scene] at [surfaceCenter] into a blended [ResolvedLight].
  ///
  /// Algorithm (single pass):
  /// 1. For each light, query [SceneLight.intensityAt] and
  ///    [SceneLight.directionAt].
  /// 2. Accumulate:
  ///    - Weighted direction (weight = per-light intensity at point).
  ///    - Weighted RGB color (weight = per-light intensity at point).
  ///    - Weighted elevation (weight = per-light intensity at point).
  ///    - Total intensity weight.
  /// 3. Divide accumulators by total weight to get averages, normalise
  ///    direction to a unit vector.
  ///
  /// Returns [ResolvedLight.zero] for empty scenes.
  static ResolvedLight resolve({
    required LightScene scene,
    required Offset surfaceCenter,
  }) {
    if (scene.lights.isEmpty) return ResolvedLight.zero;

    double totalWeight = 0.0;
    double accumDx = 0.0;
    double accumDy = 0.0;
    double accumR = 0.0;
    double accumG = 0.0;
    double accumB = 0.0;
    double accumElevation = 0.0;

    for (final light in scene.lights) {
      final w = light.intensityAt(surfaceCenter);
      if (w <= 0.0) continue;

      final dir = light.directionAt(surfaceCenter);
      accumDx += dir.dx * w;
      accumDy += dir.dy * w;

      accumR += light.color.r * w;
      accumG += light.color.g * w;
      accumB += light.color.b * w;

      final elev = _elevationFor(light);
      accumElevation += elev * w;

      totalWeight += w;
    }

    if (totalWeight == 0.0) return ResolvedLight.zero;

    // Weighted-average color and elevation.
    final blendedColor = Color.from(
      alpha: 1.0,
      red: (accumR / totalWeight).clamp(0.0, 1.0),
      green: (accumG / totalWeight).clamp(0.0, 1.0),
      blue: (accumB / totalWeight).clamp(0.0, 1.0),
    );
    final blendedElevation = (accumElevation / totalWeight).clamp(0.0, 1.0);

    // Normalise blended direction vector.
    final rawDir = Offset(accumDx, accumDy);
    final rawLen = rawDir.distance;
    final normalised = rawLen > 0 ? rawDir / rawLen : Offset.zero;

    // Clamp total intensity to [0, 1].
    final intensity = totalWeight.clamp(0.0, 1.0);

    return ResolvedLight(
      direction: normalised,
      intensity: intensity,
      color: blendedColor,
      elevation: blendedElevation,
    );
  }

  /// Returns the elevation contribution for [light].
  ///
  /// - [PointLight], [SpotLight], [AreaLight]: `height / 800` clamped to [0, 1].
  /// - [DirectionalLight]: constant 0.6.
  static double _elevationFor(SceneLight light) {
    if (light is DirectionalLight) return 0.6;
    if (light is PointLight) return (light.height / 800.0).clamp(0.0, 1.0);
    if (light is SpotLight) return (light.height / 800.0).clamp(0.0, 1.0);
    if (light is AreaLight) return (light.height / 800.0).clamp(0.0, 1.0);
    // Fallback for unknown subclasses.
    return 0.5;
  }
}
