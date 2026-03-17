import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'border_theme.dart';
import 'debug/widget_inspector.dart';
import 'light_scene.dart';
import 'light_theme.dart';
import 'lit_shader.dart';
import 'material_theme.dart';
import 'surface_material.dart';
import 'surface_profile.dart';

/// A concave (inset) border for input fields, lit by the nearest [LightTheme].
///
/// The lip (border) catches light on its outer face. The recessed floor stays
/// flat. Each light in the scene contributes independently to per-edge
/// brightness and casts its own thin inset shadow.
class LitInputBorder extends StatelessWidget {
  const LitInputBorder({
    super.key,
    required this.child,
    this.baseColor,
    this.fillColor,
    this.borderWidth = 1,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.borderContrast = 1.0,
    this.scene,
    this.material,
    this.outerShadowIntensity = 0.33,
    this.outerShadowWidth = 0.96,
    this.innerShadowIntensity = 0.54,
    this.innerShadowWidth = 0.0,
  });

  final Widget child;
  final Color? baseColor;
  final Color? fillColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final double borderContrast;
  final LightScene? scene;
  final SurfaceMaterial? material;
  final double outerShadowIntensity;
  final double outerShadowWidth;
  final double innerShadowIntensity;
  final double innerShadowWidth;

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
    final effectiveBaseColor = baseColor ?? Colors.grey.shade300;
    final effectiveFillColor = fillColor ?? Colors.white;
    final screenCenter = _getScreenCenter(context);

    // Resolve shadow band values: theme overrides > widget params
    final borderTheme = LitBorderTheme.of(context);
    final effectiveOuterShadowIntensity =
        borderTheme?.outerShadowIntensity ?? outerShadowIntensity;
    final effectiveOuterShadowWidth =
        borderTheme?.outerShadowWidth ?? outerShadowWidth;
    final effectiveInnerShadowIntensity =
        borderTheme?.innerShadowIntensity ?? innerShadowIntensity;
    final effectiveInnerShadowWidth =
        borderTheme?.innerShadowWidth ?? innerShadowWidth;

    final box = context.findRenderObject() as RenderBox?;
    LitWidgetInspector.register(
      widgetHashCode: hashCode,
      widgetType: 'LitInputBorder',
      material: material,
      bounds: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );

    return CustomPaint(
      painter: _LitInputBorderPainter(
        scene: effectiveScene,
        screenCenter: screenCenter,
        baseColor: effectiveBaseColor,
        fillColor: effectiveFillColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        borderContrast: borderContrast,
        material: effectiveMaterial,
        outerShadowIntensity: effectiveOuterShadowIntensity,
        outerShadowWidth: effectiveOuterShadowWidth,
        innerShadowIntensity: effectiveInnerShadowIntensity,
        innerShadowWidth: effectiveInnerShadowWidth,
      ),
      child: child,
    );
  }
}

class _LitInputBorderPainter extends CustomPainter {
  _LitInputBorderPainter({
    required this.scene,
    required this.screenCenter,
    required this.baseColor,
    required this.fillColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderContrast,
    this.material,
    required this.outerShadowIntensity,
    required this.outerShadowWidth,
    required this.innerShadowIntensity,
    required this.innerShadowWidth,
  });

  final LightScene scene;
  final Offset screenCenter;
  final Color baseColor;
  final Color fillColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final double borderContrast;
  final SurfaceMaterial? material;
  final double outerShadowIntensity;
  final double outerShadowWidth;
  final double innerShadowIntensity;
  final double innerShadowWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect = borderRadius.toRRect(rect);
    final innerRRect = outerRRect.deflate(borderWidth);
    final hsl = HSLColor.fromColor(baseColor);

    // ── Border lip: sum per-edge brightness from all lights ──
    // 4 edge normals: top (0,-1), right (1,0), bottom (0,1), left (-1,0)
    double topB = 0, rightB = 0, bottomB = 0, leftB = 0;

    for (final light in scene.lights) {
      final intensity = light.intensityAt(screenCenter);
      if (intensity < 0.001) continue;
      final dir = light.directionAt(screenCenter);

      topB += (dir.dy * -1) * intensity;
      rightB += (dir.dx * 1) * intensity;
      bottomB += (dir.dy * 1) * intensity;
      leftB += (dir.dx * -1) * intensity;
    }

    // Concave lip model: the outer face of each edge is a small convex ridge.
    // Light-facing edges catch light (brighten). Shadow-facing edges fall into
    // the recess and should darken toward the fill color to nearly vanish.
    final effectiveMaterial = material;
    final maxLighten = effectiveMaterial != null
        ? effectiveMaterial.maxBorderLighten * borderContrast
        : 0.5 * borderContrast;
    final maxDarken = effectiveMaterial != null
        ? -effectiveMaterial.maxBorderDarken * borderContrast
        : -0.35 * borderContrast;
    final fillHsl = HSLColor.fromColor(fillColor);

    Color edgeColor(double b) {
      if (b > 0) {
        // Lit face — brighten
        final offset = b * maxLighten;
        return hsl
            .withLightness((hsl.lightness + offset).clamp(0.0, 1.0))
            .toColor();
      } else {
        // Shadow face — darken toward fill color so it disappears into recess
        final t = (b.abs() * -maxDarken).clamp(0.0, 1.0);
        final targetL = fillHsl.lightness - 0.02; // slightly darker than fill
        final newL = hsl.lightness + (targetL - hsl.lightness) * t;
        return hsl.withLightness(newL.clamp(0.0, 1.0)).toColor();
      }
    }

