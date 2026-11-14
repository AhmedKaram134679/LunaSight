import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('Distance', () {
    const epsilonD = 1e-12; // m

    test('Construction from meters and accessors', () {
      final d = Distance.fromMeters(1737400.0);
      expect(d.inMeters, equals(1737400.0));
      expect(d.inKilometers, closeTo(1737.4, epsilonD));
    });

    test('Construction from kilometers and accessors', () {
      final d = Distance.fromKilometers(1.0);
      expect(d.inMeters, closeTo(1000.0, epsilonD));
      expect(d.inKilometers, equals(1.0));
    });

    test('Zero distance is valid', () {
      final d0 = Distance.fromMeters(0.0);
      expect(d0.inMeters, equals(0.0));
      expect(d0.inKilometers, equals(0.0));
    });

    test('Rejects negative distance upon construction', () {
      expect(
        () => Distance.fromMeters(-0.001),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NEGATIVE_DISTANCE',
          ),
        ),
      );

      expect(
        () => Distance.fromKilometers(-1.0),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NEGATIVE_DISTANCE',
          ),
        ),
      );
    });

    test('Rejects non-finite values upon construction', () {
      expect(
        () => Distance.fromMeters(double.nan),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Distance.fromMeters(double.infinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Distance.fromKilometers(double.nan),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Distance.fromKilometers(double.infinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
    });

    test('Detects overflow when constructing from huge kilometers', () {
      expect(
        () => Distance.fromKilometers(1e306),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Distance addition and overflow detection', () {
      final d1 = Distance.fromMeters(100.0);
      final d2 = Distance.fromMeters(250.0);
      final sum = d1 + d2;
      expect(sum.inMeters, equals(350.0));

      final huge = Distance.fromMeters(1.7e308);
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
    });

    test('Distance subtraction enforces non-negative distance invariant', () {
      final d1 = Distance.fromMeters(300.0);
      final d2 = Distance.fromMeters(100.0);

      final diff = d1 - d2;
      expect(diff.inMeters, equals(200.0));

      expect(
        () => d2 - d1,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NEGATIVE_DISTANCE',
          ),
        ),
      );
    });

    test('Distance scalar multiplication and overflow/negative rejection', () {
      final d = Distance.fromMeters(50.0);

      final scaled = d * 3.0;
      expect(scaled.inMeters, equals(150.0));

      expect(
        () => d * -1.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NEGATIVE_DISTANCE',
          ),
        ),
      );

      expect(
        () => d * double.nan,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      final huge = Distance.fromMeters(1e308);
      expect(
        () => huge * 10.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Distance division error hierarchy', () {
      final d = Distance.fromMeters(100.0);

      // Normal division
      final res = d / 4.0;
      expect(res.inMeters, equals(25.0));

      // 1. Non-finite scalar
      expect(
        () => d / double.nan,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
      expect(
        () => d / double.infinity,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      // 2. Division by zero
      expect(
        () => d / 0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );
      expect(
        () => d / -0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );

      // 3. Negative scalar
      expect(
        () => d / -2.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NEGATIVE_DISTANCE',
          ),
        ),
      );

      // 4. Arithmetic overflow
      final huge = Distance.fromMeters(1e308);
      expect(
        () => huge / 1e-10,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Equality, hashCode, and Comparable', () {
      final d1 = Distance.fromMeters(100.0);
      final d2 = Distance.fromMeters(100.0);
      final d3 = Distance.fromMeters(200.0);

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));

      expect(d1.compareTo(d2), equals(0));
      expect(d1.compareTo(d3), isNegative);
      expect(d3.compareTo(d1), isPositive);
    });
  });
}
