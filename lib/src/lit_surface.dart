import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'debug/widget_inspector.dart';
import 'light_scene.dart';
import 'light_theme.dart';
import 'light_types.dart';
import 'lit_shader.dart';
import 'material_theme.dart';
import 'surface_material.dart';
import 'surface_profile.dart';

/// A widget that renders its child on a lit surface.
///
/// Each light in the scene contributes independently:
/// - **Fill**: layered gradient overlays (curvature-dependent)
/// - **Border**: single sweep gradient with per-edge brightness summed from all lights
///
/// When [overlay] is `true`, the fill gradient renders **on top** of the child
/// using [BlendMode.overlay], so lighting composites onto images or other
/// opaque content. The border still renders behind the child.
class LitSurface extends StatelessWidget {
  const LitSurface({
    super.key,
    required this.baseColor,
    required this.child,
    this.elevation = 4,
    this.curvature = 0.0,
    this.borderWidth = 1,
    this.borderRadius,
    this.fillContrast = 1.0,
    this.borderContrast = 1.0,
    this.scene,
    this.padding,
    this.material,
    this.profile,
    this.normalMap,
    this.overlay = true,
  });

  final Color baseColor;
  final Widget child;
  final double elevation;
  final double curvature;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final double fillContrast;
  final double borderContrast;
  final EdgeInsets? padding;
  final LightScene? scene;
  final SurfaceMaterial? material;
  final SurfaceProfile? profile;
  final ui.Image? normalMap;

  /// When `true`, the lighting fill renders as a foreground overlay on top of
  /// the child (e.g. an image) instead of behind it. The border still renders
  /// behind.
  final bool overlay;

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
    final effectiveProfile = profile ?? LitMaterialTheme.profileOf(context);
    final radius = borderRadius ?? BorderRadius.circular(10);
    final screenCenter = _getScreenCenter(context);

    final box = context.findRenderObject() as RenderBox?;
    LitWidgetInspector.register(
      widgetHashCode: hashCode,
      widgetType: 'LitSurface',
      material: material,
      bounds: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );

    Widget result;
    if (overlay) {
      result = CustomPaint(
        painter: _LitSurfacePainter(
          scene: effectiveScene,
          screenCenter: screenCenter,
          baseColor: baseColor,
          borderWidth: borderWidth,
          borderRadius: radius,
          curvature: curvature,
          fillContrast: fillContrast,
          borderContrast: borderContrast,
          material: effectiveMaterial,
          profile: effectiveProfile,
          normalMap: normalMap,
          borderOnly: true,
        ),
        foregroundPainter: _LitSurfacePainter(
          scene: effectiveScene,
          screenCenter: screenCenter,
          baseColor: baseColor,
          borderWidth: borderWidth,
          borderRadius: radius,
          curvature: curvature,
          fillContrast: fillContrast,
          borderContrast: borderContrast,
          material: effectiveMaterial,
          profile: effectiveProfile,
          normalMap: normalMap,
          overlayFill: true,
        ),
        child: Padding(
          padding: (padding ?? EdgeInsets.zero) + EdgeInsets.all(borderWidth),
          child: child,
        ),
      );
    } else {
      result = CustomPaint(
        painter: _LitSurfacePainter(
          scene: effectiveScene,
          screenCenter: screenCenter,
          baseColor: baseColor,
          borderWidth: borderWidth,
          borderRadius: radius,
          curvature: curvature,
          fillContrast: fillContrast,
          borderContrast: borderContrast,
          material: effectiveMaterial,
          profile: effectiveProfile,
          normalMap: normalMap,
        ),
        child: Padding(
          padding: (padding ?? EdgeInsets.zero) + EdgeInsets.all(borderWidth),
          child: child,
        ),
      );
    }

    // Wrap in backdrop blur for translucent surfaces
    final translucency = effectiveMaterial?.translucency ?? 0.0;
    if (translucency > 0) {
      final sigma = 8.0 * translucency * (effectiveMaterial?.roughness ?? 0.0);
      result = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: result,
        ),
      );
    }

    return result;
  }
}

class _LitSurfacePainter extends CustomPainter {
  _LitSurfacePainter({
    required this.scene,
    required this.screenCenter,
    required this.baseColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.curvature,
    required this.fillContrast,
    required this.borderContrast,
    this.material,
    this.profile,
    this.normalMap,
    this.borderOnly = false,
    this.overlayFill = false,
  });

