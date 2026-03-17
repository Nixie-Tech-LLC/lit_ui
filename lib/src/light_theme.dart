import 'package:flutter/widgets.dart';

import 'light_scene.dart';

/// Provides a [LightScene] to the widget subtree.
///
/// Wrap your app or a subtree with [LightTheme] to define a set of light
/// sources. Descendant widgets can access the scene via [LightTheme.of(context)]
/// or [LightTheme.maybeOf(context)].
///
/// ```dart
/// LightTheme(
///   scene: LightScene.directional(angle: -0.4, intensity: 0.6),
///   child: MyApp(),
/// )
/// ```
class LightTheme extends InheritedWidget {
  const LightTheme({
    super.key,
    required this.scene,
    required super.child,
  });

  final LightScene scene;

  /// Returns the nearest [LightScene] above [context], or throws.
  static LightScene of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<LightTheme>();
    assert(theme != null, 'No LightTheme found in context');
    return theme!.scene;
  }

  /// Returns the nearest [LightScene] above [context], or null.
  static LightScene? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LightTheme>()?.scene;
  }

  @override
  bool updateShouldNotify(LightTheme oldWidget) => scene != oldWidget.scene;
}
