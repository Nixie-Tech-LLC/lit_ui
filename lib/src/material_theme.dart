import 'package:flutter/widgets.dart';

import 'surface_material.dart';
import 'surface_profile.dart';

/// Provides material preset overrides and a default profile to the widget subtree.
///
/// Widgets call [resolveOf] to resolve their material through the theme.
/// If the widget's material is a known preset (checked via [identical]),
/// the theme returns the overridden version. This lets the debug tool
/// edit Metal's roughness and have only Metal widgets update.
///
/// ```dart
/// LitMaterialTheme(
///   presetOverrides: { 'metal': tweakedMetal, 'matte': tweakedMatte, ... },
///   profile: SurfaceProfile.flat,
///   child: MyApp(),
/// )
/// ```
class LitMaterialTheme extends InheritedWidget {
  const LitMaterialTheme({
    super.key,
    required this.presetOverrides,
    required this.profile,
    this.defaultMaterial,
    required super.child,
  });

  /// Current values for each named preset. Keys match [presetKeys].
  final Map<String, SurfaceMaterial> presetOverrides;

  final SurfaceProfile profile;

  /// The material applied to widgets that don't specify their own.
  /// When null, widgets without a material use the Canvas fallback.
  /// The debug overlay sets this to the currently selected preset.
  final SurfaceMaterial? defaultMaterial;

  /// Canonical preset keys, in display order.
  static const presetKeys = ['metal', 'matte', 'fuzzy', 'glossy', 'lacquered', 'glass', 'frostedGlass'];

  /// The original static const for each key. Used for [identical] matching.
  static const Map<String, SurfaceMaterial> presetDefaults = {
    'metal': SurfaceMaterial.polishedMetal,
    'matte': SurfaceMaterial.matte,
    'fuzzy': SurfaceMaterial.fuzzy,
    'glossy': SurfaceMaterial.glossy,
    'lacquered': SurfaceMaterial.lacquered,
    'glass': SurfaceMaterial.glass,
    'frostedGlass': SurfaceMaterial.frostedGlass,
  };

  /// Display labels for each preset key.
  static const Map<String, String> presetLabels = {
    'metal': 'Metal',
    'matte': 'Matte',
    'fuzzy': 'Fuzzy',
    'glossy': 'Glossy',
    'lacquered': 'Lacquer',
    'glass': 'Glass',
    'frostedGlass': 'Frosted',
  };

  /// Resolve a widget's material through the theme.
  ///
  /// If [material] is [identical] to a known preset constant, returns
  /// the overridden version from [presetOverrides]. Otherwise returns
  /// [material] unchanged (custom materials are not overridden).
  ///
  /// If [material] is null, returns [defaultMaterial] (which may also be null).
  SurfaceMaterial? resolve(SurfaceMaterial? material) {
    if (material == null) return defaultMaterial;
    for (final entry in presetDefaults.entries) {
      if (identical(material, entry.value)) {
        return presetOverrides[entry.key] ?? material;
      }
    }
    return material;
  }

  /// Convenience: resolve a material from the nearest theme in [context].
  static SurfaceMaterial? resolveOf(BuildContext context, SurfaceMaterial? material) {
    final theme = context.dependOnInheritedWidgetOfExactType<LitMaterialTheme>();
    if (theme == null) return material;
    return theme.resolve(material);
  }

  /// Returns the profile from the nearest [LitMaterialTheme], or null.
  static SurfaceProfile? profileOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LitMaterialTheme>()?.profile;
  }

  @override
  bool updateShouldNotify(LitMaterialTheme oldWidget) =>
      profile != oldWidget.profile ||
      defaultMaterial != oldWidget.defaultMaterial ||
      !_mapsEqual(presetOverrides, oldWidget.presetOverrides);

  static bool _mapsEqual(Map<String, SurfaceMaterial> a, Map<String, SurfaceMaterial> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