  final LightScene scene;
  final Offset screenCenter;
  final Color baseColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final double curvature;
  final double fillContrast;
  final double borderContrast;
  final SurfaceMaterial? material;
  final SurfaceProfile? profile;
  final ui.Image? normalMap;

  /// When `true`, only the border sweep gradient is painted (no fill).
  final bool borderOnly;

  /// When `true`, only the fill gradient is painted as a foreground overlay
  /// using [BlendMode.overlay] — no solid base, no border.
  final bool overlayFill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect = borderRadius.toRRect(rect);
    final innerRRect = outerRRect.deflate(borderWidth);
    final hsl = HSLColor.fromColor(baseColor);

    // ── Shader path ──
    final useShader = LitShader.isLoaded &&
        (material != null ||
            (profile != null && profile!.pattern != SurfacePattern.flat));
    if (useShader && !borderOnly) {
      if (overlayFill) {
        // Overlay: shader outputs lighting-only for overlay compositing.
        // Border zone is transparent in the shader; background painter
        // handles the border separately.
        final shader = LitShader.createShader(
          size: size,
          baseColor: baseColor,
          material: material ?? SurfaceMaterial.matte,
          profile: profile ?? SurfaceProfile.flat,
          scene: scene,
          screenCenter: screenCenter,
          curvature: curvature,
          borderWidth: borderWidth,
          borderRadius: borderRadius,
          normalMap: normalMap,
          overlay: true,
        );
        if (shader != null) {
          final shaderPaint = Paint()
            ..shader = shader
            ..blendMode = BlendMode.softLight;
          canvas.drawRect(rect, shaderPaint);
          return;
        }
      } else {
        // Normal: unified fill + border in one draw call.
        final shader = LitShader.createShader(
          size: size,
          baseColor: baseColor,
          material: material ?? SurfaceMaterial.matte,
          profile: profile ?? SurfaceProfile.flat,
          scene: scene,
          screenCenter: screenCenter,
          curvature: curvature,
          borderWidth: borderWidth,
          borderRadius: borderRadius,
          normalMap: normalMap,
        );
        if (shader != null) {
          final shaderPaint = Paint()..shader = shader;
          canvas.drawRect(rect, shaderPaint);
          return;
        }
      }
    }

    // ── Border: per-edge brightness summed from all lights ──
    if (!overlayFill) {
      final edgeBrightness = List.filled(8, 0.0);
      for (final light in scene.lights) {
        final intensity = light.intensityAt(screenCenter);
        if (intensity < 0.001) continue;
        final dir = light.directionAt(screenCenter);

        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final nx = math.cos(angle);
          final ny = math.sin(angle);
          edgeBrightness[i] += (dir.dx * nx + dir.dy * ny) * intensity;
        }
      }

      final mRoughness = material?.roughness ?? 0.5;
      final mFresnel = material?.effectiveFresnel ?? 0.0;
      final mSheen = material?.effectiveSheen ?? 0.0;
      final mMetallic = material?.metallic ?? 0.0;

      final bLighten = material != null
          ? (0.3 + (1.0 - mRoughness) * 0.4) * (0.5 + (1.0 - mRoughness) * 0.5)
          : 0.4 * borderContrast;
      final bDarken = material != null
          ? -(0.05 + (1.0 - mRoughness) * 0.15)
          : -0.06 * borderContrast;
      final fresnelBoost = mFresnel * 0.15;
      final sheenBoost = mSheen * 0.08;

      final borderColors = edgeBrightness.map((b) {
        var lightnessOffset = b > 0 ? b * bLighten : b.abs() * bDarken;
        lightnessOffset += fresnelBoost + sheenBoost;
        var edgeColor = hsl
            .withLightness((hsl.lightness + lightnessOffset).clamp(0.0, 1.0))
            .toColor();
        if (b > 0 && mMetallic > 0) {
          edgeColor = Color.lerp(edgeColor, baseColor, mMetallic * 0.4)!;
        }
        return edgeColor;
      }).toList();

      final borderGradient = SweepGradient(
        center: Alignment.center,
        colors: [...borderColors, borderColors[0]],
        stops: [for (var i = 0; i < 8; i++) i / 8.0, 1.0],
      );