    final topColor = edgeColor(topB);
    final rightColor = edgeColor(rightB);
    final bottomColor = edgeColor(bottomB);
    final leftColor = edgeColor(leftB);

    final borderGradient = SweepGradient(
      center: Alignment.center,
      colors: [
        rightColor,
        _lerpColor(rightColor, bottomColor, 0.5),
        bottomColor,
        _lerpColor(bottomColor, leftColor, 0.5),
        leftColor,
        _lerpColor(leftColor, topColor, 0.5),
        topColor,
        _lerpColor(topColor, rightColor, 0.5),
        rightColor,
      ],
      stops: const [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0],
    );

    // ── 1. Floor first: solid flat color ──
    final fillPaint = Paint()..color = fillColor;
    canvas.drawRRect(innerRRect, fillPaint);

    // ── 2. Inset shadows: per-edge rects with MaskFilter.blur ──
    // For each lit edge, draw a thin rect just outside the clip boundary.
    // BlurStyle.normal bleeds the rect's fill inward past the clip, creating
    // a crisp inset shadow along that edge.
    canvas.save();
    canvas.clipRRect(innerRRect);

    final blurSigma = effectiveMaterial?.shadowBlurSigma ?? 1.5;
    const stripThickness = 10.0; // rect thickness outside the clip
    final innerRect = innerRRect.outerRect;

    for (final light in scene.lights) {
      final intensity = light.intensityAt(screenCenter);
      if (intensity < 0.001) continue;
      final dir = light.directionAt(screenCenter);

      final len = math.sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
      if (len < 0.001) continue;
      final nx = dir.dx / len;
      final ny = dir.dy / len;

      // Dot product with each edge's outward normal:
      // top (0,-1), right (1,0), bottom (0,1), left (-1,0)
      final edgeDots = [-ny, nx, ny, -nx];

      for (int i = 0; i < 4; i++) {
        final dot = edgeDots[i];
        if (dot <= 0) continue;

        // dot² so the most light-facing edge dominates
        final shadowOpacity = effectiveMaterial != null
            ? (effectiveMaterial.insetShadowIntensity * dot * dot * intensity * borderContrast).clamp(0.0, 0.25)
            : (0.25 * dot * dot * intensity * borderContrast).clamp(0.0, 0.25);

        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: shadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

        // Thin rect sitting just outside the clip edge.
        late Rect stripRect;
        switch (i) {
          case 0: // top
            stripRect = Rect.fromLTRB(
              innerRect.left,
              innerRect.top - stripThickness,
              innerRect.right,
              innerRect.top,
            );
            break;
          case 1: // right
            stripRect = Rect.fromLTRB(
              innerRect.right,
              innerRect.top,
              innerRect.right + stripThickness,
              innerRect.bottom,
            );
            break;
          case 2: // bottom
            stripRect = Rect.fromLTRB(
              innerRect.left,
              innerRect.bottom,
              innerRect.right,
              innerRect.bottom + stripThickness,
            );
            break;
          case 3: // left
            stripRect = Rect.fromLTRB(
              innerRect.left - stripThickness,
              innerRect.top,
              innerRect.left,
              innerRect.bottom,
            );
            break;
        }

        canvas.drawRect(stripRect, shadowPaint);
      }
    }

    canvas.restore();

    // ── 3. Shader lip: border with shadow bands ──
    final useShader = LitShader.isLoaded && material != null;
    if (useShader) {
      final shader = LitShader.createShader(
        size: size,
        baseColor: baseColor,
        material: material!,
        profile: SurfaceProfile.flat,
        scene: scene,
        screenCenter: screenCenter,
        curvature: 0.0,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        outerShadowIntensity: outerShadowIntensity,
        outerShadowWidth: outerShadowWidth,
        innerShadowIntensity: innerShadowIntensity,
        innerShadowWidth: innerShadowWidth,
      );
      if (shader != null) {
        final shaderPaint = Paint()..shader = shader;
        canvas.drawRect(rect, shaderPaint);
        return;
      }
    }

    // ── 4. Canvas fallback border: sweep gradient on outer RRect ──
    final borderPaint = Paint()..shader = borderGradient.createShader(rect);
    canvas.drawRRect(outerRRect, borderPaint);
  }

  static Color _lerpColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  @override
  bool shouldRepaint(_LitInputBorderPainter oldDelegate) =>
      scene != oldDelegate.scene ||
      screenCenter != oldDelegate.screenCenter ||
      baseColor != oldDelegate.baseColor ||
      fillColor != oldDelegate.fillColor ||
      borderWidth != oldDelegate.borderWidth ||
      borderRadius != oldDelegate.borderRadius ||
      borderContrast != oldDelegate.borderContrast ||
      material != oldDelegate.material ||
      outerShadowIntensity != oldDelegate.outerShadowIntensity ||
      outerShadowWidth != oldDelegate.outerShadowWidth ||
      innerShadowIntensity != oldDelegate.innerShadowIntensity ||
      innerShadowWidth != oldDelegate.innerShadowWidth;
}
