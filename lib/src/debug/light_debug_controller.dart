import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import '../light_types.dart';
import '../light_scene.dart';
import '../material_theme.dart';
import '../surface_material.dart';
import '../surface_profile.dart';

class LightDebugController extends ChangeNotifier {
  LightDebugController({LightScene? defaultScene})
    : _lights = defaultScene?.lights.toList() ??
          [DirectionalLight(angle: 354 * math.pi / 180, intensity: 0.65, blendMode: BlendMode.overlay)],
      _defaultScene = defaultScene ??
          LightScene(lights: [
            DirectionalLight(angle: 354 * math.pi / 180, intensity: 0.65, blendMode: BlendMode.overlay),
          ]);

  final LightScene _defaultScene;

  bool _isExpanded = false;
  bool get isExpanded => _isExpanded;

  // ── Debug tab ──
  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  void setTab(int i) { _tabIndex = i; notifyListeners(); }

  // ── Per-preset material overrides ──
  final Map<String, SurfaceMaterial> _presetOverrides = {
    for (final e in LitMaterialTheme.presetDefaults.entries) e.key: e.value,
  };
  Map<String, SurfaceMaterial> get presetOverrides =>
      Map.unmodifiable(_presetOverrides);

  String _selectedPresetKey = 'matte';
  String get selectedPresetKey => _selectedPresetKey;

  SurfaceMaterial get selectedPresetMaterial =>
      _presetOverrides[_selectedPresetKey] ?? SurfaceMaterial.matte;

  void selectPreset(String key) {
    _selectedPresetKey = key;
    notifyListeners();
  }

  void updateSelectedPreset(SurfaceMaterial m) {
    _presetOverrides[_selectedPresetKey] = m;
    notifyListeners();
  }

  void resetPreset(String key) {
    final def = LitMaterialTheme.presetDefaults[key];
    if (def != null) {
      _presetOverrides[key] = def;
      notifyListeners();
    }
  }

  // ── Border shadow bands ──
  double _outerShadowIntensity = 0.33;
  double get outerShadowIntensity => _outerShadowIntensity;
  void setOuterShadowIntensity(double v) {
    _outerShadowIntensity = v;
    notifyListeners();
  }

  double _outerShadowWidth = 0.96;
  double get outerShadowWidth => _outerShadowWidth;
  void setOuterShadowWidth(double v) {
    _outerShadowWidth = v;
    notifyListeners();
  }

  double _innerShadowIntensity = 0.54;
  double get innerShadowIntensity => _innerShadowIntensity;
  void setInnerShadowIntensity(double v) {
    _innerShadowIntensity = v;
    notifyListeners();
  }

  double _innerShadowWidth = 0.0;
  double get innerShadowWidth => _innerShadowWidth;
  void setInnerShadowWidth(double v) {
    _innerShadowWidth = v;
    notifyListeners();
  }

  // ── Profile ──
  SurfaceProfile _profile = SurfaceProfile.flat;
  SurfaceProfile get profile => _profile;

  void setProfile(SurfaceProfile p) {
    _profile = p;
    notifyListeners();
  }

  bool _showRays = false;
  bool get showRays => _showRays;

  void toggleRays() {
    _showRays = !_showRays;
    notifyListeners();
  }

  /// When non-null, this light index follows the cursor position.
  int? _cursorFollowIndex;
  int? get cursorFollowIndex => _cursorFollowIndex;

  void toggleCursorFollow(int index) {
    if (_cursorFollowIndex == index) {
      _cursorFollowIndex = null;
    } else {
      _cursorFollowIndex = index;
    }
    notifyListeners();
  }

  /// Called on every cursor move. Updates the followed light's position.
  void onCursorMove(Offset position) {
    final idx = _cursorFollowIndex;
    if (idx == null || idx >= _lights.length) return;
    final light = _lights[idx];
    // Only positional lights can follow cursor.
    SceneLight? updated;
    if (light is PointLight) {
      updated = PointLight(
        position: position, height: light.height,
        intensity: light.intensity, falloff: light.falloff,
        color: light.color, blendMode: light.blendMode,
      );
    } else if (light is SpotLight) {
      updated = SpotLight(
        position: position, height: light.height,
        direction: light.direction, coneAngle: light.coneAngle,
        softEdge: light.softEdge, falloff: light.falloff,
        intensity: light.intensity, color: light.color,
        blendMode: light.blendMode,
      );
    } else if (light is AreaLight) {
      updated = AreaLight(
        position: position, height: light.height,
        size: light.size, intensity: light.intensity,
        color: light.color, blendMode: light.blendMode,
      );
    }
    if (updated != null) {
      _lights[idx] = updated;
      notifyListeners();
    }
  }

  final List<SceneLight> _lights;
  int _selectedIndex = 0;

  List<SceneLight> get lights => List.unmodifiable(_lights);
  int get selectedIndex => _selectedIndex;
  SceneLight? get selectedLight =>
      _selectedIndex < _lights.length ? _lights[_selectedIndex] : null;

  LightScene get scene => LightScene(lights: List.of(_lights));

  void toggle() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  void selectLight(int index) {
    if (index < 0 || index >= _lights.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void updateLight(int index, SceneLight light) {
    if (index < 0 || index >= _lights.length) return;
    _lights[index] = light;
    notifyListeners();
  }

  void addLight(SceneLight light) {
    _lights.add(light);
    _selectedIndex = _lights.length - 1;
    notifyListeners();
  }

  void removeLight(int index) {
    if (index < 0 || index >= _lights.length || _lights.length <= 1) return;
    _lights.removeAt(index);
    if (_selectedIndex >= _lights.length) {
      _selectedIndex = _lights.length - 1;
    }
    notifyListeners();
  }

  void reset() {
    _lights
      ..clear()
      ..addAll(_defaultScene.lights.toList());
    _selectedIndex = 0;
    notifyListeners();
  }

  String lightTypeLabel(SceneLight light) {
    if (light is DirectionalLight) return 'Directional';
    if (light is PointLight) return 'Point';
    if (light is SpotLight) return 'Spot';
    if (light is AreaLight) return 'Area';
    return 'Unknown';
  }
}