      final borderPaint = Paint()..shader = borderGradient.createShader(rect);
      canvas.drawRRect(outerRRect, borderPaint);
    }

    // ── Fill ──
    if (!borderOnly) {
      if (!overlayFill) {
        // Normal mode: solid base beneath gradient overlays
        final basePaint = Paint()..color = baseColor;
        canvas.drawRRect(innerRRect, basePaint);
      }

      if (curvature > 0) {
        canvas.save();
        canvas.clipRRect(innerRRect);

        final fillRect = innerRRect.outerRect;

        for (final light in scene.lights) {
          final intensity = light.intensityAt(screenCenter);
          if (intensity < 0.001) continue;
          final dir = light.directionAt(screenCenter);

          final effectiveFillContrast = material?.fillContrast ?? fillContrast;
          final lightenAmt =
              0.15 * intensity * effectiveFillContrast * curvature;
          final darkenAmt =
              0.20 * intensity * effectiveFillContrast * curvature;

          final Color lightSide;
          final Color darkSide;

          if (overlayFill) {
            // Overlay mode: neutral gray ± offset so overlay blend
            // lightens the lit side and darkens the shadow side.
            const mid = 0.5;
            lightSide = HSLColor.fromAHSL(
              intensity.clamp(0.0, 1.0),
              0,
              0,
              (mid + lightenAmt).clamp(0.0, 1.0),
            ).toColor();
            darkSide = HSLColor.fromAHSL(
              intensity.clamp(0.0, 1.0),
              0,
              0,
              (mid - darkenAmt).clamp(0.0, 1.0),
            ).toColor();
          } else {
            // Normal mode: base-color-tinted gradients
            final litBase =
                Color.lerp(baseColor, light.color, 0.5 * intensity)!;
            final litHsl = HSLColor.fromColor(litBase);

            lightSide = litHsl
                .withLightness((litHsl.lightness + lightenAmt).clamp(0.0, 1.0))
                .toColor()
                .withValues(alpha: intensity.clamp(0.0, 1.0));
            darkSide = hsl
                .withLightness((hsl.lightness - darkenAmt).clamp(0.0, 1.0))
                .toColor()
                .withValues(alpha: intensity.clamp(0.0, 1.0));
          }

          final Gradient gradient;

          if (light is DirectionalLight) {
            final begin =
                Alignment(dir.dx.clamp(-1.0, 1.0), dir.dy.clamp(-1.0, 1.0));
            final end = Alignment(
                (-dir.dx).clamp(-1.0, 1.0), (-dir.dy).clamp(-1.0, 1.0));
            gradient = LinearGradient(
                begin: begin, end: end, colors: [lightSide, darkSide]);
          } else {
            final Offset lightPos;
            if (light is PointLight) {
              lightPos = light.position;
            } else if (light is SpotLight) {
              lightPos = light.position;
            } else if (light is AreaLight) {
              lightPos = light.position;
            } else {
              lightPos = screenCenter;
            }

            final halfW = fillRect.width / 2;
            final halfH = fillRect.height / 2;
            final relX = (lightPos.dx - screenCenter.dx) / halfW;
            final relY = (lightPos.dy - screenCenter.dy) / halfH;
            final center =
                Alignment(relX.clamp(-3.0, 3.0), relY.clamp(-3.0, 3.0));

            final dist = (lightPos - screenCenter).distance;
            final maxDim = math.max(fillRect.width, fillRect.height);
            final radius = ((dist + maxDim) / maxDim).clamp(0.5, 4.0);

            gradient = RadialGradient(
                center: center, radius: radius, colors: [lightSide, darkSide]);
          }

          final paint = Paint()
            ..shader = gradient.createShader(fillRect)
            ..blendMode = overlayFill ? BlendMode.overlay : light.blendMode;
          canvas.drawRRect(innerRRect, paint);
        }

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_LitSurfacePainter oldDelegate) =>
      scene != oldDelegate.scene ||
      (screenCenter - oldDelegate.screenCenter).distanceSquared > 1.0 ||
      baseColor != oldDelegate.baseColor ||
      borderWidth != oldDelegate.borderWidth ||
      borderRadius != oldDelegate.borderRadius ||
      curvature != oldDelegate.curvature ||
      fillContrast != oldDelegate.fillContrast ||
      borderContrast != oldDelegate.borderContrast ||
      material != oldDelegate.material ||
      profile != oldDelegate.profile ||
      normalMap != oldDelegate.normalMap ||
      borderOnly != oldDelegate.borderOnly ||
      overlayFill != oldDelegate.overlayFill;
}
