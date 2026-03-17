import 'package:flutter/widgets.dart';

/// Provides optional shadow band overrides to descendant [LitInputBorder] widgets.
///
/// When present in the widget tree, [LitInputBorder] uses these values instead
/// of its own widget parameters. Null fields mean "use widget default."
///
/// Used by the debug overlay to allow real-time tweaking of shadow band values.
class LitBorderTheme extends InheritedWidget {
  const LitBorderTheme({
    super.key,
    required super.child,
    this.outerShadowIntensity,
    this.outerShadowWidth,
    this.innerShadowIntensity,
    this.innerShadowWidth,
  });

  final double? outerShadowIntensity;
  final double? outerShadowWidth;
  final double? innerShadowIntensity;
  final double? innerShadowWidth;

  /// Returns the nearest [LitBorderTheme] data, or null if none exists.
  static LitBorderTheme? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LitBorderTheme>();
  }

  @override
  bool updateShouldNotify(LitBorderTheme oldWidget) =>
      outerShadowIntensity != oldWidget.outerShadowIntensity ||
      outerShadowWidth != oldWidget.outerShadowWidth ||
      innerShadowIntensity != oldWidget.innerShadowIntensity ||
      innerShadowWidth != oldWidget.innerShadowWidth;
}
