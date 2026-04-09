import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'debug/widget_inspector.dart';
import 'light_scene.dart';
import 'light_theme.dart';
import 'light_types.dart';
import 'lit_shader.dart';
import 'material_theme.dart';
import 'surface_material.dart';
import 'surface_profile.dart';

/// A button whose gradients, border, and shadow are derived from a [LightScene].
///
/// Each light in the scene contributes independently:
/// - **Fill**: layered gradient overlays, one per light (curvature-dependent)
/// - **Border**: single sweep gradient with per-edge brightness summed from all lights
/// - **Shadow**: one shadow per light, layered
class LitButton extends StatefulWidget {
  const LitButton({
    super.key,
    required this.onTap,
    required this.baseColor,
    required this.child,
    this.borderRadius,
    this.padding,
    this.borderWidth = 1,
    this.elevation = 4,
    this.curvature = 0.05,
    this.hoverLightenAmount = 0.02,
    this.fillContrast = 1.0,
    this.borderContrast = 1.0,
    this.scene,
    this.material,
    this.profile,
    this.normalMap,
  });

  final VoidCallback onTap;
  final Color baseColor;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final double borderWidth;
  final double elevation;
  final double curvature;
  final double hoverLightenAmount;
  final double fillContrast;
  final double borderContrast;

  /// Override the inherited scene for this button.
  final LightScene? scene;

  /// Optional PBR material properties for this button's surface.
  final SurfaceMaterial? material;

  /// Optional procedural heightmap profile for this button's surface.
  final SurfaceProfile? profile;

  /// Optional normal map image for texture-based surface normals.
  final ui.Image? normalMap;

  @override
  State<LitButton> createState() => _LitButtonState();
}

class _LitButtonState extends State<LitButton> {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Offset _getScreenCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene ?? LightTheme.of(context);
    final effectiveMaterial =
        LitMaterialTheme.resolveOf(context, widget.material);
    final effectiveProfile =
        widget.profile ?? LitMaterialTheme.profileOf(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(10);
    final padding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    final screenCenter = _getScreenCenter();

    final box = context.findRenderObject() as RenderBox?;
    LitWidgetInspector.register(
      widgetHashCode: widget.hashCode,
      widgetType: 'LitButton',
      material: widget.material,
      bounds: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );

    // Wrap in backdrop blur for translucent surfaces
    final translucency = effectiveMaterial?.translucency ?? 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Animate(
        target: _isHovered ? 1.0 : 0.0,
        effects: [
          CustomEffect(
            duration: 120.ms,
            curve: Curves.easeOut,
            begin: 0.0,
            end: widget.hoverLightenAmount,
            builder: (context, hoverAmount, child) {
              Widget paintedButton = CustomPaint(
                painter: _LitButtonPainter(
                  scene: scene,
                  screenCenter: screenCenter,
                  baseColor: widget.baseColor,
                  borderWidth: widget.borderWidth,
                  borderRadius: radius,
                  surfaceElevation: widget.elevation,
                  curvature: widget.curvature,
                  fillContrast: widget.fillContrast,
                  borderContrast: widget.borderContrast,
                  hoverAmount: hoverAmount,
                  material: effectiveMaterial,
                  profile: effectiveProfile,
                  normalMap: widget.normalMap,
                ),
                child: child,
              );

              if (translucency > 0) {
                final sigma =
                    8.0 * translucency * (effectiveMaterial?.roughness ?? 0.0);
                paintedButton = ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: paintedButton,
                  ),
                );
              }

              return GestureDetector(
                onTap: widget.onTap,
                child: paintedButton,
              );
            },
          ),
        ],
        child: Padding(
          padding: padding + EdgeInsets.all(widget.borderWidth),
          child: widget.child,
        ),
      ),
    );
  }
}

class _LitButtonPainter extends CustomPainter {
  _LitButtonPainter({
    required this.scene,
    required this.screenCenter,
    required this.baseColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.surfaceElevation,
    required this.curvature,
    required this.fillContrast,
    required this.borderContrast,
    required this.hoverAmount,
    this.material,
    this.profile,
    this.normalMap,
  });

  final LightScene scene;
  final Offset screenCenter;
  final Color baseColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final double surfaceElevation;
  final double curvature;
  final double fillContrast;
  final double borderContrast;
  final double hoverAmount;
  final SurfaceMaterial? material;
  final SurfaceProfile? profile;
  final ui.Image? normalMap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect = borderRadius.toRRect(rect);
    final innerRRect = outerRRect.deflate(borderWidth);
    final hsl = HSLColor.fromColor(baseColor);

