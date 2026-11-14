import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';

void main() {
  group('ElevationSample Model', () {
    test('valid sample holds correct properties', () {
      final sample = ElevationSample(
        elevationMeters: 1250.5,
        status: ElevationSampleStatus.valid,
        latitude: Angle.fromDegrees(-89.5),
        longitude: Angle.fromDegrees(45.0),
        projectedX: 50.0,
        projectedY: 100.0,
      );
      expect(sample.isValid, isTrue);
      expect(sample.status, ElevationSampleStatus.valid);
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

  group('DemTile Bilinear and Nearest-Neighbor Sampling', () {
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

    test('bilinear interpolation between 4 valid points', () {
      // Center between (0,0) [10], (1,0) [20], (0,1) [20], (1,1) [30]
      // In pixel indices: col = 1.0, row = 1.0 is at x = 10, y = -10
      // v00=10 (c=0,r=0), v10=20 (c=1,r=0), v01=20 (c=0,r=1), v11=30 (c=1,r=1)
      // At x = 5.0, y = -5.0: col = 0.5, row = 0.5
      // top = 10*0.5 + 20*0.5 = 15; bottom = 20*0.5 + 30*0.5 = 25; center = 20.0
      final sample = tile.sampleBilinear(5.0, -5.0);
      expect(sample, isNotNull);
      expect(sample!, closeTo(20.0, 1e-4));
    });

    test('rejection of NoData when fallback is also NoData', () {
      // Point directly on (col 2, row 2) which is NoData (-32768.0)
      // col = 2 -> x = 20, row = 2 -> y = -20
      final sample = tile.sampleNearest(25.0, -25.0);
      expect(sample, isNull);
    });

    test('out of bounds queries return null', () {
      expect(tile.sampleNearest(-5.0, -20.0), isNull);
      expect(tile.sampleBilinear(50.0, -20.0), isNull);
      expect(tile.sampleNearest(20.0, 10.0), isNull);
      expect(tile.sampleBilinear(20.0, -50.0), isNull);
    });
  });
}
