import 'package:flutter/material.dart';

import 'light_types.dart';

/// A container that holds an ordered list of [SceneLight] sources that
/// together illuminate a surface.
///
/// Use [LightScene.directional] for the common case of a single
/// [DirectionalLight] (backward-compatible convenience factory).
class LightScene {
  const LightScene({
    required this.lights,
    this.ambientSky = const Color(0xFFFFFFFF),
    this.ambientGround = const Color(0xFFFFFFFF),
  });

  /// The lights in this scene. May be empty (no illumination).
  final List<SceneLight> lights;

  /// Sky-hemisphere ambient tint. Applied to surfaces whose normals
  /// point upward (toward the top of the screen).
  final Color ambientSky;

  /// Ground-hemisphere ambient tint. Applied to surfaces whose normals
  /// point downward (toward the bottom of the screen).
  final Color ambientGround;

  /// Convenience factory: wraps a single [DirectionalLight].
  factory LightScene.directional({
    required double angle,
    double intensity = 0.5,
    Color color = const Color(0xFFFFFFFF),
    Color ambientSky = const Color(0xFFFFFFFF),
    Color ambientGround = const Color(0xFFFFFFFF),
  }) =>
      LightScene(
        lights: [
          DirectionalLight(angle: angle, intensity: intensity, color: color),
        ],
        ambientSky: ambientSky,
        ambientGround: ambientGround,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LightScene) return false;
    if (lights.length != other.lights.length) return false;
    if (ambientSky != other.ambientSky) return false;
    if (ambientGround != other.ambientGround) return false;
    for (var i = 0; i < lights.length; i++) {
      if (lights[i] != other.lights[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(lights), ambientSky, ambientGround);

  @override
  String toString() => 'LightScene(lights: $lights, ambientSky: $ambientSky, ambientGround: $ambientGround)';
}
