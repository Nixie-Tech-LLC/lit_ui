import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'light.dart';
import 'light_resolver.dart';

/// Computed lighting values for a surface, derived from a [Light] and a base color.
class SurfaceLighting {
  const SurfaceLighting({
    required this.lightFaceColor,
    required this.darkFaceColor,
    required this.lightEdgeColor,
    required this.darkEdgeColor,
    required this.gradientBegin,
    required this.gradientEnd,
    required this.borderSweepColors,
    required this.borderSweepStops,
    required this.shadowOffset,
    required this.shadowBlurRadius,
    required this.shadowColor,
  });

  /// Surface color on the side facing the light.
  final Color lightFaceColor;

  /// Surface color on the side facing away from the light.
  final Color darkFaceColor;

  /// Border color on edges facing the light.
  final Color lightEdgeColor;

  /// Border color on edges facing away from the light.
  final Color darkEdgeColor;

  /// Alignment where the fill gradient starts (light side).
  final Alignment gradientBegin;

  /// Alignment where the fill gradient ends (dark side).
  final Alignment gradientEnd;

  /// Colors for the border's SweepGradient.
  final List<Color> borderSweepColors;

  /// Stops for the border's SweepGradient.
  final List<double> borderSweepStops;

  /// Shadow offset, pointing away from the light.
  final Offset shadowOffset;

  /// Shadow blur radius.
  final double shadowBlurRadius;

  /// Shadow color.
  final Color shadowColor;

  /// Builds a [LinearGradient] for the surface fill.
  LinearGradient get fillGradient => LinearGradient(
        begin: gradientBegin,
        end: gradientEnd,
        colors: [lightFaceColor, darkFaceColor],
      );

  /// Builds a [SweepGradient] for the border.
  SweepGradient get borderGradient => SweepGradient(
        center: Alignment.center,
        colors: borderSweepColors,
        stops: borderSweepStops,
      );

  /// Builds a [BoxShadow] from the computed values.
  BoxShadow get boxShadow => BoxShadow(
        offset: shadowOffset,
        blurRadius: shadowBlurRadius,
        color: shadowColor,
      );
}

/// Computes [SurfaceLighting] from a [Light], a base color, and surface properties.
class LightingEngine {
  const LightingEngine._();

  /// Compute all lighting values for a surface using a [ResolvedLight].
  ///
  /// This is the preferred method when using the new scene-based lighting
  /// system. It accepts a [ResolvedLight] produced by [LightResolver.resolve].
  ///
  /// [light] — the resolved light source.
  /// [baseColor] — the surface's base color.
  /// [surfaceElevation] — how raised the surface is (affects shadow distance).
  ///   Typical range: 0 (flat) to 24 (very elevated).
  /// [curvature] — how convex the surface is. 0 = perfectly flat (uniform color),
  ///   1 = very convex (strong gradient). Buttons typically use 0.5–1.0,
  ///   flat panels and page shells use 0.
  /// [fillContrast] — multiplier for the fill gradient contrast. Default 1.0.
  /// [borderContrast] — multiplier for the border gradient contrast. Default 1.0.
  static SurfaceLighting computeResolved({
    required ResolvedLight light,
    required Color baseColor,
    double surfaceElevation = 4,
    double curvature = 0.5,
    double fillContrast = 1.0,
    double borderContrast = 1.0,
  }) {
    final hsl = HSLColor.fromColor(baseColor);
    final intensity = light.intensity;

    // ── Fill gradient ──
    final fillLighten = 0.06 * intensity * fillContrast * curvature;
    final fillDarken = -0.08 * intensity * fillContrast * curvature;

    final lightFaceColor = _adjustLightness(hsl, fillLighten);
    final darkFaceColor = _adjustLightness(hsl, fillDarken);

    // Gradient direction: begins where the light points toward the surface
    // (the lit face) and ends on the opposite (shadow) face.
    final gradientBegin = Alignment(
      light.direction.dx.clamp(-1.0, 1.0),
      light.direction.dy.clamp(-1.0, 1.0),
    );
    final gradientEnd = Alignment(
      (-light.direction.dx).clamp(-1.0, 1.0),
      (-light.direction.dy).clamp(-1.0, 1.0),
    );

    // ── Border gradient ──
    final borderLighten = 0.4 * intensity * borderContrast;
    final borderDarken = -0.06 * intensity * borderContrast;

    final lightEdgeColor = _adjustLightness(hsl, borderLighten);
    final darkEdgeColor = _adjustLightness(hsl, borderDarken);

    final sweepResult = _computeBorderSweepFromDirection(
      direction: light.direction,
      lightEdgeColor: lightEdgeColor,
      darkEdgeColor: darkEdgeColor,
    );

    // ── Shadow ──
    // Shadow is cast opposite to the light direction.
    // light.direction points FROM the surface TOWARD the light, so we negate
    // it to get the direction the shadow falls.
    final shadowDistance = surfaceElevation * (1.0 - light.elevation * 0.8);
    final shadowBlur = surfaceElevation * (1.5 - light.elevation);
    final shadowOffset = -light.direction * shadowDistance;
    final shadowOpacity = (0.15 * intensity).clamp(0.0, 1.0);

    return SurfaceLighting(
      lightFaceColor: lightFaceColor,
      darkFaceColor: darkFaceColor,
      lightEdgeColor: lightEdgeColor,
      darkEdgeColor: darkEdgeColor,
      gradientBegin: gradientBegin,
      gradientEnd: gradientEnd,
      borderSweepColors: sweepResult.colors,
      borderSweepStops: sweepResult.stops,
      shadowOffset: shadowOffset,
      shadowBlurRadius: shadowBlur.clamp(0.0, 100.0),
      shadowColor: Colors.black.withValues(alpha: shadowOpacity),
    );
  }

