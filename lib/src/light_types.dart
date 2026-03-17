import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Abstract base ─────────────────────────────────────────────────────────────

/// Abstract base class for all light sources in a lit-UI scene.
///
/// Every light has:
/// - [intensity] — overall brightness contribution (0 = off, 1 = maximum).
/// - [color] — tint of the light (default white = neutral).
///
/// Subclasses implement:
/// - [directionAt] — unit vector FROM [surfacePoint] TOWARD the light source,
///   in Flutter screen coordinates (y-axis points downward).
/// - [intensityAt] — effective intensity at [surfacePoint] after any
///   distance/cone attenuation.
abstract class SceneLight {
  const SceneLight({
    required this.intensity,
    this.color = Colors.white,
    this.blendMode = BlendMode.srcOver,
  });

  /// Overall strength of the lighting effect (0–1).
  final double intensity;

  /// Color tint of the light. White = neutral, default.
  final Color color;

  /// How this light's fill gradient composites onto the base surface.
  final BlendMode blendMode;

  /// Unit vector pointing FROM [surfacePoint] TOWARD the light source,
  /// expressed in Flutter screen coordinates (y-axis points downward).
  Offset directionAt(Offset surfacePoint);

  /// Effective intensity at [surfacePoint] after distance / cone attenuation.
  /// Always clamped to [0, 1].
  double intensityAt(Offset surfacePoint);
}

// ── DirectionalLight ─────────────────────────────────────────────────────────

/// Parallel-ray light source — every point on the scene sees the same
/// direction and intensity (like sunlight).
///
/// [angle] is measured in radians **clockwise from the top** (12-o'clock),
/// matching the convention used by the existing [Light] class:
///   - 0       = light from top       → direction (0, -1)
///   - π/2     = light from right     → direction (1,  0)
///   - π       = light from bottom    → direction (0,  1)
///   - 3π/2    = light from left      → direction (-1, 0)
class DirectionalLight extends SceneLight {
  const DirectionalLight({
    required this.angle,
    required super.intensity,
    super.color,
    super.blendMode,
  });

  /// Direction light comes FROM, in radians clockwise from top.
  final double angle;

  /// Cached unit vector pointing FROM the surface TOWARD the light.
  ///
  /// Convention: identical to `-Light.directionToSurface` from `light.dart`.
  /// angle=0 → (sin 0, -cos 0) = (0, -1) — pointing toward top where light is.
  Offset get _direction => Offset(math.sin(angle), -math.cos(angle));

  @override
  Offset directionAt(Offset surfacePoint) => _direction;

  @override
  double intensityAt(Offset surfacePoint) => intensity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectionalLight &&
          angle == other.angle &&
          intensity == other.intensity &&
          color == other.color &&
          blendMode == other.blendMode;

  @override
  int get hashCode => Object.hash(DirectionalLight, angle, intensity, color, blendMode);

  @override
  String toString() =>
      'DirectionalLight(angle: $angle, intensity: $intensity, color: $color)';
}

// ── PointLight ───────────────────────────────────────────────────────────────

/// Omnidirectional light that radiates from a single point in screen space.
///
/// [position] is the XY location of the light in screen pixels.
/// [height] is the Z distance above the surface (pixels). Larger values
///   spread the light more evenly across the surface.
/// [falloff] controls the rate of intensity decay with distance (default 1.0).
///   Higher values → sharper falloff. Uses inverse-power attenuation normalised
///   so that a point directly below the light (`dist3d == height`) receives
///   `intensity` exactly.
class PointLight extends SceneLight {
  const PointLight({
    required this.position,
    required this.height,
    required super.intensity,
    this.falloff = 1.0,
    super.color,
    super.blendMode,
  });

  /// XY position of the light in screen pixels.
  final Offset position;

  /// Height (Z) of the light above the surface in pixels.
  final double height;

  /// Inverse-power falloff exponent (default 1.0).
  final double falloff;

  @override
  Offset directionAt(Offset surfacePoint) {
    final delta = position - surfacePoint;
    final dist = delta.distance;
    if (dist == 0.0) return const Offset(0, -1); // directly below → up
    return delta / dist;
  }

  @override
  double intensityAt(Offset surfacePoint) {
    final xyDist = (position - surfacePoint).distance;
    final dist3d = math.sqrt(xyDist * xyDist + height * height);
    // Normalise so dist3d / height == 1 when directly below.
    final normalised = dist3d / height;
    return (intensity / math.pow(normalised, falloff)).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointLight &&
          position == other.position &&
          height == other.height &&
          intensity == other.intensity &&
          falloff == other.falloff &&
          color == other.color &&
          blendMode == other.blendMode;

  @override
  int get hashCode =>
      Object.hash(PointLight, position, height, intensity, falloff, color, blendMode);

  @override
  String toString() =>
      'PointLight(position: $position, height: $height, '
      'intensity: $intensity, falloff: $falloff, color: $color)';
}

// ── SpotLight ─────────────────────────────────────────────────────────────────

/// Directional cone light that radiates from a point and illuminates only
/// surfaces within its cone.
///
/// [position] is the XY location of the spotlight in screen pixels.
/// [height] is the Z height above the surface.
/// [direction] is the XY direction the spot points (need not be normalized).
/// [coneAngle] is the half-angle of the cone in radians (0 = razor-thin,
///   π/2 = full hemisphere).
/// [softEdge] is the fraction of [coneAngle] used for smooth edge falloff
///   (0 = hard edge, 1 = fully soft).
/// [falloff] controls distance attenuation rate (same as [PointLight]).
class SpotLight extends SceneLight {
  const SpotLight({
    required this.position,
    required this.height,
    required this.direction,
    required this.coneAngle,
    this.softEdge = 0.15,
    this.falloff = 1.0,
    super.blendMode,
    required super.intensity,
    super.color,
  });

