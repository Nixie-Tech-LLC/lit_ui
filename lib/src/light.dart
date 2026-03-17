import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A light source that illuminates UI surfaces.
///
/// The [angle] determines the direction light comes FROM, measured in radians
/// clockwise from the top (12 o'clock position):
///   - 0       = light from top
///   - pi/4    = light from top-right
///   - pi/2    = light from right
///   - pi      = light from bottom
///   - 3*pi/2  = light from left
///
/// [intensity] controls how much contrast the light creates (0 = flat, 1 = dramatic).
/// [elevation] controls how high the light is above the surface, affecting shadow spread.
/// [color] tints the highlights.
class Light {
  const Light({
    required this.angle,
    this.intensity = 0.5,
    this.elevation = 0.6,
    this.color = Colors.white,
  });

  /// Direction light comes FROM, in radians clockwise from top.
  final double angle;

  /// Strength of the lighting effect. 0 = no effect, 1 = maximum contrast.
  final double intensity;

  /// Height of the light above the surface. Affects shadow blur and offset.
  /// 0 = grazing (long soft shadows), 1 = directly above (short sharp shadows).
  final double elevation;

  /// Color tint of the light. White = neutral.
  final Color color;

  // ── Convenience constructors ──

  const Light.topLeft({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: 7 * math.pi / 4,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.top({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: 0,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.topRight({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: math.pi / 4,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.left({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: 3 * math.pi / 2,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.right({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: math.pi / 2,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.bottomLeft({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: 5 * math.pi / 4,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.bottom({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: math.pi,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  const Light.bottomRight({
    double intensity = 0.5,
    double elevation = 0.6,
    Color color = Colors.white,
  }) : this(
          angle: 3 * math.pi / 4,
          intensity: intensity,
          elevation: elevation,
          color: color,
        );

  /// Unit vector pointing FROM the light toward the surface.
  /// Used internally for shadow offset computation.
  Offset get directionToSurface => Offset(
        math.sin(angle),
        -math.cos(angle),
      );

  /// Unit vector pointing FROM the surface toward the light.
  Offset get directionToLight => -directionToSurface;

  Light copyWith({
    double? angle,
    double? intensity,
    double? elevation,
    Color? color,
  }) {
    return Light(
      angle: angle ?? this.angle,
      intensity: intensity ?? this.intensity,
      elevation: elevation ?? this.elevation,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Light &&
          angle == other.angle &&
          intensity == other.intensity &&
          elevation == other.elevation &&
          color == other.color;

  @override
  int get hashCode => Object.hash(angle, intensity, elevation, color);
}