    // ── Shadows (one per light, behind everything — always Canvas) ──
    for (final light in scene.lights) {
      final intensity = light.intensityAt(screenCenter);
      if (intensity < 0.001) continue;
      final dir = light.directionAt(screenCenter);

      final shadowDistance = surfaceElevation * (1.0 - 0.5 * 0.8);
      final shadowBlur = material != null
          ? surfaceElevation * (1.5 - 0.5) * (1.0 + material!.roughness * 0.5)
          : surfaceElevation * (1.5 - 0.5);
      final shadowOffset =
          Offset(-dir.dx * shadowDistance, -dir.dy * shadowDistance);
      final shadowOpacity = (0.12 * intensity).clamp(0.0, 0.4);

      final shadowRRect = outerRRect.shift(shadowOffset);
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: shadowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur * 0.5);
      canvas.drawRRect(shadowRRect, shadowPaint);
    }

    // ── Compute effective base (hover) ──
    var effectiveBase = baseColor;
    if (hoverAmount != 0) {
      final h = HSLColor.fromColor(effectiveBase);
      effectiveBase = h
          .withLightness((h.lightness + hoverAmount).clamp(0.0, 1.0))
          .toColor();
    }

    // ── Shader path: unified fill + border in one draw call ──
    final useShader = LitShader.isLoaded &&
        (material != null ||
            (profile != null && profile!.pattern != SurfacePattern.flat));
    if (useShader) {
      final shader = LitShader.createShader(
        size: size,
        baseColor: effectiveBase,
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

    // ── Canvas fallback: border + fill ──

    // ── Border (single sweep gradient, per-edge brightness summed from all lights) ──
    final edgeBrightness = List.filled(8, 0.0);
    // Track weighted color tint per edge for colored lights.
    final edgeTintR = List.filled(8, 0.0);
    final edgeTintG = List.filled(8, 0.0);
    final edgeTintB = List.filled(8, 0.0);

    for (final light in scene.lights) {
      final intensity = light.intensityAt(screenCenter);
      if (intensity < 0.001) continue;
      final dir = light.directionAt(screenCenter);

      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final nx = math.cos(angle);
        final ny = math.sin(angle);
        final dot = dir.dx * nx + dir.dy * ny;
        edgeBrightness[i] += dot * intensity;
        // Only tint edges that face the light (positive dot)
        if (dot > 0) {
          final w = dot * intensity;
          edgeTintR[i] += light.color.r * w;
          edgeTintG[i] += light.color.g * w;
          edgeTintB[i] += light.color.b * w;
        }
      }
    }

    // Material-aware border computation
    final mRoughness = material?.roughness ?? 0.5;
    final mMetallic = material?.metallic ?? 0.0;
    final mFresnel = material?.effectiveFresnel ?? 0.0;
    final mSheen = material?.effectiveSheen ?? 0.0;

    // Smooth surfaces → tight bright peak (up to 0.7), rough → broad dim (0.3)
    final bLighten = material != null
        ? (0.3 + (1.0 - mRoughness) * 0.4) * (0.5 + (1.0 - mRoughness) * 0.5)
        : 0.4 * borderContrast;
    final bDarken = material != null
        ? -(0.05 + (1.0 - mRoughness) * 0.15)
        : -0.06 * borderContrast;

    // Fresnel adds uniform edge brightness regardless of light direction
    final fresnelBoost = mFresnel * 0.15;
    // Sheen adds a softer uniform edge glow
    final sheenBoost = mSheen * 0.08;

    final borderColors = List.generate(8, (i) {
      final b = edgeBrightness[i];
      var lightnessOffset = b > 0 ? b * bLighten : b.abs() * bDarken;
      // Fresnel + sheen: always brighten edges slightly
      lightnessOffset += fresnelBoost + sheenBoost;
      var edgeColor = hsl
          .withLightness((hsl.lightness + lightnessOffset).clamp(0.0, 1.0))
          .toColor();
      // Metallic: tint bright edges with the base color instead of going white
      if (b > 0 && mMetallic > 0) {
        edgeColor = Color.lerp(edgeColor, baseColor, mMetallic * 0.4)!;
        // Also boost saturation for metals
        final edgeHsl = HSLColor.fromColor(edgeColor);
        edgeColor = edgeHsl
            .withSaturation(
                (edgeHsl.saturation + mMetallic * 0.3).clamp(0.0, 1.0))
            .toColor();
      }
      // Light color tinting (existing)
      if (b > 0 && (edgeTintR[i] + edgeTintG[i] + edgeTintB[i]) > 0) {
        final totalW = edgeTintR[i] + edgeTintG[i] + edgeTintB[i];
        final tintColor = Color.from(
          alpha: 1.0,
          red: (edgeTintR[i] / totalW * 3).clamp(0.0, 1.0),
          green: (edgeTintG[i] / totalW * 3).clamp(0.0, 1.0),
          blue: (edgeTintB[i] / totalW * 3).clamp(0.0, 1.0),
        );
        edgeColor = Color.lerp(edgeColor, tintColor, 0.3 * b.clamp(0.0, 1.0))!;
      }
      return edgeColor;
    });

    final borderGradient = SweepGradient(
      center: Alignment.center,
      colors: [...borderColors, borderColors[0]], // close the loop
      stops: [
        for (var i = 0; i < 8; i++) i / 8.0,
        1.0,
      ],
    );

    final borderPaint = Paint()..shader = borderGradient.createShader(rect);
    canvas.drawRRect(outerRRect, borderPaint);

    // ── Fill: base color with per-light HSL gradient overlays ──
    if (curvature > 0 && scene.lights.isNotEmpty) {
      final baseHsl = HSLColor.fromColor(effectiveBase);

      final basePaint = Paint()..color = effectiveBase;
      canvas.drawRRect(innerRRect, basePaint);

      canvas.save();
      canvas.clipRRect(innerRRect);

      for (final light in scene.lights) {
        final intensity = light.intensityAt(screenCenter);
        if (intensity < 0.001) continue;
        final dir = light.directionAt(screenCenter);

        final effectiveFillContrast = material?.fillContrast ?? fillContrast;
        final lightenAmount =
            0.15 * intensity * effectiveFillContrast * curvature;
        final darkenAmount =
            0.20 * intensity * effectiveFillContrast * curvature;

        final tintTarget = mMetallic > 0.5 ? baseColor : light.color;
        final litBase = Color.lerp(effectiveBase, tintTarget, 0.5 * intensity)!;
        final litHsl = HSLColor.fromColor(litBase);

        final lightSide = litHsl
            .withLightness((litHsl.lightness + lightenAmount).clamp(0.0, 1.0))
            .toColor()
            .withValues(alpha: intensity.clamp(0.0, 1.0));
        final darkSide = baseHsl
            .withLightness((baseHsl.lightness - darkenAmount).clamp(0.0, 1.0))
            .toColor()
            .withValues(alpha: intensity.clamp(0.0, 1.0));

        final fillRect = innerRRect.outerRect;
        final Gradient gradient;

        if (light is DirectionalLight) {
          final begin =
              Alignment(dir.dx.clamp(-1.0, 1.0), dir.dy.clamp(-1.0, 1.0));
          final end =
              Alignment((-dir.dx).clamp(-1.0, 1.0), (-dir.dy).clamp(-1.0, 1.0));
          gradient = LinearGradient(
            begin: begin,
            end: end,
            colors: [lightSide, darkSide],
          );
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
            center: center,
            radius: radius,
            colors: [lightSide, darkSide],
          );
        }

        final paint = Paint()
          ..shader = gradient.createShader(fillRect)
          ..blendMode = light.blendMode;
        canvas.drawRRect(innerRRect, paint);
      }

      canvas.restore();
    } else {
      final basePaint = Paint()..color = effectiveBase;
      canvas.drawRRect(innerRRect, basePaint);
    }
  }

  @override
  bool shouldRepaint(_LitButtonPainter oldDelegate) =>
      scene != oldDelegate.scene ||
      (screenCenter - oldDelegate.screenCenter).distanceSquared > 1.0 ||
      baseColor != oldDelegate.baseColor ||
      borderWidth != oldDelegate.borderWidth ||
      borderRadius != oldDelegate.borderRadius ||
      surfaceElevation != oldDelegate.surfaceElevation ||
      curvature != oldDelegate.curvature ||
      fillContrast != oldDelegate.fillContrast ||
      borderContrast != oldDelegate.borderContrast ||
      hoverAmount != oldDelegate.hoverAmount ||
      material != oldDelegate.material ||
      profile != oldDelegate.profile ||
      normalMap != oldDelegate.normalMap;
}