  /// XY position of the light in screen pixels.
  final Offset position;

  /// Height (Z) of the light above the surface in pixels.
  final double height;

  /// XY direction the spot points (does not need to be normalised).
  final Offset direction;

  /// Half-angle of the cone in radians.
  final double coneAngle;

  /// Fraction of [coneAngle] to use for smooth edge falloff (0–1).
  final double softEdge;

  /// Inverse-power falloff exponent (default 1.0).
  final double falloff;

  @override
  Offset directionAt(Offset surfacePoint) {
    final delta = position - surfacePoint;
    final dist = delta.distance;
    if (dist == 0.0) return const Offset(0, -1);
    return delta / dist;
  }

  @override
  double intensityAt(Offset surfacePoint) {
    // ── Distance attenuation (same as PointLight) ──
    final xyDist = (position - surfacePoint).distance;
    final dist3d = math.sqrt(xyDist * xyDist + height * height);
    final normalised = dist3d / height;
    final distAttenuation =
        (intensity / math.pow(normalised, falloff)).clamp(0.0, 1.0);

    // ── Cone attenuation ──
    // [direction] is the XY vector indicating where the spot points on the
    // surface plane. We measure the XY angle between the vector from the
    // light position to the surface point and the spot direction.
    final dirLen = direction.distance;
    if (dirLen == 0.0) return 0.0;
    final dirNorm = direction / dirLen;

    final toSurface =
        Offset(surfacePoint.dx - position.dx, surfacePoint.dy - position.dy);
    final toSurfaceLen = toSurface.distance;

    // If the surface is directly below the light (on-axis), angle = 0.
    final double angleFromAxis;
    if (toSurfaceLen == 0.0) {
      angleFromAxis = 0.0;
    } else {
      final toSurfaceNorm = toSurface / toSurfaceLen;
      // Cosine of the 2-D angle between the spot direction and the ray.
      final dotXY =
          toSurfaceNorm.dx * dirNorm.dx + toSurfaceNorm.dy * dirNorm.dy;
      angleFromAxis = math.acos(dotXY.clamp(-1.0, 1.0));
    }

    if (angleFromAxis >= coneAngle) return 0.0;

    // Smooth edge falloff inside the cone.
    double coneAttenuation;
    if (softEdge <= 0.0) {
      coneAttenuation = 1.0;
    } else {
      final innerAngle = coneAngle * (1.0 - softEdge);
      if (angleFromAxis <= innerAngle) {
        coneAttenuation = 1.0;
      } else {
        final t = (angleFromAxis - innerAngle) / (coneAngle - innerAngle);
        coneAttenuation = 1.0 - t;
      }
    }

    return (distAttenuation * coneAttenuation).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotLight &&
          position == other.position &&
          height == other.height &&
          direction == other.direction &&
          coneAngle == other.coneAngle &&
          softEdge == other.softEdge &&
          falloff == other.falloff &&
          intensity == other.intensity &&
          color == other.color &&
          blendMode == other.blendMode;

  @override
  int get hashCode => Object.hash(
      SpotLight, position, height, direction, coneAngle, softEdge, falloff,
      intensity, color, blendMode);

  @override
  String toString() =>
      'SpotLight(position: $position, height: $height, direction: $direction, '
      'coneAngle: $coneAngle, softEdge: $softEdge, falloff: $falloff, '
      'intensity: $intensity, color: $color)';
}

// ── AreaLight ─────────────────────────────────────────────────────────────────

/// Soft rectangular area light.
///
/// Approximated as a single point at the area's center but with an effective
/// normalization distance of `height + halfDiagonal`, making the falloff much
/// softer than a [PointLight] of the same height.
///
/// [position] is the XY center of the light area in screen pixels.
/// [height] is the Z height above the surface.
/// [size] is the width and height of the rectangular light area.
class AreaLight extends SceneLight {
  const AreaLight({
    required this.position,
    required this.height,
    required this.size,
    required super.intensity,
    super.color,
    super.blendMode,
  });

  /// XY center of the light area in screen pixels.
  final Offset position;

  /// Height (Z) of the light above the surface in pixels.
  final double height;

  /// Width and height of the rectangular light area.
  final Size size;

  /// Half the diagonal of the area rectangle — contributes to soft falloff.
  double get _halfDiagonal =>
      math.sqrt(size.width * size.width + size.height * size.height) / 2.0;

  @override
  Offset directionAt(Offset surfacePoint) {
    final delta = position - surfacePoint;
    final dist = delta.distance;
    if (dist == 0.0) return const Offset(0, -1);
    return delta / dist;
  }

  @override
  double intensityAt(Offset surfacePoint) {
    final xyDist = (position - surfacePoint).distance;
    final normDist = height + _halfDiagonal;
    final dist3d = math.sqrt(xyDist * xyDist + normDist * normDist);
    // Normalise so that directly below (xyDist=0) gives dist3d/normDist = 1.
    final normalised = dist3d / normDist;
    return (intensity / normalised).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaLight &&
          position == other.position &&
          height == other.height &&
          size == other.size &&
          intensity == other.intensity &&
          color == other.color &&
          blendMode == other.blendMode;

  @override
  int get hashCode =>
      Object.hash(AreaLight, position, height, size, intensity, color, blendMode);

  @override
  String toString() =>
      'AreaLight(position: $position, height: $height, size: $size, '
      'intensity: $intensity, color: $color)';
}