  /// Compute all lighting values for a surface.
  ///
  /// [light] — the light source (directional, like sunlight).
  /// [baseColor] — the surface's base color.
  /// [surfaceElevation] — how raised the surface is (affects shadow distance).
  ///   Typical range: 0 (flat) to 24 (very elevated).
  /// [curvature] — how convex the surface is. 0 = perfectly flat (uniform color),
  ///   1 = very convex (strong gradient). Buttons typically use 0.5–1.0,
  ///   flat panels and page shells use 0.
  /// [fillContrast] — multiplier for the fill gradient contrast. Default 1.0.
  /// [borderContrast] — multiplier for the border gradient contrast. Default 1.0.
  @Deprecated('Use computeResolved() instead')
  static SurfaceLighting compute({
    required Light light,
    required Color baseColor,
    double surfaceElevation = 4,
    double curvature = 0.5,
    double fillContrast = 1.0,
    double borderContrast = 1.0,
  }) {
    final hsl = HSLColor.fromColor(baseColor);
    final intensity = light.intensity;

    // ── Fill gradient ──
    // With directional light (parallel rays), a perfectly flat surface
    // receives uniform illumination — no gradient. Curvature simulates
    // a convex surface whose normal varies across the face, creating
    // a gradient from the light-facing side to the shadow-facing side.
    final fillLighten = 0.06 * intensity * fillContrast * curvature;
    final fillDarken = -0.08 * intensity * fillContrast * curvature;

    final lightFaceColor = _adjustLightness(hsl, fillLighten);
    final darkFaceColor = _adjustLightness(hsl, fillDarken);

    // Gradient direction: from light toward shadow.
    final gradientBegin = _angleToAlignment(light.angle);
    final gradientEnd = _angleToAlignment(light.angle + math.pi);

    // ── Border gradient ──
    // Stronger contrast on borders than fill — this is what makes them "pop".
    final borderLighten = 0.4 * intensity * borderContrast;
    final borderDarken = -0.06 * intensity * borderContrast;

    final lightEdgeColor = _adjustLightness(hsl, borderLighten);
    final darkEdgeColor = _adjustLightness(hsl, borderDarken);

    final sweepResult = _computeBorderSweep(
      light: light,
      lightEdgeColor: lightEdgeColor,
      darkEdgeColor: darkEdgeColor,
    );

    // ── Shadow ──
    // Shadow is cast opposite the light direction.
    // Note: directionToSurface is the light position vector (toward the light),
    // so we negate it to get the shadow direction (away from the light).
    final shadowDistance = surfaceElevation * (1.0 - light.elevation * 0.8);
    final shadowBlur = surfaceElevation * (1.5 - light.elevation);
    final shadowOffset = -light.directionToSurface * shadowDistance;
    final shadowOpacity = (0.15 * intensity).clamp(0.0, 1.0);

    return SurfaceLighting(
      lightFaceColor: lightFaceColor,
      darkFaceColor: darkFaceColor,
      lightEdgeColor: lightEdgeColor,
      darkEdgeColor: darkEdgeColor,
      gradientBegin: gradientBegin,
      gradientEnd: gradientEnd,
      borderSweepColors: sweepResult.colors,
      borderSweepStops: sweepResult.stops,
      shadowOffset: shadowOffset,
      shadowBlurRadius: shadowBlur.clamp(0.0, 100.0),
      shadowColor: Colors.black.withValues(alpha: shadowOpacity),
    );
  }

