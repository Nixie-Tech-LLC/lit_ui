import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/lit_ui.dart';

void main() {
  group('SurfaceMaterial translucency', () {
    test('default translucency is 0.0 (opaque)', () {
      expect(SurfaceMaterial.matte.translucency, 0.0);
      expect(SurfaceMaterial.polishedMetal.translucency, 0.0);
      expect(SurfaceMaterial.glossy.translucency, 0.0);
    });

    test('glass preset has high translucency', () {
      expect(SurfaceMaterial.glass.translucency, greaterThan(0.5));
    });

    test('glass preset has low roughness', () {
      expect(SurfaceMaterial.glass.roughness, lessThan(0.2));
    });

    test('glass preset has high fresnel', () {
      expect(SurfaceMaterial.glass.fresnel, greaterThan(0.7));
    });

    test('custom material stores translucency', () {
      const m = SurfaceMaterial(
        roughness: 0.1,
        metallic: 0.0,
        fresnel: 0.6,
        sheen: 0.0,
        clearcoat: 0.0,
        translucency: 0.5,
      );
      expect(m.translucency, 0.5);
    });

    test('equality includes translucency', () {
      const a = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.5,
      );
      const b = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.5,
      );
      const c = SurfaceMaterial(
        roughness: 0.1, metallic: 0.0, fresnel: 0.6,
        sheen: 0.0, clearcoat: 0.0, translucency: 0.8,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('frostedGlass preset has moderate translucency and higher roughness', () {
      expect(SurfaceMaterial.frostedGlass.translucency, greaterThan(0.3));
      expect(SurfaceMaterial.frostedGlass.roughness, greaterThan(SurfaceMaterial.glass.roughness));
    });
  });
}
