import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('SurfaceMaterial — custom constructor', () {
    const custom = SurfaceMaterial(
      roughness: 0.4,
      metallic: 0.6,
      fresnel: 0.3,
      sheen: 0.2,
      clearcoat: 0.5,
    );

    test('stores all 5 properties correctly', () {
      expect(custom.roughness, 0.4);
      expect(custom.metallic, 0.6);
      expect(custom.fresnel, 0.3);
      expect(custom.sheen, 0.2);
      expect(custom.clearcoat, 0.5);
    });

    test('equality holds for identical values', () {
      const same = SurfaceMaterial(
        roughness: 0.4,
        metallic: 0.6,
        fresnel: 0.3,
        sheen: 0.2,
        clearcoat: 0.5,
      );
      expect(custom, equals(same));
    });

    test('hashCode matches for equal materials', () {
      const same = SurfaceMaterial(
        roughness: 0.4,
        metallic: 0.6,
        fresnel: 0.3,
        sheen: 0.2,
        clearcoat: 0.5,
      );
      expect(custom.hashCode, same.hashCode);
    });

    test('inequality when any property differs', () {
      const different = SurfaceMaterial(
        roughness: 0.9,
        metallic: 0.6,
        fresnel: 0.3,
        sheen: 0.2,
        clearcoat: 0.5,
      );
      expect(custom, isNot(equals(different)));
    });

    test('toString contains all property names and values', () {
      final s = custom.toString();
      expect(s, contains('roughness'));
      expect(s, contains('metallic'));
      expect(s, contains('fresnel'));
      expect(s, contains('sheen'));
      expect(s, contains('clearcoat'));
    });
  });

  group('SurfaceMaterial.polishedMetal preset', () {
    test('has low roughness (≤ 0.2)', () {
      expect(SurfaceMaterial.polishedMetal.roughness, lessThanOrEqualTo(0.2));
    });

    test('has high metallic (≥ 0.9)', () {
      expect(SurfaceMaterial.polishedMetal.metallic, greaterThanOrEqualTo(0.9));
    });

    test('highlightTint > 0.5', () {
      expect(SurfaceMaterial.polishedMetal.highlightTint, greaterThan(0.5));
    });

    test('fillContrast is greater than fuzzy fillContrast', () {
      expect(
        SurfaceMaterial.polishedMetal.fillContrast,
        greaterThan(SurfaceMaterial.fuzzy.fillContrast),
      );
    });

    test('borderContrast is greater than matte borderContrast', () {
      expect(
        SurfaceMaterial.polishedMetal.borderContrast,
        greaterThan(SurfaceMaterial.matte.borderContrast),
      );
    });
  });

  group('SurfaceMaterial.matte preset', () {
    test('has high roughness (≥ 0.6)', () {
      expect(SurfaceMaterial.matte.roughness, greaterThanOrEqualTo(0.6));
    });

    test('has zero metallic', () {
      expect(SurfaceMaterial.matte.metallic, 0.0);
    });

    test('highlightTint == 0.0', () {
      expect(SurfaceMaterial.matte.highlightTint, 0.0);
    });
  });

  group('SurfaceMaterial.fuzzy preset', () {
    test('has high roughness (≥ 0.8)', () {
      expect(SurfaceMaterial.fuzzy.roughness, greaterThanOrEqualTo(0.8));
    });

    test('has high sheen (≥ 0.6)', () {
      expect(SurfaceMaterial.fuzzy.sheen, greaterThanOrEqualTo(0.6));
    });

    test('shadowBlurSigma > polishedMetal shadowBlurSigma', () {
      expect(
        SurfaceMaterial.fuzzy.shadowBlurSigma,
        greaterThan(SurfaceMaterial.polishedMetal.shadowBlurSigma),
      );
    });
  });

  group('Derived getters — fresnel attenuation', () {
    test('effectiveFresnel decreases as roughness increases', () {
      const smooth = SurfaceMaterial(
        roughness: 0.1,
        metallic: 0.0,
        fresnel: 0.8,
        sheen: 0.0,
        clearcoat: 0.0,
      );
      const rough = SurfaceMaterial(
        roughness: 0.9,
        metallic: 0.0,
        fresnel: 0.8,
        sheen: 0.0,
        clearcoat: 0.0,
      );
      expect(smooth.effectiveFresnel, greaterThan(rough.effectiveFresnel));
    });
  });

  group('Derived getters — valid ranges for all presets', () {
    const presets = <SurfaceMaterial>[
      SurfaceMaterial.polishedMetal,
      SurfaceMaterial.matte,
      SurfaceMaterial.fuzzy,
      SurfaceMaterial.glossy,
      SurfaceMaterial.lacquered,
    ];

    for (final preset in presets) {
      test('${preset.toString().split('(').first} — all derived values in range',
          () {
        // fillContrast: no explicit clamp in spec but should be reasonable
        expect(preset.fillContrast, greaterThanOrEqualTo(0.0));

        // borderContrast: clamped [0, 1]
        expect(preset.borderContrast, inInclusiveRange(0.0, 1.0));

        // highlightTint: equals metallic, so [0, 1]
        expect(preset.highlightTint, inInclusiveRange(0.0, 1.0));

        // effectiveFresnel: clamped [0, 1]
        expect(preset.effectiveFresnel, inInclusiveRange(0.0, 1.0));

        // effectiveSheen: clamped [0, 1]
        expect(preset.effectiveSheen, inInclusiveRange(0.0, 1.0));

        // maxBorderLighten: 0.3 + (1-roughness)*0.4, range [0.3, 0.7]
        expect(preset.maxBorderLighten, inInclusiveRange(0.3, 0.7));

        // maxBorderDarken: 0.05 + (1-roughness)*0.15, range [0.05, 0.2]
        expect(preset.maxBorderDarken, inInclusiveRange(0.05, 0.2));

        // shadowBlurSigma: 0.5 + roughness*3, range [0.5, 3.5]
        expect(preset.shadowBlurSigma, inInclusiveRange(0.5, 3.5));

        // insetShadowIntensity: clamped [0, 1]
        expect(preset.insetShadowIntensity, inInclusiveRange(0.0, 1.0));
      });
    }
  });
}
