import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/terrain_horizon/domain/projections/south_polar_stereographic.dart';

void main() {
  group('South Polar Stereographic Projection Tests', () {
    const proj = SouthPolarStereographic(
      sphereRadiusMeters: 1737400.0,
      centralMeridianDegrees: 0.0,
    );

    test('South Pole (-90°) projects to exact (0, 0) meters', () {
      final (x, y) = proj.forward(
        latitude: Angle.fromDegrees(-90.0),
        longitude: Angle.fromDegrees(0.0),
      );
      expect(x, equals(0.0));
      expect(y, equals(0.0));

      final (invLat, invLon) = proj.inverse(x: 0.0, y: 0.0);
      expect(invLat.inDegrees, equals(-90.0));
      expect(invLon.inDegrees, equals(0.0));
    });

    test('Cardinal directions at 88°S project to correct quadrant', () {
      // At -88° latitude (colatitude = 2° = 2 * pi / 180 rad)
      // d = 2 * R * tan(1°) = 2 * 1737400 * tan(pi/180) ≈ 60,652.8 m
      final expectedRho =
          2.0 * 1737400.0 * math.tan((45.0 - 44.0) * math.pi / 180.0);

      // 1. Prime meridian (0°E): should point to -Y in GMT/USGS convention
      final (x0, y0) = proj.forward(
        latitude: Angle.fromDegrees(-88.0),
        longitude: Angle.fromDegrees(0.0),
      );
      expect(x0, closeTo(0.0, 1e-4));
      expect(y0, closeTo(-expectedRho, 1e-4));

      // 2. 90° East: should point to +X
      final (x90, y90) = proj.forward(
        latitude: Angle.fromDegrees(-88.0),
        longitude: Angle.fromDegrees(90.0),
      );
      expect(x90, closeTo(expectedRho, 1e-4));
      expect(y90, closeTo(0.0, 1e-4));

      // 3. 180° East: should point to +Y
      final (x180, y180) = proj.forward(
        latitude: Angle.fromDegrees(-88.0),
        longitude: Angle.fromDegrees(180.0),
      );
      expect(x180, closeTo(0.0, 1e-4));
      expect(y180, closeTo(expectedRho, 1e-4));

      // 4. -90° East (270°E): should point to -X
      final (x270, y270) = proj.forward(
        latitude: Angle.fromDegrees(-88.0),
        longitude: Angle.fromDegrees(-90.0),
      );
      expect(x270, closeTo(-expectedRho, 1e-4));
      expect(y270, closeTo(0.0, 1e-4));
    });

    test('Round-trip forward-inverse identity across multiple coordinates', () {
      final testCoords = [
        (-89.9, 0.0),
        (-89.5, 45.0),
        (-88.45, -160.0),
        (-87.0, 120.0),
        (-85.0, -45.0),
      ];

      for (final (latDeg, lonDeg) in testCoords) {
        final (x, y) = proj.forward(
          latitude: Angle.fromDegrees(latDeg),
          longitude: Angle.fromDegrees(lonDeg),
        );

        final (invLat, invLon) = proj.inverse(x: x, y: y);

        expect(invLat.inDegrees, closeTo(latDeg, 1e-6));

        var dLon = (invLon.inDegrees - lonDeg).abs();
        while (dLon > 180.0) {
          dLon = (dLon - 360.0).abs();
        }
        expect(dLon, closeTo(0.0, 1e-6));
      }
    });
  });
}
