import 'package:flutter/material.dart';
import '../surface_material.dart';
import '../material_theme.dart';

/// Tracks which lit widgets are on screen and what material they resolved to.
///
/// Widgets call [register] during build. The debug overlay reads [entries]
/// to show a widget list with material assignments.
class LitWidgetInspector {
  LitWidgetInspector._();

  static final _entries = <int, LitWidgetEntry>{};
  static bool enabled = false;

  /// Register a widget during build. Call from lit widget build() methods.
  static void register({
    required int widgetHashCode,
    required String widgetType,
    required SurfaceMaterial? material,
    required Rect? bounds,
  }) {
    if (!enabled) return;
    final presetKey = _presetKeyFor(material);
    _entries[widgetHashCode] = LitWidgetEntry(
      widgetType: widgetType,
      presetKey: presetKey,
      material: material,
      bounds: bounds,
    );
  }

  /// Remove a widget from the registry (call from dispose).
  static void unregister(int widgetHashCode) {
    _entries.remove(widgetHashCode);
  }

  /// All registered widget entries.
  static List<LitWidgetEntry> get entries => _entries.values.toList();

  /// Count of widgets per preset key.
  static Map<String, int> get countsByPreset {
    final counts = <String, int>{};
    for (final e in _entries.values) {
      final key = e.presetKey ?? 'none';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Clear all entries (called at start of each frame in inspect mode).
  static void clear() => _entries.clear();

  static String? _presetKeyFor(SurfaceMaterial? material) {
    if (material == null) return null;
    for (final entry in LitMaterialTheme.presetDefaults.entries) {
      if (identical(material, entry.value)) return entry.key;
    }
    return 'custom';
  }
}

class LitWidgetEntry {
  const LitWidgetEntry({
    required this.widgetType,
    required this.presetKey,
    required this.material,
    required this.bounds,
  });

  final String widgetType;
  final String? presetKey; // null = no material, 'custom' = non-preset
  final SurfaceMaterial? material;
  final Rect? bounds;
}
