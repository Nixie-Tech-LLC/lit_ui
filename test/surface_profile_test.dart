import 'package:flutter_test/flutter_test.dart';
import 'package:lit_ui/src/surface_profile.dart';

void main() {
  // ── SurfacePattern enum ───────────────────────────────────────────────────

  group('SurfacePattern enum', () {
    test('has all four expected values', () {
      const values = SurfacePattern.values;
      expect(values, contains(SurfacePattern.flat));
      expect(values, contains(SurfacePattern.grooves));
      expect(values, contains(SurfacePattern.dimples));
      expect(values, contains(SurfacePattern.noise));
      expect(values.length, equals(4));
    });
  });

  // ── SurfaceProfile.flat ───────────────────────────────────────────────────

  group('SurfaceProfile.flat', () {
    test('has zero amplitude', () {
      expect(SurfaceProfile.flat.amplitude, equals(0.0));
    });

    test('has pattern == SurfacePattern.flat', () {
      expect(SurfaceProfile.flat.pattern, equals(SurfacePattern.flat));
    });

    test('is const', () {
      // Two references to the static const should be identical.
      const a = SurfaceProfile.flat;
      const b = SurfaceProfile.flat;
      expect(identical(a, b), isTrue);
    });
  });

  // ── SurfaceProfile.grooves ────────────────────────────────────────────────

  group('SurfaceProfile.grooves()', () {
    test('has correct pattern', () {
      const p = SurfaceProfile.grooves();
      expect(p.pattern, equals(SurfacePattern.grooves));
    });

    test('has non-zero default frequency', () {
      const p = SurfaceProfile.grooves();
      expect(p.frequency, greaterThan(0.0));
    });

    test('has non-zero default amplitude', () {
      const p = SurfaceProfile.grooves();
      expect(p.amplitude, greaterThan(0.0));
    });

    test('uses default values frequency=12, amplitude=0.4, angle=0', () {
      const p = SurfaceProfile.grooves();
      expect(p.frequency, equals(12.0));
      expect(p.amplitude, equals(0.4));
      expect(p.angle, equals(0.0));
    });

    test('accepts custom frequency, amplitude, and angle', () {
      const p = SurfaceProfile.grooves(
        frequency: 20.0,
        amplitude: 0.7,
        angle: 1.5,
      );
      expect(p.frequency, equals(20.0));
      expect(p.amplitude, equals(0.7));
      expect(p.angle, equals(1.5));
    });
  });

  // ── SurfaceProfile.dimples ────────────────────────────────────────────────

  group('SurfaceProfile.dimples()', () {
    test('has correct pattern', () {
      const p = SurfaceProfile.dimples();
      expect(p.pattern, equals(SurfacePattern.dimples));
    });

    test('uses default values frequency=10, amplitude=0.3', () {
      const p = SurfaceProfile.dimples();
      expect(p.frequency, equals(10.0));
      expect(p.amplitude, equals(0.3));
    });

    test('angle is always 0', () {
      const p = SurfaceProfile.dimples();
      expect(p.angle, equals(0.0));
    });

    test('accepts custom frequency and amplitude', () {
      const p = SurfaceProfile.dimples(frequency: 5.0, amplitude: 0.8);
      expect(p.frequency, equals(5.0));
      expect(p.amplitude, equals(0.8));
    });
  });

  // ── SurfaceProfile.noise ──────────────────────────────────────────────────

  group('SurfaceProfile.noise()', () {
    test('has correct pattern', () {
      const p = SurfaceProfile.noise();
      expect(p.pattern, equals(SurfacePattern.noise));
    });

    test('uses default values frequency=8, amplitude=0.5', () {
      const p = SurfaceProfile.noise();
      expect(p.frequency, equals(8.0));
      expect(p.amplitude, equals(0.5));
    });

    test('angle is always 0', () {
      const p = SurfaceProfile.noise();
      expect(p.angle, equals(0.0));
    });

    test('accepts custom frequency and amplitude', () {
      const p = SurfaceProfile.noise(frequency: 16.0, amplitude: 0.2);
      expect(p.frequency, equals(16.0));
      expect(p.amplitude, equals(0.2));
    });
  });

  // ── Custom SurfaceProfile ─────────────────────────────────────────────────

  group('SurfaceProfile (custom)', () {
    test('stores all four parameters correctly', () {
      const p = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 7.5,
        amplitude: 0.6,
        angle: 0.785,
      );
      expect(p.pattern, equals(SurfacePattern.grooves));
      expect(p.frequency, equals(7.5));
      expect(p.amplitude, equals(0.6));
      expect(p.angle, equals(0.785));
    });

    test('default frequency is 12.0', () {
      const p = SurfaceProfile(pattern: SurfacePattern.noise, amplitude: 0.3);
      expect(p.frequency, equals(12.0));
    });

    test('default amplitude is 0.4', () {
      const p = SurfaceProfile(pattern: SurfacePattern.noise);
      expect(p.amplitude, equals(0.4));
    });

    test('default angle is 0.0', () {
      const p = SurfaceProfile(pattern: SurfacePattern.grooves);
      expect(p.angle, equals(0.0));
    });
  });

  // ── Equality and hashCode ─────────────────────────────────────────────────

  group('equality and hashCode', () {
    test('two identical profiles are equal', () {
      const a = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 12.0,
        amplitude: 0.4,
        angle: 0.0,
      );
      const b = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 12.0,
        amplitude: 0.4,
        angle: 0.0,
      );
      expect(a, equals(b));
    });

    test('equal profiles have equal hashCodes', () {
      const a = SurfaceProfile(
        pattern: SurfacePattern.dimples,
        frequency: 10.0,
        amplitude: 0.3,
      );
      const b = SurfaceProfile(
        pattern: SurfacePattern.dimples,
        frequency: 10.0,
        amplitude: 0.3,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('profiles differing in pattern are not equal', () {
      const a = SurfaceProfile(pattern: SurfacePattern.grooves);
      const b = SurfaceProfile(pattern: SurfacePattern.noise);
      expect(a, isNot(equals(b)));
    });

    test('profiles differing in frequency are not equal', () {
      const a = SurfaceProfile(pattern: SurfacePattern.grooves, frequency: 10.0);
      const b = SurfaceProfile(pattern: SurfacePattern.grooves, frequency: 20.0);
      expect(a, isNot(equals(b)));
    });

    test('profiles differing in amplitude are not equal', () {
      const a = SurfaceProfile(
          pattern: SurfacePattern.grooves, amplitude: 0.2);
      const b = SurfaceProfile(
          pattern: SurfacePattern.grooves, amplitude: 0.8);
      expect(a, isNot(equals(b)));
    });

    test('profiles differing in angle are not equal', () {
      const a = SurfaceProfile(
          pattern: SurfacePattern.grooves, angle: 0.0);
      const b = SurfaceProfile(
          pattern: SurfacePattern.grooves, angle: 1.0);
      expect(a, isNot(equals(b)));
    });

    test('flat static const equals equivalent constructed profile', () {
      const equivalent = SurfaceProfile(
        pattern: SurfacePattern.flat,
        frequency: 12.0,
        amplitude: 0.0,
        angle: 0.0,
      );
      expect(SurfaceProfile.flat, equals(equivalent));
    });
  });

  // ── toString ──────────────────────────────────────────────────────────────

  group('toString', () {
    test('contains pattern, frequency, amplitude, and angle', () {
      const p = SurfaceProfile(
        pattern: SurfacePattern.grooves,
        frequency: 12.0,
        amplitude: 0.4,
        angle: 0.0,
      );
      final s = p.toString();
      expect(s, contains('SurfaceProfile'));
      expect(s, contains('grooves'));
      expect(s, contains('12.0'));
      expect(s, contains('0.4'));
      expect(s, contains('0.0'));
    });
  });
}
