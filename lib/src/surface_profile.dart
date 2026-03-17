/// Describes the procedural heightmap pattern applied to a surface.
///
/// A [SurfaceProfile] combines a [SurfacePattern] with parameters that control
/// the frequency, depth, and orientation of the texture. Per-pixel lighting
/// uses the heightmap normal to modulate the final colour.
///
/// Three convenience constructors cover common cases:
/// - [SurfaceProfile.flat] — perfectly smooth, no texture
/// - [SurfaceProfile.grooves] — parallel sinusoidal ridges
/// - [SurfaceProfile.dimples] — 2-D sine grid (egg-crate)
/// - [SurfaceProfile.noise] — hash-based pseudo-random bumps
enum SurfacePattern {
  /// Perfectly smooth — no heightmap displacement.
  flat,

  /// Parallel sinusoidal ridges running perpendicular to [SurfaceProfile.angle].
  grooves,

  /// 2-D sine grid producing a regular dimple / egg-crate pattern.
  dimples,

  /// Hash-based pseudo-random bumps with no repeating structure.
  noise,
}

/// Defines the procedural heightmap applied to a lit surface.
///
/// Widgets that support surface texturing accept a [SurfaceProfile] and use
/// its parameters to generate a per-pixel normal map at render time.
///
/// All instances are const-constructible and value-comparable.
class SurfaceProfile {
  const SurfaceProfile({
    required this.pattern,
    this.frequency = 12.0,
    this.amplitude = 0.4,
    this.angle = 0.0,
  });

  /// The procedural pattern used to generate the heightmap.
  final SurfacePattern pattern;

  /// Number of texture cycles per 100 logical pixels.
  ///
  /// Higher values produce finer / more tightly packed features.
  final double frequency;

  /// Depth of the surface displacement, normalised to [0, 1].
  ///
  /// `0.0` produces no bump effect; `1.0` is the maximum displacement.
  final double amplitude;

  /// Rotation of the texture pattern in radians (clockwise from top).
  ///
  /// For [SurfacePattern.grooves] this rotates the ridge direction.
  /// Ignored for [SurfacePattern.dimples] and [SurfacePattern.noise]
  /// (always `0.0`).
  final double angle;

  // ── Static const presets ─────────────────────────────────────────────────

  /// Perfectly flat surface — no texture, zero amplitude.
  static const flat = SurfaceProfile(
    pattern: SurfacePattern.flat,
    amplitude: 0.0,
  );

  // ── Named constructors ───────────────────────────────────────────────────

  /// Parallel sinusoidal ridges.
  ///
  /// [frequency] controls ridge density (cycles per 100 px, default 12).
  /// [amplitude] controls ridge depth 0–1 (default 0.4).
  /// [angle] rotates the ridge direction in radians (default 0).
  const SurfaceProfile.grooves({
    double frequency = 12.0,
    double amplitude = 0.4,
    double angle = 0.0,
  }) : this(
          pattern: SurfacePattern.grooves,
          frequency: frequency,
          amplitude: amplitude,
          angle: angle,
        );

  /// 2-D sine grid producing a regular dimple / egg-crate pattern.
  ///
  /// [frequency] controls grid density (cycles per 100 px, default 10).
  /// [amplitude] controls dimple depth 0–1 (default 0.3).
  const SurfaceProfile.dimples({
    double frequency = 10.0,
    double amplitude = 0.3,
  }) : this(
          pattern: SurfacePattern.dimples,
          frequency: frequency,
          amplitude: amplitude,
        );

  /// Hash-based pseudo-random bumps with no repeating structure.
  ///
  /// [frequency] controls bump density (cycles per 100 px, default 8).
  /// [amplitude] controls bump height 0–1 (default 0.5).
  const SurfaceProfile.noise({
    double frequency = 8.0,
    double amplitude = 0.5,
  }) : this(
          pattern: SurfacePattern.noise,
          frequency: frequency,
          amplitude: amplitude,
        );

  // ── Object overrides ─────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceProfile &&
          pattern == other.pattern &&
          frequency == other.frequency &&
          amplitude == other.amplitude &&
          angle == other.angle;

  @override
  int get hashCode => Object.hash(pattern, frequency, amplitude, angle);

  @override
  String toString() =>
      'SurfaceProfile(pattern: $pattern, frequency: $frequency, '
      'amplitude: $amplitude, angle: $angle)';
}
