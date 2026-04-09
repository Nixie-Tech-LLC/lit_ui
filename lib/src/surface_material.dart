/// Describes how a surface responds to light using PBR-inspired properties.
///
/// A [SurfaceMaterial] bundles the physical properties that control how
/// highlights, shadows, and gradients appear on lit widgets.
///
/// Five built-in presets cover common cases:
/// - [SurfaceMaterial.polishedMetal] — sharp, bright highlights with tight
///   falloff and strong fresnel edge glow
/// - [SurfaceMaterial.matte] — soft, even light spread with gentle gradients
/// - [SurfaceMaterial.fuzzy] — scattered light, velvet-like sheen, very soft
/// - [SurfaceMaterial.glossy] — smooth dielectric with strong fresnel, no metal
/// - [SurfaceMaterial.lacquered] — rough base with a glossy clearcoat on top
///
/// All values are normalised to 0–1 ranges. Widgets interpret them as
/// multipliers on their lighting calculations.
class SurfaceMaterial {
  const SurfaceMaterial({
    required this.roughness,
    required this.metallic,
    required this.fresnel,
    required this.sheen,
    required this.clearcoat,
    this.translucency = 0.0,
  });

  /// How rough the surface is (0 = mirror-smooth, 1 = fully diffuse).
  ///
  /// Affects fill gradient spread: low roughness → tight highlight hotspot,
  /// high roughness → broad, even illumination.
  final double roughness;

  /// How metallic the surface is (0 = dielectric, 1 = metal).
  ///
  /// Metals tint their highlights with the base color and have a higher
  /// overall reflectivity response.
  final double metallic;

  /// Fresnel edge brightness (0 = none, 1 = strong edge brightness).
  ///
  /// Simulates the Fresnel effect where surfaces become more reflective at
  /// grazing angles.
  final double fresnel;

  /// Velvet / fabric sheen (0 = none, 1 = strong velvet glow).
  ///
  /// Scatters light at grazing angles, characteristic of cloth and felt.
  final double sheen;

  /// Clearcoat layer (0 = none, 1 = full glossy topcoat).
  ///
  /// Adds a smooth, glossy coat on top of the base material (e.g. car paint).
  final double clearcoat;

  /// Surface translucency (0 = fully opaque, 1 = fully transparent).
  ///
  /// Translucent surfaces let light pass through while still showing
  /// specular highlights and fresnel effects at full opacity.
  final double translucency;

  // ── Presets ──────────────────────────────────────────────────────────────

  /// Polished metal — bright, tight highlights, crisp shadows, strong fresnel.
  static const polishedMetal = SurfaceMaterial(
    roughness: 0.15,
    metallic: 0.95,
    fresnel: 0.8,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  /// Standard matte surface — even light, gentle gradients, medium shadows.
  static const matte = SurfaceMaterial(
    roughness: 0.7,
    metallic: 0.0,
    fresnel: 0.1,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  /// Felt / fabric — light scatters broadly, velvet sheen, soft shadows.
  static const fuzzy = SurfaceMaterial(
    roughness: 0.85,
    metallic: 0.0,
    fresnel: 0.05,
    sheen: 0.7,
    clearcoat: 0.0,
  );

  /// Glossy dielectric — smooth, subtle fresnel, clearcoat sheen.
  static const glossy = SurfaceMaterial(
    roughness: 0.91,
    metallic: 0.0,
    fresnel: 0.17,
    sheen: 0.0,
    clearcoat: 0.0,
  );

  /// Lacquered — rough matte base with a full glossy clearcoat on top.
  static const lacquered = SurfaceMaterial(
    roughness: 0.6,
    metallic: 0.0,
    fresnel: 0.3,
    sheen: 0.0,
    clearcoat: 0.9,
  );

  /// Clear glass — highly transparent, strong fresnel at edges, sharp specular.
  static const glass = SurfaceMaterial(
    roughness: 0.05,
    metallic: 0.0,
    fresnel: 0.9,
    sheen: 0.0,
    clearcoat: 0.0,
    translucency: 0.75,
  );

  /// Frosted glass — translucent with diffused light, softer highlights.
  static const frostedGlass = SurfaceMaterial(
    roughness: 0.4,
    metallic: 0.0,
    fresnel: 0.7,
    sheen: 0.0,
    clearcoat: 0.0,
    translucency: 0.5,
  );

  // ── Derived values for widgets ──────────────────────────────────────────

  /// Fill gradient contrast multiplier.
  ///
  /// All materials show diffuse gradients. Roughness softens them,
  /// metallic boosts them slightly. Range: ~0.3 (fuzzy) to ~1.0 (polished metal).
  double get fillContrast => (0.6 + metallic * 0.4) * (1.0 - roughness * 0.5);

  /// Border highlight contrast multiplier (clamped to [0, 1]).
  ///
  /// Smooth surfaces get bright, concentrated edge highlights.
  /// Rough surfaces still show borders, just broader and dimmer.
  double get borderContrast =>
      ((0.5 + metallic * 0.5) * (0.5 + (1.0 - roughness) * 0.5))
          .clamp(0.0, 1.0);

  /// Whether the material tints highlights with the base color (0–1).
  ///
  /// Equals [metallic]: pure metals fully tint their specular highlights.
  double get highlightTint => metallic;

  /// Effective fresnel after roughness attenuation (clamped to [0, 1]).
  ///
  /// Rough surfaces wash out the fresnel edge effect.
  double get effectiveFresnel =>
      (fresnel * (1.0 - roughness * 0.8)).clamp(0.0, 1.0);

  /// Effective sheen (clamped to [0, 1]).
  double get effectiveSheen => sheen.clamp(0.0, 1.0);

  /// Maximum border lighten amount (0–1 lightness offset).
  ///
  /// Low roughness → wider bright peak.
  double get maxBorderLighten => 0.3 + (1.0 - roughness) * 0.4;

  /// Maximum border darken amount (0–1 lightness offset, positive value).
  ///
  /// Matte/fuzzy surfaces don't darken shadow edges as much because
  /// scattered light fills in the shadow side.
  double get maxBorderDarken => 0.05 + (1.0 - roughness) * 0.15;

  /// Shadow blur sigma. Smooth materials → tight sigma, rough → broad.
  double get shadowBlurSigma => 0.5 + roughness * 3.0;

  /// Inset shadow opacity multiplier (clamped to [0, 1]).
  double get insetShadowIntensity =>
      (0.15 + (1.0 - roughness) * 0.2).clamp(0.0, 1.0);

  SurfaceMaterial copyWith({
    double? roughness,
    double? metallic,
    double? fresnel,
    double? sheen,
    double? clearcoat,
    double? translucency,
  }) =>
      SurfaceMaterial(
        roughness: roughness ?? this.roughness,
        metallic: metallic ?? this.metallic,
        fresnel: fresnel ?? this.fresnel,
        sheen: sheen ?? this.sheen,
        clearcoat: clearcoat ?? this.clearcoat,
        translucency: translucency ?? this.translucency,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceMaterial &&
          roughness == other.roughness &&
          metallic == other.metallic &&
          fresnel == other.fresnel &&
          sheen == other.sheen &&
          clearcoat == other.clearcoat &&
          translucency == other.translucency;

  @override
  int get hashCode =>
      Object.hash(roughness, metallic, fresnel, sheen, clearcoat, translucency);

  @override
  String toString() =>
      'SurfaceMaterial(roughness: $roughness, metallic: $metallic, '
      'fresnel: $fresnel, sheen: $sheen, clearcoat: $clearcoat, '
      'translucency: $translucency)';
}