  /// Apply a hover lighten effect to existing lighting.
  static SurfaceLighting applyHover(
    SurfaceLighting base, {
    double amount = 0.02,
  }) {
    return SurfaceLighting(
      lightFaceColor: _lighten(base.lightFaceColor, amount),
      darkFaceColor: _lighten(base.darkFaceColor, amount),
      lightEdgeColor: base.lightEdgeColor,
      darkEdgeColor: base.darkEdgeColor,
      gradientBegin: base.gradientBegin,
      gradientEnd: base.gradientEnd,
      borderSweepColors: base.borderSweepColors,
      borderSweepStops: base.borderSweepStops,
      shadowOffset: base.shadowOffset,
      shadowBlurRadius: base.shadowBlurRadius,
      shadowColor: base.shadowColor,
    );
  }

  // ── Private helpers ──

  static Color _adjustLightness(HSLColor hsl, double amount) {
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Convert a light angle (radians clockwise from top) to an [Alignment].
  static Alignment _angleToAlignment(double angle) {
    final x = math.sin(angle);
    final y = -math.cos(angle);
    return Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
  }

  /// Builds a SweepGradient color/stop list so the bright edge faces the light
  /// and transitions smoothly to the dark edge on the opposite side.
  ///
  /// The SweepGradient starts at 3 o'clock and sweeps clockwise.
  /// We map the light angle into this space and place the bright zone
  /// centered on the lit edge, with smooth transitions to dark.
  static ({List<Color> colors, List<double> stops}) _computeBorderSweep({
    required Light light,
    required Color lightEdgeColor,
    required Color darkEdgeColor,
  }) {
    // SweepGradient 0.0 = 3 o'clock, 0.25 = 6, 0.5 = 9, 0.75 = 12.
    // Our light angle: 0 = 12 o'clock, pi/2 = 3 o'clock, pi = 6, 3pi/2 = 9.
    // The bright edge faces TOWARD the light, so we add pi to flip direction.
    // Convert: sweepFraction = (angle + 3*pi/2) / (2*pi) mod 1.0
    final sweepCenter =
        ((light.angle + 3 * math.pi / 2) / (2 * math.pi)) % 1.0;

    // The bright zone spans ~0.3 of the sweep centered on sweepCenter.
    // The dark zone is the rest.
    const brightSpan = 0.3;
    const transitionSpan = 0.1;

    // Build stops wrapping around the [0, 1] range.
    final brightStart = (sweepCenter - brightSpan / 2) % 1.0;
    final brightEnd = (sweepCenter + brightSpan / 2) % 1.0;

    // If the bright zone wraps around 1.0→0.0, handle it simply:
    // we always produce 7 stops to match the original button pattern.
    if (brightStart < brightEnd) {
      // Normal case: bright zone doesn't wrap.
      final darkZoneEnd = (brightStart - transitionSpan).clamp(0.0, 1.0);
      final darkZoneStart = (brightEnd + transitionSpan).clamp(0.0, 1.0);

      return (
        colors: [
          darkEdgeColor,  // 0.0
          darkEdgeColor,  // before transition
          lightEdgeColor, // bright start
          lightEdgeColor, // bright end
          darkEdgeColor,  // after transition
          darkEdgeColor,  // rest
          darkEdgeColor,  // 1.0
        ],
        stops: [
          0.0,
          darkZoneEnd.clamp(0.0, brightStart),
          brightStart,
          brightEnd,
          darkZoneStart.clamp(brightEnd, 1.0),
          (darkZoneStart + 0.01).clamp(brightEnd, 1.0),
          1.0,
        ],
      );
    } else {
      // Wrapped case: bright zone crosses the 0/1 boundary.
      return (
        colors: [
          lightEdgeColor, // 0.0 (in bright zone)
          lightEdgeColor, // bright end
          darkEdgeColor,  // transition out
          darkEdgeColor,  // dark zone
          darkEdgeColor,  // transition in
          lightEdgeColor, // bright start
          lightEdgeColor, // 1.0 (in bright zone)
        ],
        stops: [
          0.0,
          brightEnd,
          (brightEnd + transitionSpan).clamp(0.0, 1.0),
          0.5,
          (brightStart - transitionSpan).clamp(0.0, 1.0),
          brightStart,
          1.0,
        ],
      );
    }
  }

  /// Variant of [_computeBorderSweep] that takes a direction [Offset] instead
  /// of a [Light] object. Used by [computeResolved].
  ///
  /// [direction] is the unit vector pointing FROM the surface TOWARD the light.
  ///
  /// SweepGradient coordinate system: 0.0 = 3 o'clock (positive x), sweeps
  /// clockwise. Flutter's y-axis points downward.
  ///
  /// Conversion: we want the bright edge to face the light. The angle of the
  /// light direction in standard math coords (counter-clockwise from +x) is
  /// `atan2(-direction.dy, direction.dx)`. To convert to SweepGradient's
  /// clockwise-from-3-o'clock fraction:
  ///   sweepCenter = ((-atan2(-direction.dy, direction.dx)) / (2*pi) + 1.0) % 1.0
  /// Simplified: sweepCenter = (atan2(direction.dy, direction.dx) / (2*pi) + 1.0) % 1.0
  static ({List<Color> colors, List<double> stops}) _computeBorderSweepFromDirection({
    required Offset direction,
    required Color lightEdgeColor,
    required Color darkEdgeColor,
  }) {
    // Convert direction to SweepGradient fraction.
    // atan2(dy, dx) gives the angle in [-pi, pi] clockwise from +x (in Flutter
    // coords where y is down, atan2 is already clockwise).
    // Divide by 2*pi and normalise to [0, 1].
    final sweepCenter =
        (math.atan2(direction.dy, direction.dx) / (2 * math.pi) + 1.0) % 1.0;

    const brightSpan = 0.3;
    const transitionSpan = 0.1;

    final brightStart = (sweepCenter - brightSpan / 2) % 1.0;
    final brightEnd = (sweepCenter + brightSpan / 2) % 1.0;

    if (brightStart < brightEnd) {
      final darkZoneEnd = (brightStart - transitionSpan).clamp(0.0, 1.0);
      final darkZoneStart = (brightEnd + transitionSpan).clamp(0.0, 1.0);

      return (
        colors: [
          darkEdgeColor,
          darkEdgeColor,
          lightEdgeColor,
          lightEdgeColor,
          darkEdgeColor,
          darkEdgeColor,
          darkEdgeColor,
        ],
        stops: [
          0.0,
          darkZoneEnd.clamp(0.0, brightStart),
          brightStart,
          brightEnd,
          darkZoneStart.clamp(brightEnd, 1.0),
          (darkZoneStart + 0.01).clamp(brightEnd, 1.0),
          1.0,
        ],
      );
    } else {
      return (
        colors: [
          lightEdgeColor,
          lightEdgeColor,
          darkEdgeColor,
          darkEdgeColor,
          darkEdgeColor,
          lightEdgeColor,
          lightEdgeColor,
        ],
        stops: [
          0.0,
          brightEnd,
          (brightEnd + transitionSpan).clamp(0.0, 1.0),
          0.5,
          (brightStart - transitionSpan).clamp(0.0, 1.0),
          brightStart,
          1.0,
        ],
      );
    }
  }
}
