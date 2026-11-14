import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';

/// Projection transformer for lunar South Polar Stereographic projection.
///
/// Implements standard USGS / NASA PDS and GMT South Polar Stereographic equations
/// for a spherical body of radius [sphereRadiusMeters] (default 1,737,400.0 m):
///
/// - Standard parallel: $\varphi_0 = -90^\circ$ (South Pole).
/// - Central meridian: $\lambda_0 = 0^\circ$ (Prime meridian points toward +Y, +90°E points toward +X).
///
/// Forward (Lat/Lon -> X/Y):
/// For south polar stereographic conformal mapping:
/// $$k = \frac{2 R}{1 + \sin(-\varphi)} = \frac{2 R}{1 - \sin\varphi}$$
/// In USGS / LOLA convention:
/// $$X = 2 R \tan(\pi/4 + \varphi/2) \sin(\lambda - \lambda_0)$$
/// $$Y = -2 R \tan(\pi/4 + \varphi/2) \cos(\lambda - \lambda_0)$$
///
/// Note: At $\varphi = -90^\circ$ (South Pole), $\tan(\pi/4 - \pi/4) = 0 \implies X = 0, Y = 0$.
final class SouthPolarStereographic {
  final double sphereRadiusMeters;
  final double centralMeridianDegrees;

  const SouthPolarStereographic({
    this.sphereRadiusMeters = 1737400.0,
    this.centralMeridianDegrees = 0.0,
  });

  /// Projects selenocentric/planetocentric geographic coordinates to polar stereographic (X, Y) in meters.
  (double x, double y) forward({
    required Angle latitude,
    required Angle longitude,
  }) {
    final phi = latitude.inRadians;
    final lam = longitude.inRadians;
    final lam0 = centralMeridianDegrees * math.pi / 180.0;

    // Colatitude / polar distance angle from south pole
    // At South Pole (-pi/2), colatitude is 0.
    // tan(pi/4 + phi/2)
    final halfAngle = math.pi / 4.0 + phi / 2.0;
    if (halfAngle <= 0.0) {
      // Exactly at or south of South pole
      return (0.0, 0.0);
    }

    final rho = 2.0 * sphereRadiusMeters * math.tan(halfAngle);
    final dLam = lam - lam0;

    final x = rho * math.sin(dLam);
    final y = -rho * math.cos(dLam);

    return (x, y);
  }

  /// Inverses polar stereographic (X, Y) in meters back to geographic latitude and longitude.
  (Angle latitude, Angle longitude) inverse({
    required double x,
    required double y,
  }) {
    final rho = math.sqrt(x * x + y * y);
    if (rho == 0.0) {
      return (
        Angle.fromDegrees(-90.0),
        Angle.fromDegrees(centralMeridianDegrees),
      );
    }

    final c = 2.0 * math.atan(rho / (2.0 * sphereRadiusMeters));
    // phi = - (pi/2 - c) = c - pi/2
    final phi = c - math.pi / 2.0;

    final lam0 = centralMeridianDegrees * math.pi / 180.0;
    // In USGS convention: X = rho * sin(dLam), -Y = rho * cos(dLam)
    // Therefore: dLam = atan2(X, -Y)
    final dLam = math.atan2(x, -y);
    var lam = lam0 + dLam;

    // Normalize longitude to [-pi, pi]
    while (lam > math.pi) {
      lam -= 2.0 * math.pi;
    }
    while (lam < -math.pi) {
      lam += 2.0 * math.pi;
    }

    return (Angle.fromRadians(phi), Angle.fromRadians(lam));
  }
}
