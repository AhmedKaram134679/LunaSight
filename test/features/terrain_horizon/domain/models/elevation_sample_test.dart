import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';

void main() {
  group('ElevationSample Model', () {
    test('valid sample holds correct properties', () {
      final sample = ElevationSample(
        elevationMeters: 1250.5,
        status: ElevationSampleStatus.validBilinear,
        latitude: Angle.fromDegrees(-89.5),
        longitude: Angle.fromDegrees(45.0),
        projectedX: 50.0,
        projectedY: 100.0,
      );
      expect(sample.isValid, isTrue);
      expect(sample.status, ElevationSampleStatus.validBilinear);
      expect(sample.elevationMeters, 1250.5);
      expect(sample.projectedX, 50.0);
      expect(sample.projectedY, 100.0);
    });

    test('noData sample indicates invalid status', () {
      final sample = ElevationSample.noDataSample;
      expect(sample.isValid, isFalse);
      expect(sample.status, ElevationSampleStatus.noData);
    });

    test('outOfBounds sample indicates outsideCoverage status', () {
      final sample = ElevationSample.outOfBounds;
      expect(sample.isValid, isFalse);
      expect(sample.status, ElevationSampleStatus.outsideCoverage);
    });
  });

  group('DemTile Bilinear, Nearest-Neighbor, and Quality Distinctions', () {
    late DemTile tile;

    setUp(() {
      // Create a 4x4 tile spanning (0, 0) to (40, -40) meters
      // minX = 0, maxX = 40, minY = -40, maxY = 0, pixelScale = 10 m/pixel
      // Grid values:
      // Row 0 (y = 0 to -10):  10,  20,  30,  40
      // Row 1 (y = -10 to -20): 20,  30,  40,  50
      // Row 2 (y = -20 to -30): 30,  40, -32768 (NoData), 60
      // Row 3 (y = -30 to -40): 40,  50,  60,  70
      final buffer = Float32List.fromList([
        10.0,
        20.0,
        30.0,
        40.0,
        20.0,
        30.0,
        40.0,
        50.0,
        30.0,
        40.0,
        -32768.0,
        60.0,
        40.0,
        50.0,
        60.0,
        70.0,
      ]);

      tile = DemTile(
        tileX: 0,
        tileY: 0,
        width: 4,
        height: 4,
        elevations: buffer,
        minX: 0.0,
        maxX: 40.0,
        minY: -40.0,
        maxY: 0.0,
        pixelScale: 10.0,
        noDataValue: -32768.0,
      );
    });

    test('nearest-neighbor sampling at pixel centers', () {
      // Pixel (0, 0) center: x = 5, y = -5
      final sample00 = tile.sampleNearest(5.0, -5.0);
      expect(sample00, isNotNull);
      expect(sample00!, closeTo(10.0, 1e-4));

      // Pixel (1, 1) center: x = 15, y = -15
      final sample11 = tile.sampleNearest(15.0, -15.0);
      expect(sample11, isNotNull);
      expect(sample11!, closeTo(30.0, 1e-4));
    });

    test(
      'bilinear interpolation between 4 valid points returns validBilinear',
      () {
        // Center between (0,0) [10], (1,0) [20], (0,1) [20], (1,1) [30]
        // In pixel indices: col = 1.0, row = 1.0 is at x = 10, y = -10
        // At x = 5.0, y = -5.0: col = 0.5, row = 0.5
        final (elev, status) = tile.sampleDetailed(5.0, -5.0);
        expect(elev, isNotNull);
        expect(elev!, closeTo(20.0, 1e-4));
        expect(status, ElevationSampleStatus.validBilinear);
      },
    );

    test(
      'mixed neighborhood with NoData returns validNearestNeighbor fallback',
      () {
        // (col 1, row 1) = 30.0, (col 2, row 1) = 40.0, (col 1, row 2) = 40.0, (col 2, row 2) = -32768
        // x = 12.0, y = -12.0 -> col = 1.2, row = 1.2
        // Nearest neighbor is (col 1, row 1) which is 30.0 (valid)
        final (elev, status) = tile.sampleDetailed(12.0, -12.0);
        expect(elev, isNotNull);
        expect(elev!, closeTo(30.0, 1e-4));
        expect(status, ElevationSampleStatus.validNearestNeighbor);
      },
    );

    test('rejection of NoData when nearest fallback is also NoData', () {
      // (col 2, row 2) is NoData (-32768.0).
      // At x = 25.0, y = -25.0, col = 2.5, row = 2.5.
      // At x = 22.0, y = -22.0, col = 2.2, row = 2.2 -> nearest is (col 2, row 2) which is NoData
      final (elev, status) = tile.sampleDetailed(22.0, -22.0);
      expect(elev, isNull);
      expect(status, ElevationSampleStatus.noData);
    });

    test('test handling of non-finite floats (NaN, +inf, -inf)', () {
      final bufferWithNonFinite = Float32List.fromList([
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1e35,
      ]);
      final nonFiniteTile = DemTile(
        tileX: 0,
        tileY: 0,
        width: 2,
        height: 2,
        elevations: bufferWithNonFinite,
        minX: 0.0,
        maxX: 20.0,
        minY: -20.0,
        maxY: 0.0,
        pixelScale: 10.0,
      );

      final (elevNan, statusNan) = nonFiniteTile.sampleDetailed(5.0, -5.0);
      expect(elevNan, isNull);
      expect(statusNan, ElevationSampleStatus.noData);

      final (elevInf, statusInf) = nonFiniteTile.sampleDetailed(15.0, -5.0);
      expect(elevInf, isNull);
      expect(statusInf, ElevationSampleStatus.noData);
    });

    test('out of bounds queries return outsideCoverage status', () {
      final (elevLeft, statusLeft) = tile.sampleDetailed(-5.0, -20.0);
      expect(elevLeft, isNull);
      expect(statusLeft, ElevationSampleStatus.outsideCoverage);

      final (elevRight, statusRight) = tile.sampleDetailed(50.0, -20.0);
      expect(elevRight, isNull);
      expect(statusRight, ElevationSampleStatus.outsideCoverage);

      final (elevTop, statusTop) = tile.sampleDetailed(20.0, 10.0);
      expect(elevTop, isNull);
      expect(statusTop, ElevationSampleStatus.outsideCoverage);

      final (elevBottom, statusBottom) = tile.sampleDetailed(20.0, -50.0);
      expect(elevBottom, isNull);
      expect(statusBottom, ElevationSampleStatus.outsideCoverage);
    });
  });
}
