import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'debug/widget_inspector.dart';
import 'light_scene.dart';
import 'light_theme.dart';
import 'material_theme.dart';
import 'surface_material.dart';

/// Paints a top and left border with a sweep gradient derived from the
/// nearest [LightTheme], with a rounded top-left corner.
///
/// Per-edge brightness is summed from all lights in the scene.
class LitEdgeBorder extends StatelessWidget {
  const LitEdgeBorder({
    super.key,
    required this.child,
    this.baseColor,
    this.borderWidth = 1,
    this.topLeftRadius = 0,
    this.borderContrast = 1.0,
    this.scene,
    this.material,
  });

  final Widget child;
  final Color? baseColor;
  final double borderWidth;
  final double topLeftRadius;
  final double borderContrast;
  final LightScene? scene;
  final SurfaceMaterial? material;

  Offset _getScreenCenter(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveScene = scene ?? LightTheme.of(context);
    final effectiveMaterial = LitMaterialTheme.resolveOf(context, material);
    final effectiveColor = baseColor ?? Colors.grey.shade300;
    final screenCenter = _getScreenCenter(context);

    final box = context.findRenderObject() as RenderBox?;
    LitWidgetInspector.register(
      widgetHashCode: hashCode,
      widgetType: 'LitEdgeBorder',
      material: material,
      bounds: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );

    return CustomPaint(
      painter: _LitEdgeBorderPainter(
        scene: effectiveScene,
        screenCenter: screenCenter,
        baseColor: effectiveColor,
        borderWidth: borderWidth,
        topLeftRadius: topLeftRadius,
        borderContrast: borderContrast,
        material: effectiveMaterial,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeftRadius),
        ),
        child: child,
      ),
    );
  }
}

class _LitEdgeBorderPainter extends CustomPainter {
  _LitEdgeBorderPainter({
    required this.scene,
    required this.screenCenter,
    required this.baseColor,
    required this.borderWidth,
    required this.topLeftRadius,
    required this.borderContrast,
    this.material,
  });

  final LightScene scene;
  final Offset screenCenter;
  final Color baseColor;
  final double borderWidth;
  final double topLeftRadius;
  final double borderContrast;
  final SurfaceMaterial? material;

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(baseColor);

    // Sum per-edge brightness from all lights.
    // Top edge normal: (0, -1), Left edge normal: (-1, 0)
    double topBrightness = 0;
    double leftBrightness = 0;

    for (final light in scene.lights) {
      final intensity = light.intensityAt(screenCenter);
      if (intensity < 0.001) continue;
      final dir = light.directionAt(screenCenter);

      // dot(direction, edgeNormal) * intensity
      topBrightness += (dir.dy * -1) * intensity;
      leftBrightness += (dir.dx * -1) * intensity;
    }

    final maxLighten = material != null
        ? material!.maxBorderLighten * borderContrast
        : 0.4 * borderContrast;
    final maxDarken = material != null
        ? -material!.maxBorderDarken * borderContrast
        : -0.08 * borderContrast;

    double brightnessToOffset(double b) {
      return b > 0 ? b * maxLighten : b.abs() * maxDarken;
    }

    final topColor = hsl
        .withLightness((hsl.lightness + brightnessToOffset(topBrightness)).clamp(0.0, 1.0))
        .toColor();
    final leftColor = hsl
        .withLightness((hsl.lightness + brightnessToOffset(leftBrightness)).clamp(0.0, 1.0))
        .toColor();

    final gradient = SweepGradient(
      center: Alignment.topLeft,
      startAngle: 0,
      endAngle: math.pi / 2,
      colors: [topColor, leftColor],
    );

    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final hw = borderWidth / 2;
    final r = topLeftRadius + hw;
    final path = Path()
      ..moveTo(-hw, size.height)
      ..lineTo(-hw, r)
      ..arcToPoint(
        Offset(r, -hw),
        radius: Radius.circular(r),
      )
      ..lineTo(size.width, -hw);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LitEdgeBorderPainter oldDelegate) =>
      scene != oldDelegate.scene ||
      screenCenter != oldDelegate.screenCenter ||
      baseColor != oldDelegate.baseColor ||
      borderWidth != oldDelegate.borderWidth ||
      topLeftRadius != oldDelegate.topLeftRadius ||
      borderContrast != oldDelegate.borderContrast ||
      material != oldDelegate.material;
}
