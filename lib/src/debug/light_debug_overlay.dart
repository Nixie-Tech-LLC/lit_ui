import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../border_theme.dart';
import '../light_scene.dart';
import '../light_types.dart';
import '../light_theme.dart';
import '../material_theme.dart';
import '../surface_material.dart';
import '../surface_profile.dart';
import 'light_debug_controller.dart';
import 'widget_inspector.dart';

/// A debug overlay that provides interactive controls for a [LightScene].
///
/// Wrap your app with [LightDebugOverlay] in debug mode. It renders a
/// [LightTheme] whose values are driven by an interactive panel that
/// supports multiple lights of different types.
///
/// ```dart
/// LightDebugOverlay(
///   defaultScene: LightScene(lights: [
///     DirectionalLight(angle: 0, intensity: 0.68),
///   ]),
///   child: MyApp(),
/// )
/// ```
class LightDebugOverlay extends StatefulWidget {
  const LightDebugOverlay({
    super.key,
    required this.child,
    this.defaultScene,
    this.enabled = true,
  });

  final Widget child;
  final LightScene? defaultScene;
  final bool enabled;

  @override
  State<LightDebugOverlay> createState() => _LightDebugOverlayState();
}

class _LightDebugOverlayState extends State<LightDebugOverlay> {
  late final LightDebugController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LightDebugController(defaultScene: widget.defaultScene);
    if (widget.enabled) LitWidgetInspector.enabled = true;
  }

  @override
  void dispose() {
    LitWidgetInspector.enabled = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      final scene = widget.defaultScene ??
          LightScene.directional(angle: 354 * math.pi / 180, intensity: 0.45);
      return LightTheme(
        scene: scene,
        child: LitMaterialTheme(
          presetOverrides: LitMaterialTheme.presetDefaults,
          profile: SurfaceProfile.flat,
          child: LitBorderTheme(
            child: widget.child,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => LightTheme(
        scene: _controller.scene,
        child: LitMaterialTheme(
          presetOverrides: _controller.presetOverrides,
          profile: _controller.profile,
          defaultMaterial: _controller.selectedPresetMaterial,
          child: LitBorderTheme(
            outerShadowIntensity: _controller.outerShadowIntensity,
            outerShadowWidth: _controller.outerShadowWidth,
            innerShadowIntensity: _controller.innerShadowIntensity,
            innerShadowWidth: _controller.innerShadowWidth,
            child: Directionality(
          textDirection: TextDirection.ltr,
          child: MouseRegion(
            onHover: (event) => _controller.onCursorMove(event.position),
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                // Light ray visualization
                if (_controller.showRays)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LightRaysPainter(
                          lights: _controller.lights,
                          selectedIndex: _controller.selectedIndex,
                        ),
                      ),
                    ),
                  ),
                // Position markers for positional lights
                ..._buildPositionMarkers(),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _controller.isExpanded
                      ? _ExpandedPanel(controller: _controller)
                      : _CollapsedButton(controller: _controller),
                ),
              ],
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }

  List<Widget> _buildPositionMarkers() {
    final markers = <Widget>[];
    for (var i = 0; i < _controller.lights.length; i++) {
      final light = _controller.lights[i];
      Offset? position;
      if (light is PointLight) {
        position = light.position;
      } else if (light is SpotLight) {
        position = light.position;
      } else if (light is AreaLight) {
        position = light.position;
      }
      if (position == null) continue;

      final isSelected = i == _controller.selectedIndex;
      final color = _lightTypeColor(light);
      final index = i;

      markers.add(
        Positioned(
          left: position.dx - 10,
          top: position.dy - 10,
          child: GestureDetector(
            onTap: () => _controller.selectLight(index),
            onPanUpdate: (details) {
              final newPos = position! + details.delta;
              final updated = _copyWithPosition(light, newPos);
              _controller.updateLight(index, updated);
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.9 : 0.6),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Color _lightTypeColor(SceneLight light) {
    if (light is PointLight) return Colors.orange;
    if (light is SpotLight) return Colors.blue;
    if (light is AreaLight) return Colors.green;
    return Colors.grey;
  }

  SceneLight _copyWithPosition(SceneLight light, Offset newPos) {
    if (light is PointLight) {
      return PointLight(
        position: newPos,
        height: light.height,
        intensity: light.intensity,
        falloff: light.falloff,
        color: light.color,
        blendMode: light.blendMode,
      );
    } else if (light is SpotLight) {
      return SpotLight(
        position: newPos,
        height: light.height,
        direction: light.direction,
        coneAngle: light.coneAngle,
        softEdge: light.softEdge,
        falloff: light.falloff,
        intensity: light.intensity,
        color: light.color,
        blendMode: light.blendMode,
      );
    } else if (light is AreaLight) {
      return AreaLight(
        position: newPos,
        height: light.height,
        size: light.size,
        intensity: light.intensity,
        color: light.color,
        blendMode: light.blendMode,
      );
    }
    return light;
  }
}

// ── Collapsed button ───────────────────────────────────────────────────────────

class _CollapsedButton extends StatelessWidget {
  final LightDebugController controller;

  const _CollapsedButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final count = controller.lights.length;
    final selected = controller.selectedLight;
    final label = count == 1 && selected != null
        ? controller.lightTypeLabel(selected)
        : '$count lights';

    return GestureDetector(
      onTap: controller.toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.light_mode, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded panel ─────────────────────────────────────────────────────────────

class _ExpandedPanel extends StatelessWidget {
  final LightDebugController controller;

  const _ExpandedPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with close
          Row(
            children: [
              const Icon(Icons.tune, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              const Text(
                'Lit UI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: controller.toggle,
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tab bar
          _TabBar(
            selectedIndex: controller.tabIndex,
            onChanged: controller.setTab,
          ),
          const SizedBox(height: 8),
          // Tab content
          if (controller.tabIndex == 0)
            _LightsTab(controller: controller)
          else
            _MaterialsTab(controller: controller),
        ],
      ),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabBar({required this.selectedIndex, required this.onChanged});

  static const _tabs = ['Lights', 'Materials'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: i == selectedIndex
                        ? Colors.amber
                        : Colors.grey.shade200,
                    width: i == selectedIndex ? 1.5 : 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == selectedIndex
                          ? Colors.amber.shade800
                          : Colors.black54,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Lights tab ───────────────────────────────────────────────────────────────

class _LightsTab extends StatelessWidget {
  final LightDebugController controller;

  const _LightsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar row
        Row(
          children: [
            Text(
              '${controller.lights.length} light${controller.lights.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: Colors.black54,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: controller.toggleRays,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.grain,
                  size: 14,
                  color: controller.showRays ? Colors.amber : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: controller.reset,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.refresh, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LightChipsRow(controller: controller),
        const SizedBox(height: 8),
        _AddLightRow(controller: controller),
        if (selected != null) ...[
          const Divider(height: 16),
          _LightEditor(
            index: controller.selectedIndex,
            light: selected,
            controller: controller,
          ),
        ],
      ],
    );
  }
}

// ── Materials tab ────────────────────────────────────────────────────────────

class _MaterialsTab extends StatelessWidget {
  final LightDebugController controller;

  const _MaterialsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final counts = LitWidgetInspector.countsByPreset;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MaterialSelector(
          presetOverrides: controller.presetOverrides,
          selectedKey: controller.selectedPresetKey,
          onSelectPreset: controller.selectPreset,
          onUpdatePreset: controller.updateSelectedPreset,
          onResetPreset: controller.resetPreset,
        ),
        // Widget count for selected preset
        if (counts.isNotEmpty) ...[
          const SizedBox(height: 6),
          _WidgetList(
            entries: LitWidgetInspector.entries,
            selectedPresetKey: controller.selectedPresetKey,
          ),
        ],
        const Divider(height: 16),
        _ProfileEditor(
          profile: controller.profile,
          onChanged: controller.setProfile,
        ),
        const Divider(height: 16),
        _BorderEditor(controller: controller),
      ],
    );
  }
}

// ── Light chips row ────────────────────────────────────────────────────────────

class _LightChipsRow extends StatelessWidget {
  final LightDebugController controller;

  const _LightChipsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < controller.lights.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _LightChip(
              index: i,
              light: controller.lights[i],
              isSelected: i == controller.selectedIndex,
              controller: controller,
            ),
          ],
        ],
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  final int index;
  final SceneLight light;
  final bool isSelected;
  final LightDebugController controller;

  const _LightChip({
    required this.index,
    required this.light,
    required this.isSelected,
    required this.controller,
  });

  IconData _iconFor(SceneLight light) {
    if (light is DirectionalLight) return Icons.wb_sunny;
    if (light is SpotLight) return Icons.flashlight_on;
    if (light is AreaLight) return Icons.grid_view;
    return Icons.lightbulb; // PointLight
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.selectLight(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(light),
              size: 12,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add light row ──────────────────────────────────────────────────────────────

class _AddLightRow extends StatelessWidget {
  final LightDebugController controller;

  const _AddLightRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Add:',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 4),
        _AddButton(
          label: 'Dir',
          onTap: () => controller.addLight(
            DirectionalLight(angle: 0, intensity: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        _AddButton(
          label: 'Pt',
          onTap: () => controller.addLight(
            const PointLight(
              position: Offset(700, 400),
              height: 500,
              intensity: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _AddButton(
          label: 'Spot',
          onTap: () => controller.addLight(
            const SpotLight(
              position: Offset(700, 400),
              height: 500,
              intensity: 0.6,
              direction: Offset(0, 1),
              coneAngle: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _AddButton(
          label: 'Area',
          onTap: () => controller.addLight(
            const AreaLight(
              position: Offset(700, 400),
              height: 500,
              intensity: 0.6,
              size: Size(200, 200),
            ),
          ),
        ),
        if (controller.lights.length > 1) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => controller.removeLight(controller.selectedIndex),
            child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
          ),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '+ $label',
          style: const TextStyle(
            fontSize: 10,
            decoration: TextDecoration.none,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ── Light property editor ──────────────────────────────────────────────────────

class _LightEditor extends StatelessWidget {
  final int index;
  final SceneLight light;
  final LightDebugController controller;

  const _LightEditor({
    required this.index,
    required this.light,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (light is DirectionalLight) {
      return _DirectionalLightEditor(
        index: index,
        light: light as DirectionalLight,
        controller: controller,
      );
    } else if (light is SpotLight) {
      return _SpotLightEditor(
        index: index,
        light: light as SpotLight,
        controller: controller,
      );
    } else if (light is AreaLight) {
      return _AreaLightEditor(
        index: index,
        light: light as AreaLight,
        controller: controller,
      );
    } else if (light is PointLight) {
      return _PointLightEditor(
        index: index,
        light: light as PointLight,
        controller: controller,
      );
    }
    return const SizedBox.shrink();
  }
}

// ── DirectionalLight editor ────────────────────────────────────────────────────

class _DirectionalLightEditor extends StatelessWidget {
  final int index;
  final DirectionalLight light;
  final LightDebugController controller;

  const _DirectionalLightEditor({
    required this.index,
    required this.light,
    required this.controller,
  });

  String get _angleLabel {
    final degrees = (light.angle * 180 / math.pi) % 360;
    return '${degrees.round()}°';
  }

  String get _directionLabel {
    final deg = (light.angle * 180 / math.pi) % 360;
    if (deg >= 337.5 || deg < 22.5) return 'Top';
    if (deg < 67.5) return 'Top-Right';
    if (deg < 112.5) return 'Right';
    if (deg < 157.5) return 'Bottom-Right';
    if (deg < 202.5) return 'Bottom';
    if (deg < 247.5) return 'Bottom-Left';
    if (deg < 292.5) return 'Left';
    return 'Top-Left';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Directional',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Text(
                '$_directionLabel $_angleLabel',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _AngleDial(
                angle: light.angle,
                onChanged: (v) => controller.updateLight(
                  index,
                  DirectionalLight(
                    angle: v,
                    intensity: light.intensity,
                    color: light.color,
                    blendMode: light.blendMode,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SliderRow(
          label: 'Intensity',
          value: light.intensity,
          min: 0,
          max: 1,
          trailing: light.intensity.toStringAsFixed(2),
          onChanged: (v) => controller.updateLight(
            index,
            DirectionalLight(angle: light.angle, intensity: v, color: light.color, blendMode: light.blendMode),
          ),
        ),
        const SizedBox(height: 8),
        _HexColorPicker(
          color: light.color,
          onChanged: (c) => controller.updateLight(
            index,
            DirectionalLight(angle: light.angle, intensity: light.intensity, color: c, blendMode: light.blendMode),
          ),
        ),
        const SizedBox(height: 8),
        _BlendModeSelector(
          selected: light.blendMode,
          onChanged: (m) => controller.updateLight(
            index,
            DirectionalLight(angle: light.angle, intensity: light.intensity, color: light.color, blendMode: m),
          ),
        ),
      ],
    );
  }
}

// ── PointLight editor ──────────────────────────────────────────────────────────

class _PointLightEditor extends StatelessWidget {
  final int index;
  final PointLight light;
  final LightDebugController controller;

  const _PointLightEditor({
    required this.index,
    required this.light,
    required this.controller,
  });

  void _update(LightDebugController c, {
    Offset? position,
    double? height,
    double? intensity,
  }) {
    c.updateLight(
      index,
      PointLight(
        position: position ?? light.position,
        height: height ?? light.height,
        intensity: intensity ?? light.intensity,
        falloff: light.falloff,
        color: light.color,
        blendMode: light.blendMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PositionalLightHeader(
          label: 'Point',
          isFollowing: controller.cursorFollowIndex == index,
          onToggleFollow: () => controller.toggleCursorFollow(index),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'X',
          value: light.position.dx,
          min: 0,
          max: 1920,
          trailing: light.position.dx.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(v, light.position.dy)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Y',
          value: light.position.dy,
          min: 0,
          max: 1080,
          trailing: light.position.dy.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(light.position.dx, v)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Height',
          value: light.height,
          min: 50,
          max: 2000,
          trailing: light.height.round().toString(),
          onChanged: (v) => _update(controller, height: v),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Intensity',
          value: light.intensity,
          min: 0,
          max: 1,
          trailing: light.intensity.toStringAsFixed(2),
          onChanged: (v) => _update(controller, intensity: v),
        ),
        const SizedBox(height: 8),
        _HexColorPicker(
          color: light.color,
          onChanged: (c) => controller.updateLight(
            index,
            PointLight(
              position: light.position,
              height: light.height,
              intensity: light.intensity,
              falloff: light.falloff,
              color: c,
              blendMode: light.blendMode,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _BlendModeSelector(
          selected: light.blendMode,
          onChanged: (m) => controller.updateLight(
            index,
            PointLight(
              position: light.position,
              height: light.height,
              intensity: light.intensity,
              falloff: light.falloff,
              color: light.color,
              blendMode: m,
            ),
          ),
        ),
      ],
    );
  }
}

// ── SpotLight editor ───────────────────────────────────────────────────────────

class _SpotLightEditor extends StatelessWidget {
  final int index;
  final SpotLight light;
  final LightDebugController controller;

  const _SpotLightEditor({
    required this.index,
    required this.light,
    required this.controller,
  });

  void _update(LightDebugController c, {
    Offset? position,
    double? height,
    double? intensity,
    double? coneAngle,
  }) {
    c.updateLight(
      index,
      SpotLight(
        position: position ?? light.position,
        height: height ?? light.height,
        direction: light.direction,
        coneAngle: coneAngle ?? light.coneAngle,
        softEdge: light.softEdge,
        falloff: light.falloff,
        intensity: intensity ?? light.intensity,
        color: light.color,
        blendMode: light.blendMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = controller.cursorFollowIndex == index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PositionalLightHeader(
          label: 'Spot',
          isFollowing: isFollowing,
          onToggleFollow: () => controller.toggleCursorFollow(index),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'X',
          value: light.position.dx,
          min: 0,
          max: 1920,
          trailing: light.position.dx.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(v, light.position.dy)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Y',
          value: light.position.dy,
          min: 0,
          max: 1080,
          trailing: light.position.dy.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(light.position.dx, v)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Height',
          value: light.height,
          min: 50,
          max: 2000,
          trailing: light.height.round().toString(),
          onChanged: (v) => _update(controller, height: v),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Intensity',
          value: light.intensity,
          min: 0,
          max: 1,
          trailing: light.intensity.toStringAsFixed(2),
          onChanged: (v) => _update(controller, intensity: v),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Cone',
          value: light.coneAngle,
          min: 0.1,
          max: math.pi,
          trailing: '${(light.coneAngle * 180 / math.pi).round()}°',
          onChanged: (v) => _update(controller, coneAngle: v),
        ),
        const SizedBox(height: 8),
        _HexColorPicker(
          color: light.color,
          onChanged: (c) => controller.updateLight(
            index,
            SpotLight(
              position: light.position,
              height: light.height,
              intensity: light.intensity,
              direction: light.direction,
              coneAngle: light.coneAngle,
              softEdge: light.softEdge,
              falloff: light.falloff,
              color: c,
              blendMode: light.blendMode,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _BlendModeSelector(
          selected: light.blendMode,
          onChanged: (m) => controller.updateLight(
            index,
            SpotLight(
              position: light.position,
              height: light.height,
              intensity: light.intensity,
              direction: light.direction,
              coneAngle: light.coneAngle,
              softEdge: light.softEdge,
              falloff: light.falloff,
              color: light.color,
              blendMode: m,
            ),
          ),
        ),
      ],
    );
  }
}

// ── AreaLight editor ───────────────────────────────────────────────────────────

class _AreaLightEditor extends StatelessWidget {
  final int index;
  final AreaLight light;
  final LightDebugController controller;

  const _AreaLightEditor({
    required this.index,
    required this.light,
    required this.controller,
  });

  void _update(LightDebugController c, {
    Offset? position,
    double? height,
    double? intensity,
    Size? size,
  }) {
    c.updateLight(
      index,
      AreaLight(
        position: position ?? light.position,
        height: height ?? light.height,
        size: size ?? light.size,
        intensity: intensity ?? light.intensity,
        color: light.color,
        blendMode: light.blendMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PositionalLightHeader(
          label: 'Area',
          isFollowing: controller.cursorFollowIndex == index,
          onToggleFollow: () => controller.toggleCursorFollow(index),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'X',
          value: light.position.dx,
          min: 0,
          max: 1920,
          trailing: light.position.dx.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(v, light.position.dy)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Y',
          value: light.position.dy,
          min: 0,
          max: 1080,
          trailing: light.position.dy.round().toString(),
          onChanged: (v) => _update(controller,
              position: Offset(light.position.dx, v)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Height',
          value: light.height,
          min: 50,
          max: 2000,
          trailing: light.height.round().toString(),
          onChanged: (v) => _update(controller, height: v),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Intensity',
          value: light.intensity,
          min: 0,
          max: 1,
          trailing: light.intensity.toStringAsFixed(2),
          onChanged: (v) => _update(controller, intensity: v),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Width',
          value: light.size.width,
          min: 10,
          max: 1920,
          trailing: light.size.width.round().toString(),
          onChanged: (v) => _update(controller,
              size: Size(v, light.size.height)),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'H-size',
          value: light.size.height,
          min: 10,
          max: 1080,
          trailing: light.size.height.round().toString(),
          onChanged: (v) => _update(controller,
              size: Size(light.size.width, v)),
        ),
        const SizedBox(height: 8),
        _HexColorPicker(
          color: light.color,
          onChanged: (c) => controller.updateLight(
            index,
            AreaLight(
              position: light.position,
              height: light.height,
              size: light.size,
              intensity: light.intensity,
              color: c,
              blendMode: light.blendMode,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _BlendModeSelector(
          selected: light.blendMode,
          onChanged: (m) => controller.updateLight(
            index,
            AreaLight(
              position: light.position,
              height: light.height,
              size: light.size,
              intensity: light.intensity,
              color: light.color,
              blendMode: m,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Angle dial ─────────────────────────────────────────────────────────────────

class _AngleDial extends StatelessWidget {
  final double angle;
  final ValueChanged<double> onChanged;

  const _AngleDial({required this.angle, required this.onChanged});

  static const double _size = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _updateAngle(d.localPosition),
      onPanUpdate: (d) => _updateAngle(d.localPosition),
      child: SizedBox(
        width: _size,
        height: _size,
        child: CustomPaint(
          painter: _AngleDialPainter(angle: angle),
        ),
      ),
    );
  }

  void _updateAngle(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    final delta = local - center;
    final rad =
        (math.atan2(delta.dx, -delta.dy) + 2 * math.pi) % (2 * math.pi);
    onChanged(rad);
  }
}

class _AngleDialPainter extends CustomPainter {
  final double angle;

  _AngleDialPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final ringPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final outer = center + Offset(math.sin(a), -math.cos(a)) * radius;
      final inner = center +
          Offset(math.sin(a), -math.cos(a)) *
              (radius - (i % 2 == 0 ? 6 : 3));
      canvas.drawLine(inner, outer, tickPaint);
    }

    final dirEnd =
        center + Offset(math.sin(angle), -math.cos(angle)) * (radius - 2);
    final linePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, dirEnd, linePaint);

    final thumbPaint = Paint()..color = Colors.amber;
    canvas.drawCircle(dirEnd, 5, thumbPaint);

    final centerPaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(center, 2.5, centerPaint);
  }

  @override
  bool shouldRepaint(_AngleDialPainter oldDelegate) =>
      angle != oldDelegate.angle;
}

// ── Track slider ───────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String trailing;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.trailing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _TrackSlider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TrackSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _TrackSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  static const double _thumbRadius = 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset local) {
          final trackLeft = _thumbRadius;
          final trackRight = width - _thumbRadius;
          final fraction =
              ((local.dx - trackLeft) / (trackRight - trackLeft)).clamp(0.0, 1.0);
          onChanged(min + fraction * (max - min));
        }

        return GestureDetector(
          onPanStart: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          onTapDown: (d) => update(d.localPosition),
          child: SizedBox(
            height: 20,
            width: width,
            child: CustomPaint(
              painter: _TrackSliderPainter(
                fraction: (value - min) / (max - min),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackSliderPainter extends CustomPainter {
  final double fraction;

  _TrackSliderPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    const thumbRadius = 6.0;
    const trackHeight = 2.0;
    final trackY = size.height / 2;
    final trackLeft = thumbRadius;
    final trackRight = size.width - thumbRadius;
    final trackWidth = trackRight - trackLeft;

    // Inactive track
    final inactivePaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(trackLeft, trackY),
      Offset(trackRight, trackY),
      inactivePaint,
    );

    // Active track
    final thumbX = trackLeft + fraction * trackWidth;
    final activePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(trackLeft, trackY),
      Offset(thumbX, trackY),
      activePaint,
    );

    // Thumb
    final thumbPaint = Paint()..color = Colors.amber;
    canvas.drawCircle(Offset(thumbX, trackY), thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(_TrackSliderPainter oldDelegate) =>
      fraction != oldDelegate.fraction;
}

// ── Hex color picker ─────────────────────────────────────────────────────────

class _HexColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _HexColorPicker({required this.color, required this.onChanged});

  @override
  State<_HexColorPicker> createState() => _HexColorPickerState();
}

class _HexColorPickerState extends State<_HexColorPicker> {
  late TextEditingController _textController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _colorToHex(widget.color));
  }

  @override
  void didUpdateWidget(_HexColorPicker old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.color != old.color) {
      _textController.text = _colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static String _colorToHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  static Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return null;
  }

  void _submit() {
    final c = _hexToColor(_textController.text);
    if (c != null) widget.onChanged(c);
    setState(() => _editing = false);
  }

  static const _presets = [
    Color(0xFFFFFFFF), // white
    Color(0xFFFFF4E0), // warm
    Color(0xFFE0F0FF), // cool
    Color(0xFFFFD6D6), // rose
    Color(0xFFD6FFD6), // green
    Color(0xFFFFE0A0), // amber
    Color(0xFFA0D0FF), // sky
    Color(0xFFE0D0FF), // lavender
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Color swatch preview
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400, width: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '#',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                decoration: TextDecoration.none,
                fontFamily: 'monospace',
              ),
            ),
            // Hex input field
            SizedBox(
              width: 60,
              height: 20,
              child: EditableText(
                controller: _textController,
                focusNode: FocusNode(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                  fontFamily: 'monospace',
                ),
                cursorColor: Colors.amber,
                backgroundCursorColor: Colors.grey,
                onChanged: (v) {
                  _editing = true;
                  final c = _hexToColor(v);
                  if (c != null) widget.onChanged(c);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Preset color swatches
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _presets.map((c) {
            final isSelected = _colorToHex(c) == _colorToHex(widget.color);
            return GestureDetector(
              onTap: () {
                widget.onChanged(c);
                _textController.text = _colorToHex(c);
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                    width: isSelected ? 2 : 0.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Positional light header with cursor follow toggle ────────────────────────

class _PositionalLightHeader extends StatelessWidget {
  final String label;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  const _PositionalLightHeader({
    required this.label,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
            color: Colors.black54,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onToggleFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isFollowing ? Colors.amber : Colors.grey.shade300,
                width: isFollowing ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mouse, size: 10, color: isFollowing ? Colors.amber.shade800 : Colors.black45),
                const SizedBox(width: 3),
                Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isFollowing ? FontWeight.w700 : FontWeight.w500,
                    color: isFollowing ? Colors.amber.shade800 : Colors.black54,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Light rays painter ───────────────────────────────────────────────────────

class _LightRaysPainter extends CustomPainter {
  final List<SceneLight> lights;
  final int selectedIndex;

  _LightRaysPainter({required this.lights, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < lights.length; i++) {
      final light = lights[i];
      final isSelected = i == selectedIndex;
      final baseAlpha = isSelected ? 0.35 : 0.12;

      if (light is DirectionalLight) {
        _paintDirectionalRays(canvas, size, light, baseAlpha);
      } else if (light is PointLight) {
        _paintPointRays(canvas, size, light, baseAlpha);
      } else if (light is SpotLight) {
        _paintSpotRays(canvas, size, light, baseAlpha);
      } else if (light is AreaLight) {
        _paintAreaRays(canvas, size, light, baseAlpha);
      }
    }
  }

  void _paintDirectionalRays(
      Canvas canvas, Size size, DirectionalLight light, double alpha) {
    // Parallel rays across the screen, pointing in the light direction.
    final dir = Offset(math.sin(light.angle), -math.cos(light.angle));
    // Perpendicular to direction for spacing rays across the screen.
    final perp = Offset(-dir.dy, dir.dx);

    final color = light.color == Colors.white
        ? Colors.amber.withValues(alpha: alpha)
        : light.color.withValues(alpha: alpha);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final center = Offset(size.width / 2, size.height / 2);
    const spacing = 40.0;
    final count = (diagonal / spacing).ceil();

    for (var j = -count; j <= count; j++) {
      final origin = center + perp * (j * spacing);
      // Ray goes from far behind the light direction to far past
      final start = origin + dir * (diagonal / 2);
      final end = origin - dir * (diagonal / 2);

      // Draw arrow along ray
      canvas.drawLine(start, end, paint);

      // Small arrowhead near center of ray
      final arrowTip = origin - dir * 20;
      final arrowLeft = arrowTip + dir * 8 + perp * 3;
      final arrowRight = arrowTip + dir * 8 - perp * 3;
      canvas.drawLine(arrowTip, arrowLeft, paint);
      canvas.drawLine(arrowTip, arrowRight, paint);
    }
  }

  void _paintPointRays(
      Canvas canvas, Size size, PointLight light, double alpha) {
    final color = light.color == Colors.white
        ? Colors.orange.withValues(alpha: alpha)
        : light.color.withValues(alpha: alpha);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const rayCount = 24;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    for (var j = 0; j < rayCount; j++) {
      final angle = j * 2 * math.pi / rayCount;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final end = light.position + dir * diagonal;
      canvas.drawLine(light.position, end, paint);
    }

    // Intensity falloff ring — radius where intensity drops to ~50%
    final ringRadius = light.height * 0.8;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(light.position, ringRadius, ringPaint);
  }

  void _paintSpotRays(
      Canvas canvas, Size size, SpotLight light, double alpha) {
    final color = light.color == Colors.white
        ? Colors.blue.withValues(alpha: alpha)
        : light.color.withValues(alpha: alpha);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final dirLen = light.direction.distance;
    if (dirLen == 0) return;
    final dirNorm = light.direction / dirLen;
    final baseAngle = math.atan2(dirNorm.dy, dirNorm.dx);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    // Rays within cone
    const raysPerSide = 8;
    final totalRays = raysPerSide * 2 + 1;
    for (var j = 0; j < totalRays; j++) {
      final fraction = (j / (totalRays - 1)) * 2 - 1; // -1 to 1
      final rayAngle = baseAngle + fraction * light.coneAngle;
      final dir = Offset(math.cos(rayAngle), math.sin(rayAngle));
      final end = light.position + dir * diagonal;
      canvas.drawLine(light.position, end, paint);
    }

    // Cone edge lines (thicker)
    final edgePaint = Paint()
      ..color = color.withValues(alpha: alpha * 1.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final leftAngle = baseAngle - light.coneAngle;
    final rightAngle = baseAngle + light.coneAngle;
    canvas.drawLine(
      light.position,
      light.position + Offset(math.cos(leftAngle), math.sin(leftAngle)) * diagonal,
      edgePaint,
    );
    canvas.drawLine(
      light.position,
      light.position + Offset(math.cos(rightAngle), math.sin(rightAngle)) * diagonal,
      edgePaint,
    );

    // Cone arc at a fixed distance
    const arcDist = 80.0;
    final arcPaint = Paint()
      ..color = color.withValues(alpha: alpha * 1.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final arcRect = Rect.fromCircle(center: light.position, radius: arcDist);
    canvas.drawArc(
      arcRect,
      leftAngle,
      light.coneAngle * 2,
      false,
      arcPaint,
    );
  }

  void _paintAreaRays(
      Canvas canvas, Size size, AreaLight light, double alpha) {
    final color = light.color == Colors.white
        ? Colors.green.withValues(alpha: alpha)
        : light.color.withValues(alpha: alpha);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    // Draw the area rectangle
    final areaRect = Rect.fromCenter(
      center: light.position,
      width: light.size.width,
      height: light.size.height,
    );
    final rectPaint = Paint()
      ..color = color.withValues(alpha: alpha * 1.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(areaRect, rectPaint);

    // Rays from evenly spaced points along the rectangle edges
    const pointsPerEdge = 4;
    final edgePoints = <Offset>[];
    for (var j = 0; j <= pointsPerEdge; j++) {
      final t = j / pointsPerEdge;
      // Top edge
      edgePoints.add(Offset(
        areaRect.left + t * areaRect.width,
        areaRect.top,
      ));
      // Bottom edge
      edgePoints.add(Offset(
        areaRect.left + t * areaRect.width,
        areaRect.bottom,
      ));
      // Left edge (skip corners)
      if (j > 0 && j < pointsPerEdge) {
        edgePoints.add(Offset(
          areaRect.left,
          areaRect.top + t * areaRect.height,
        ));
        // Right edge
        edgePoints.add(Offset(
          areaRect.right,
          areaRect.top + t * areaRect.height,
        ));
      }
    }

    const raysPerPoint = 6;
    for (final pt in edgePoints) {
      for (var r = 0; r < raysPerPoint; r++) {
        final angle = r * 2 * math.pi / raysPerPoint;
        final dir = Offset(math.cos(angle), math.sin(angle));
        final end = pt + dir * diagonal * 0.3;
        canvas.drawLine(pt, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LightRaysPainter oldDelegate) =>
      lights != oldDelegate.lights ||
      selectedIndex != oldDelegate.selectedIndex;
}

// ── Material editor ──────────────────────────────────────────────────────────

class _MaterialSelector extends StatelessWidget {
  final Map<String, SurfaceMaterial> presetOverrides;
  final String selectedKey;
  final ValueChanged<String> onSelectPreset;
  final ValueChanged<SurfaceMaterial> onUpdatePreset;
  final ValueChanged<String> onResetPreset;

  const _MaterialSelector({
    required this.presetOverrides,
    required this.selectedKey,
    required this.onSelectPreset,
    required this.onUpdatePreset,
    required this.onResetPreset,
  });

  SurfaceMaterial get _current =>
      presetOverrides[selectedKey] ?? SurfaceMaterial.matte;

  bool get _isModified {
    final original = LitMaterialTheme.presetDefaults[selectedKey];
    return original != null && _current != original;
  }

  SurfaceMaterial _copyWith({
    double? roughness,
    double? metallic,
    double? fresnel,
    double? sheen,
    double? clearcoat,
    double? translucency,
  }) {
    return SurfaceMaterial(
      roughness: roughness ?? _current.roughness,
      metallic: metallic ?? _current.metallic,
      fresnel: fresnel ?? _current.fresnel,
      sheen: sheen ?? _current.sheen,
      clearcoat: clearcoat ?? _current.clearcoat,
      translucency: translucency ?? _current.translucency,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset tabs
        Row(
          children: [
            const Text(
              'Material',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            if (_isModified)
              GestureDetector(
                onTap: () => onResetPreset(selectedKey),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.refresh, size: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: LitMaterialTheme.presetKeys.map((key) {
            final isSelected = key == selectedKey;
            final label = LitMaterialTheme.presetLabels[key] ?? key;
            final isOverridden = presetOverrides[key] !=
                LitMaterialTheme.presetDefaults[key];
            return GestureDetector(
              onTap: () => onSelectPreset(key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber.withValues(alpha: 0.2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.amber
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.amber.shade800
                            : Colors.black54,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (isOverridden) ...[
                      const SizedBox(width: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // Parameter sliders for the selected preset
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Roughness',
          value: _current.roughness,
          min: 0.0,
          max: 1.0,
          trailing: _current.roughness.toStringAsFixed(2),
          onChanged: (v) => onUpdatePreset(_copyWith(roughness: v)),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Metallic',
          value: _current.metallic,
          min: 0.0,
          max: 1.0,
          trailing: _current.metallic.toStringAsFixed(2),
          onChanged: (v) => onUpdatePreset(_copyWith(metallic: v)),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Fresnel',
          value: _current.fresnel,
          min: 0.0,
          max: 1.0,
          trailing: _current.fresnel.toStringAsFixed(2),
          onChanged: (v) => onUpdatePreset(_copyWith(fresnel: v)),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Sheen',
          value: _current.sheen,
          min: 0.0,
          max: 1.0,
          trailing: _current.sheen.toStringAsFixed(2),
          onChanged: (v) => onUpdatePreset(_copyWith(sheen: v)),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Clearcoat',
          value: _current.clearcoat,
          min: 0.0,
          max: 1.0,
          trailing: _current.clearcoat.toStringAsFixed(2),
          onChanged: (v) => onUpdatePreset(_copyWith(clearcoat: v)),
        ),
      ],
    );
  }
}

// ── Widget list ──────────────────────────────────────────────────────────────

class _WidgetList extends StatelessWidget {
  final List<LitWidgetEntry> entries;
  final String selectedPresetKey;

  const _WidgetList({
    required this.entries,
    required this.selectedPresetKey,
  });

  static const _presetColors = {
    'metal': Colors.blueGrey,
    'matte': Colors.brown,
    'fuzzy': Colors.purple,
    'glossy': Colors.teal,
    'lacquered': Colors.deepOrange,
    'custom': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    // Group by preset
    final grouped = <String, List<LitWidgetEntry>>{};
    for (final e in entries) {
      final key = e.presetKey ?? 'none';
      (grouped[key] ??= []).add(e);
    }

    final selectedEntries = grouped[selectedPresetKey] ?? [];
    final otherKeys = grouped.keys
        .where((k) => k != selectedPresetKey && k != 'none')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected preset widgets
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _presetColors[selectedPresetKey] ?? Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${selectedEntries.length} widget${selectedEntries.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        if (selectedEntries.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: selectedEntries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (_presetColors[selectedPresetKey] ?? Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                e.widgetType,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: _presetColors[selectedPresetKey] ?? Colors.grey,
                  decoration: TextDecoration.none,
                  fontFamily: 'monospace',
                ),
              ),
            )).toList(),
          ),
        ],
        // Summary of other presets
        if (otherKeys.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: otherKeys.map((key) {
              final count = grouped[key]!.length;
              final label = LitMaterialTheme.presetLabels[key] ?? key;
              return Text(
                '$label: $count',
                style: TextStyle(
                  fontSize: 8,
                  color: _presetColors[key] ?? Colors.grey,
                  decoration: TextDecoration.none,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Profile editor ───────────────────────────────────────────────────────────

class _ProfileEditor extends StatelessWidget {
  final SurfaceProfile profile;
  final ValueChanged<SurfaceProfile> onChanged;

  const _ProfileEditor({required this.profile, required this.onChanged});

  static const _patterns = [
    (SurfacePattern.flat, 'Flat'),
    (SurfacePattern.grooves, 'Grooves'),
    (SurfacePattern.dimples, 'Dimples'),
    (SurfacePattern.noise, 'Noise'),
  ];

  @override
  Widget build(BuildContext context) {
    final isFlat = profile.pattern == SurfacePattern.flat;
    final isGrooves = profile.pattern == SurfacePattern.grooves;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _patterns.map((entry) {
            final (pattern, label) = entry;
            final isSelected = pattern == profile.pattern;
            return GestureDetector(
              onTap: () {
                if (pattern == SurfacePattern.flat) {
                  onChanged(SurfaceProfile.flat);
                } else {
                  onChanged(SurfaceProfile(
                    pattern: pattern,
                    frequency: profile.frequency,
                    amplitude: profile.amplitude,
                    angle: profile.angle,
                  ));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.amber.shade800 : Colors.black54,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (!isFlat) ...[
          const SizedBox(height: 6),
          _SliderRow(
            label: 'Frequency',
            value: profile.frequency,
            min: 1.0,
            max: 50.0,
            trailing: profile.frequency.toStringAsFixed(1),
            onChanged: (v) => onChanged(SurfaceProfile(
              pattern: profile.pattern,
              frequency: v,
              amplitude: profile.amplitude,
              angle: profile.angle,
            )),
          ),
          const SizedBox(height: 6),
          _SliderRow(
            label: 'Amplitude',
            value: profile.amplitude,
            min: 0.0,
            max: 1.0,
            trailing: profile.amplitude.toStringAsFixed(2),
            onChanged: (v) => onChanged(SurfaceProfile(
              pattern: profile.pattern,
              frequency: profile.frequency,
              amplitude: v,
              angle: profile.angle,
            )),
          ),
          if (isGrooves) ...[
            const SizedBox(height: 6),
            _SliderRow(
              label: 'Angle',
              value: profile.angle,
              min: 0.0,
              max: 6.28,
              trailing: '${(profile.angle * 180 / math.pi).round()}°',
              onChanged: (v) => onChanged(SurfaceProfile(
                pattern: profile.pattern,
                frequency: profile.frequency,
                amplitude: profile.amplitude,
                angle: v,
              )),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Border editor ────────────────────────────────────────────────────────────

class _BorderEditor extends StatelessWidget {
  final LightDebugController controller;

  const _BorderEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Border Shadow Bands',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'Outer Intensity',
          value: controller.outerShadowIntensity,
          min: 0.0,
          max: 1.0,
          trailing: controller.outerShadowIntensity.toStringAsFixed(2),
          onChanged: controller.setOuterShadowIntensity,
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Outer Width',
          value: controller.outerShadowWidth,
          min: 0.0,
          max: 1.0,
          trailing: controller.outerShadowWidth.toStringAsFixed(2),
          onChanged: controller.setOuterShadowWidth,
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Inner Intensity',
          value: controller.innerShadowIntensity,
          min: 0.0,
          max: 1.0,
          trailing: controller.innerShadowIntensity.toStringAsFixed(2),
          onChanged: controller.setInnerShadowIntensity,
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Inner Width',
          value: controller.innerShadowWidth,
          min: 0.0,
          max: 1.0,
          trailing: controller.innerShadowWidth.toStringAsFixed(2),
          onChanged: controller.setInnerShadowWidth,
        ),
      ],
    );
  }
}

// ── Blend mode selector ──────────────────────────────────────────────────────

class _BlendModeSelector extends StatelessWidget {
  final BlendMode selected;
  final ValueChanged<BlendMode> onChanged;

  const _BlendModeSelector({required this.selected, required this.onChanged});

  static const _modes = [
    (BlendMode.srcOver, 'Normal'),
    (BlendMode.softLight, 'Soft'),
    (BlendMode.screen, 'Screen'),
    (BlendMode.overlay, 'Overlay'),
    (BlendMode.multiply, 'Multi'),
    (BlendMode.colorDodge, 'Dodge'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blend',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _modes.map((entry) {
            final (mode, label) = entry;
            final isSelected = mode == selected;
            return GestureDetector(
              onTap: () => onChanged(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.amber.shade800 : Colors.black54,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
