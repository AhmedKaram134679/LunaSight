import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('Vector3', () {
    const epsilonNorm = 1e-15; // dimensionless

    test(
      'Validating constructor allows finite components and rejects non-finite',
      () {
        final v = Vector3(1.0, 2.0, 3.0);
        expect(v.x, 1.0);
        expect(v.y, 2.0);
        expect(v.z, 3.0);

        expect(
          () => Vector3(double.nan, 2.0, 3.0),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
        expect(
          () => Vector3(1.0, double.infinity, 3.0),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
        expect(
          () => Vector3(1.0, 2.0, double.negativeInfinity),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
      },
    );

    test('Canonical const instances have exact components', () {
      expect(Vector3.zero.x, 0.0);
      expect(Vector3.zero.y, 0.0);
      expect(Vector3.zero.z, 0.0);

      expect(Vector3.unitX.x, 1.0);
      expect(Vector3.unitX.y, 0.0);
      expect(Vector3.unitX.z, 0.0);

      expect(Vector3.unitY.x, 0.0);
      expect(Vector3.unitY.y, 1.0);
      expect(Vector3.unitY.z, 0.0);

      expect(Vector3.unitZ.x, 0.0);
      expect(Vector3.unitZ.y, 0.0);
      expect(Vector3.unitZ.z, 1.0);
    });

    test('Vector3 addition, subtraction, negation', () {
      final v1 = Vector3(1.0, 2.0, 3.0);
      final v2 = Vector3(4.0, 5.0, 6.0);

      final sum = v1 + v2;
      expect(sum, equals(Vector3(5.0, 7.0, 9.0)));

      final diff = v1 - v2;
      expect(diff, equals(Vector3(-3.0, -3.0, -3.0)));

      final neg = -v1;
      expect(neg, equals(Vector3(-1.0, -2.0, -3.0)));
    });

    test('Vector3 addition/subtraction overflow detection', () {
      final huge = Vector3(1.7e308, 0.0, 0.0);

      expect(
        () => huge + huge,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );

      expect(
        () => (-huge) - huge,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Scalar multiplication and division', () {
      final v = Vector3(2.0, -4.0, 6.0);

      final mul = v * 0.5;
      expect(mul, equals(Vector3(1.0, -2.0, 3.0)));

      final div = v / 2.0;
      expect(div, equals(Vector3(1.0, -2.0, 3.0)));

      expect(
        () => v / 0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );
      expect(
        () => v / -0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );

      expect(
        () => v * double.nan,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
      expect(
        () => v / double.infinity,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
    });

    test('Dot product invariants and commutativity', () {
      final i = Vector3.unitX;
      final j = Vector3.unitY;
      final u = Vector3(1.0, 2.0, 3.0);
      final v = Vector3(4.0, -5.0, 6.0);

      expect(i.dot(j), 0.0);
      expect(i.dot(i), 1.0);
      expect(u.dot(v), equals(v.dot(u)));
      expect(u.dot(v), 1.0 * 4.0 + 2.0 * -5.0 + 3.0 * 6.0); // 4 - 10 + 18 = 12
    });

    test('Dot product intermediate multiplication overflow detection', () {
      final huge1 = Vector3(1e200, 0.0, 0.0);
      final huge2 = Vector3(1e200, 0.0, 0.0);

      expect(
        () => huge1.dot(huge2),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Cross product invariants and right-hand orientation', () {
      final i = Vector3.unitX;
      final j = Vector3.unitY;
      final k = Vector3.unitZ;

      expect(i.cross(j), equals(k));
      expect(j.cross(k), equals(i));
      expect(k.cross(i), equals(j));
      expect(j.cross(i), equals(-k));

      final v = Vector3(1.0, 2.0, 3.0);
      expect(v.cross(v), equals(Vector3.zero));
    });

    test('Cross product intermediate overflow detection', () {
      final huge1 = Vector3(1e200, 0.0, 0.0);
      final huge2 = Vector3(0.0, 1e200, 0.0);

      expect(
        () => huge1.cross(huge2),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Scaled magnitude: ordinary vector', () {
      final v = Vector3(3.0, 4.0, 0.0);
      expect(v.magnitude, 5.0);

      final v3d = Vector3(2.0, 3.0, 6.0);
      expect(v3d.magnitude, 7.0);
    });

    test('Scaled magnitude: zero vector', () {
      expect(Vector3.zero.magnitude, 0.0);
    });

    test('Scaled magnitude regression: Large vector avoids naive squaring overflow', () {
      // Components 1e200 square to 1e400 which overflows naive sum of squares (Omega ~ 1.79e308).
      // Scaled magnitude must compute sqrt(3) * 1e200 accurately.
      final v = Vector3(1e200, 1e200, 1e200);
      final expected = math.sqrt(3.0) * 1e200;
      expect(v.magnitude, closeTo(expected, expected * 1e-15));
    });

    test('Scaled magnitude regression: Small vector avoids naive squaring underflow', () {
      // Components 1e-200 square to 1e-400 which underflows to 0.0 in naive sum of squares.
      // Scaled magnitude must compute sqrt(3) * 1e-200 accurately.
      final v = Vector3(1e-200, 1e-200, 1e-200);
      final expected = math.sqrt(3.0) * 1e-200;
      expect(v.magnitude, closeTo(expected, expected * 1e-15));
    });

    test('Scaled magnitude regression: (1.0e308, 1.0e308, 1.0e308) near-limit finite', () {
      // Mathematical magnitude: sqrt(3) * 1e308 approx 1.7320508075688773e308 < Omega (approx 1.797e308).
      // Naive sum of squares overflows at 1e154. Scaled magnitude remains finite.
      final v = Vector3(1.0e308, 1.0e308, 1.0e308);
      final expected = math.sqrt(3.0) * 1.0e308;
      expect(v.magnitude.isFinite, isTrue);
      expect(v.magnitude, closeTo(expected, expected * 1e-15));
    });

    test('Scaled magnitude regression: (1.1e308, 1.1e308, 1.1e308) reliably overflows to MAGNITUDE_OVERFLOW', () {
      // Mathematical magnitude: 1.1 * sqrt(3) * 1e308 approx 1.90526e308 > Omega.
      // Final multiplication m * scaledSum evaluates to +Infinity in binary64.
      final v = Vector3(1.1e308, 1.1e308, 1.1e308);
      expect(
        () => v.magnitude,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'MAGNITUDE_OVERFLOW',
          ),
        ),
      );
    });

    test('Scaled normalization: standard vector', () {
      final v = Vector3(0.0, 3.0, 4.0);
      final unit = v.normalize();
      expect(unit.x, 0.0);
      expect(unit.y, closeTo(0.6, epsilonNorm));
      expect(unit.z, closeTo(0.8, epsilonNorm));
      expect(unit.magnitude, closeTo(1.0, epsilonNorm));
    });

    test(
      'Scaled normalization: very large vector (avoiding squaring overflow)',
      () {
        final v = Vector3(0.0, 3e250, 4e250);
        final unit = v.normalize();
        expect(unit.x, 0.0);
        expect(unit.y, closeTo(0.6, epsilonNorm));
        expect(unit.z, closeTo(0.8, epsilonNorm));
        expect(unit.magnitude, closeTo(1.0, epsilonNorm));
      },
    );

    test(
      'Scaled normalization: very small vector (avoiding squaring underflow)',
      () {
        final v = Vector3(0.0, 3e-250, 4e-250);
        final unit = v.normalize();
        expect(unit.x, 0.0);
        expect(unit.y, closeTo(0.6, epsilonNorm));
        expect(unit.z, closeTo(0.8, epsilonNorm));
        expect(unit.magnitude, closeTo(1.0, epsilonNorm));
      },
    );

    test('Zero vector normalization strictly rejected with ZERO_VECTOR_NORMALIZATION', () {
      expect(
        () => Vector3.zero.normalize(),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ZERO_VECTOR_NORMALIZATION',
          ),
        ),
      );

      final exactZero = Vector3(0.0, 0.0, 0.0);
      expect(
        () => exactZero.normalize(),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ZERO_VECTOR_NORMALIZATION',
          ),
        ),
      );
    });

    test('Small nonzero component is not misclassified as zero', () {
      // Vector with tiny component 1e-320 (subnormal) and two zeros.
      // Must not throw ZERO_VECTOR_NORMALIZATION.
      final v = Vector3(1e-320, 0.0, 0.0);
      final unit = v.normalize();
      expect(unit.x, 1.0);
      expect(unit.y, 0.0);
      expect(unit.z, 0.0);
      expect(unit.magnitude, 1.0);
    });

    test(
      'Dot product final summation overflow detection (finite products)',
      () {
        // Pairwise products: px = 1e308, py = 1e308, pz = 0.
        // Individual products are well within finite binary64 range (Omega ~ 1.797e308).
        // Summation px + py = 2e308 > Omega overflows to +Infinity.
        final u = Vector3(1e308, 1e308, 0.0);
        final v = Vector3(1.0, 1.0, 0.0);

        expect(
          () => u.dot(v),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'ARITHMETIC_OVERFLOW',
            ),
          ),
        );
      },
    );

    test(
      'Cross product final subtraction overflow detection (finite products)',
      () {
        // For Z component: p1z = x * other.y = (1.7e308) * (1.0) = 1.7e308 (finite).
        //                  p2z = y * other.x = (-1.7e308) * (1.0) = -1.7e308 (finite).
        // Subtraction: p1z - p2z = 1.7e308 - (-1.7e308) = 3.4e308 > Omega overflows to +Infinity.
        final u = Vector3(1.7e308, -1.7e308, 0.0);
        final v = Vector3(1.0, 1.0, 0.0);

        expect(
          () => u.cross(v),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'ARITHMETIC_OVERFLOW',
            ),
          ),
        );
      },
    );

    test('Mixed-exponent vector verification (disparate magnitudes)', () {
      // Vector with components spanning multiple orders of magnitude:
      // x = 1e10, y = 2e5, z = 3e0.
      // Analytical magnitude: sqrt(1e20 + 4e10 + 9) = 10000000000.000002
      // Dominant component ratio: y/x = 2e-5, z/x = 3e-10.
      // Both ratios are well above machine epsilon (2^-53 ~ 1.11e-16), so they are
      // representable and their relative precision is preserved in normalization.
      final v = Vector3(1e10, 2e5, 3.0);
      final mag = v.magnitude;
      expect(mag.isFinite, isTrue);

      final analyticalMag = math.sqrt(1e20 + 4e10 + 9.0);
      expect(
        mag,
        closeTo(analyticalMag, 1e-5),
      ); // within 1e-15 relative tolerance

      final unit = v.normalize();
      expect(unit.magnitude, closeTo(1.0, epsilonNorm));
      expect(unit.x, closeTo(1e10 / analyticalMag, epsilonNorm));
      expect(unit.y, closeTo(2e5 / analyticalMag, epsilonNorm));
      expect(unit.z, closeTo(3.0 / analyticalMag, epsilonNorm));
    });

    test('Dot product final summation overflow detection (finite products)', () {
      // Pairwise products: px = 1e308, py = 1e308, pz = 0.
      // Individual products are well within finite binary64 range (Omega ~ 1.797e308).
      // Summation px + py = 2e308 > Omega overflows to +Infinity.
      final u = Vector3(1e308, 1e308, 0.0);
      final v = Vector3(1.0, 1.0, 0.0);

      expect(
        () => u.dot(v),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Cross product final subtraction overflow detection (finite products)', () {
      // For Z component: p1z = x * other.y = (1.7e308) * (1.0) = 1.7e308 (finite).
      //                  p2z = y * other.x = (-1.7e308) * (1.0) = -1.7e308 (finite).
      // Subtraction: p1z - p2z = 1.7e308 - (-1.7e308) = 3.4e308 > Omega overflows to +Infinity.
      final u = Vector3(1.7e308, -1.7e308, 0.0);
      final v = Vector3(1.0, 1.0, 0.0);

      expect(
        () => u.cross(v),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Mixed-exponent vector verification (disparate magnitudes)', () {
      // Vector with components spanning multiple orders of magnitude:
      // x = 1e10, y = 2e5, z = 3e0.
      // Analytical magnitude: sqrt(1e20 + 4e10 + 9) = 10000000000.000002
      // Dominant component ratio: y/x = 2e-5, z/x = 3e-10.
      // Both ratios are well above machine epsilon (2^-53 ~ 1.11e-16), so they are
      // representable and their relative precision is preserved in normalization.
      final v = Vector3(1e10, 2e5, 3.0);
      final mag = v.magnitude;
      expect(mag.isFinite, isTrue);

      final analyticalMag = math.sqrt(1e20 + 4e10 + 9.0);
      expect(mag, closeTo(analyticalMag, 1e-5)); // within 1e-15 relative tolerance

      final unit = v.normalize();
      expect(unit.magnitude, closeTo(1.0, epsilonNorm));
      expect(unit.x, closeTo(1e10 / analyticalMag, epsilonNorm));
      expect(unit.y, closeTo(2e5 / analyticalMag, epsilonNorm));
      expect(unit.z, closeTo(3.0 / analyticalMag, epsilonNorm));
    });
  });
}
