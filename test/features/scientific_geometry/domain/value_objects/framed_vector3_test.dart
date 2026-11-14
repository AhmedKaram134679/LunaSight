import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('FramedVector3', () {
    final frame = ReferenceFrameId.moonMeDe421;
    final origin = CoordinateOriginId.moonCenterOfMass;

    test('Construction, field preservation, and equality', () {
      final v = Vector3(1000.0, 2000.0, 3000.0);
      final framed = FramedVector3(
        vector: v,
        frame: frame,
        origin: origin,
        unit: VectorUnit.meters,
      );

      expect(framed.vector, equals(v));
      expect(framed.frame, equals(frame));
      expect(framed.origin, equals(origin));
      expect(framed.unit, equals(VectorUnit.meters));

      final framedSame = FramedVector3(
        vector: Vector3(1000.0, 2000.0, 3000.0),
        frame: ReferenceFrameId.moonMeDe421,
        origin: CoordinateOriginId.moonCenterOfMass,
        unit: VectorUnit.meters,
      );
      expect(framed, equals(framedSame));
      expect(framed.hashCode, equals(framedSame.hashCode));
    });

    test('Unit conversion: meters to kilometers', () {
      final framed = FramedVector3(
        vector: Vector3(1000.0, 2000.0, 3000.0),
        frame: frame,
        origin: origin,
        unit: VectorUnit.meters,
      );

      final converted = framed.toUnit(VectorUnit.kilometers);
      expect(converted.unit, equals(VectorUnit.kilometers));
      expect(converted.vector.x, equals(1.0));
      expect(converted.vector.y, equals(2.0));
      expect(converted.vector.z, equals(3.0));
      expect(converted.frame, equals(frame));
      expect(converted.origin, equals(origin));
    });

    test('Unit conversion: kilometers to meters', () {
      final framed = FramedVector3(
        vector: Vector3(1.5, 2.5, 3.5),
        frame: frame,
        origin: origin,
        unit: VectorUnit.kilometers,
      );

      final converted = framed.toUnit(VectorUnit.meters);
      expect(converted.unit, equals(VectorUnit.meters));
      expect(converted.vector.x, equals(1500.0));
      expect(converted.vector.y, equals(2500.0));
      expect(converted.vector.z, equals(3500.0));
      expect(converted.frame, equals(frame));
      expect(converted.origin, equals(origin));
    });

    test('Unit conversion: identity (same unit)', () {
      final framed = FramedVector3(
        vector: Vector3(1.0, 2.0, 3.0),
        frame: frame,
        origin: origin,
        unit: VectorUnit.dimensionless,
      );

      final converted = framed.toUnit(VectorUnit.dimensionless);
      expect(identical(converted, framed), isTrue);
    });

    test('Unit conversion: overflow detection', () {
      final framed = FramedVector3(
        vector: Vector3(1e306, 0.0, 0.0),
        frame: frame,
        origin: origin,
        unit: VectorUnit.kilometers,
      );

      expect(
        () => framed.toUnit(VectorUnit.meters),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Unit conversion: rejects conversion between dimensionless and physical units', () {
      final dimLess = FramedVector3(
        vector: Vector3(0.0, 0.6, 0.8),
        frame: frame,
        origin: origin,
        unit: VectorUnit.dimensionless,
      );

      expect(
        () => dimLess.toUnit(VectorUnit.meters),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'UNIT_MISMATCH',
          ),
        ),
      );

      expect(
        () => dimLess.toUnit(VectorUnit.kilometers),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'UNIT_MISMATCH',
          ),
        ),
      );

      final inMeters = FramedVector3(
        vector: Vector3(100.0, 200.0, 300.0),
        frame: frame,
        origin: origin,
        unit: VectorUnit.meters,
      );

      expect(
        () => inMeters.toUnit(VectorUnit.dimensionless),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'UNIT_MISMATCH',
          ),
        ),
      );
    });

    test('FramedVector3 does not possess an epoch field', () {
      // In accordance with Phase 04B specification, FramedVector3 is purely spatial.
      // Epoch/time-tagging is deferred to ephemeris-state contracts in Phase 04C/04D.
      final framed = FramedVector3(
        vector: Vector3(1.0, 1.0, 1.0),
        frame: frame,
        origin: origin,
        unit: VectorUnit.meters,
      );
      expect(framed, isA<FramedVector3>());
    });
  });
}
