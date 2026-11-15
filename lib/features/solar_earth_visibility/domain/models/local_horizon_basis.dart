import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';

/// Orthonormal basis vectors representing the local topocentric horizon frame (SEZ: South-East-Zenith).
///
/// Orientations:
/// - Zenith ($\hat{\mathbf{u}}_Z$): Outward unit normal to the lunar reference surface.
/// - North ($\hat{\mathbf{u}}_N$): Unit vector tangent to the local meridian pointing North.
/// - South ($\hat{\mathbf{u}}_S = -\hat{\mathbf{u}}_N$): Along the positive S axis in SEZ coordinates.
/// - East ($\hat{\mathbf{u}}_E$): Unit vector tangent to the local latitude parallel pointing East.
///
/// Handedness & Orthonormality:
/// In the standard astronomical SEZ frame:
/// $$\hat{\mathbf{u}}_S \times \hat{\mathbf{u}}_E = \hat{\mathbf{u}}_Z$$
/// forms a rigorous right-handed orthonormal triad.
///
/// Polar Singularities:
/// At the exact South Pole ($\varphi = -90^\circ$), longitude is mathematically degenerate.
/// The SEZ basis enforces a deterministic meridian-dependent convention:
/// - $\hat{\mathbf{u}}_Z = (0, 0, -1)$
/// - $\hat{\mathbf{u}}_N = (\cos\lambda, \sin\lambda, 0)$
/// - $\hat{\mathbf{u}}_E = (-\sin\lambda, \cos\lambda, 0)$
/// At the Prime Meridian ($\lambda = 0^\circ$): $\hat{\mathbf{u}}_N = (1, 0, 0)$ and $\hat{\mathbf{u}}_E = (0, 1, 0)$.
class LocalHorizonBasis {
  /// Local North unit vector.
  final Vector3 north;

  /// Local East unit vector.
  final Vector3 east;

  /// Local Zenith (Up) unit vector.
  final Vector3 zenith;

  const LocalHorizonBasis._({
    required this.north,
    required this.east,
    required this.zenith,
  });

  /// Local South unit vector ($\hat{\mathbf{u}}_S = -\hat{\mathbf{u}}_N$).
  Vector3 get south => -north;

  /// Computes the orthonormal [LocalHorizonBasis] at selenographic [latitude] and [longitude].
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if coordinates are not finite.
  factory LocalHorizonBasis.fromCoordinates({
    required Angle latitude,
    required Angle longitude,
  }) {
    final latDeg = latitude.inDegrees;
    final lonDeg = longitude.inDegrees;

    if (!latDeg.isFinite || !lonDeg.isFinite) {
      throw ScientificComputationException(
        message: 'Latitude and longitude must be finite numeric angles.',
        code: 'NON_FINITE_VALUE',
        context: {'latitude': latDeg, 'longitude': lonDeg},
      );
    }

    if (latDeg < -90.0 || latDeg > 90.0) {
      throw ScientificComputationException(
        message: 'Latitude must be bounded in [-90, +90] degrees.',
        code: 'LATITUDE_OUT_OF_BOUNDS',
        context: {'latitude': latDeg},
      );
    }

    final phi = latitude.inRadians;
    final lam = longitude.inRadians;

    const eps = 1e-12;

    // Exact North Pole: phi = +90 deg
    if ((latDeg - 90.0).abs() < eps) {
      final cosLam = math.cos(lam);
      final sinLam = math.sin(lam);
      return LocalHorizonBasis._(
        north: Vector3(-cosLam, -sinLam, 0.0),
        east: Vector3(-sinLam, cosLam, 0.0),
        zenith: Vector3(0.0, 0.0, 1.0),
      );
    }

    // Exact South Pole: phi = -90 deg
    if ((latDeg - (-90.0)).abs() < eps) {
      final cosLam = math.cos(lam);
      final sinLam = math.sin(lam);
      return LocalHorizonBasis._(
        north: Vector3(cosLam, sinLam, 0.0),
        east: Vector3(-sinLam, cosLam, 0.0),
        zenith: Vector3(0.0, 0.0, -1.0),
      );
    }

    // Standard non-polar locations:
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);
    final cosLam = math.cos(lam);
    final sinLam = math.sin(lam);

    final uZ = Vector3(cosPhi * cosLam, cosPhi * sinLam, sinPhi);
    final uN = Vector3(-sinPhi * cosLam, -sinPhi * sinLam, cosPhi);
    final uE = Vector3(-sinLam, cosLam, 0.0);

    return LocalHorizonBasis._(north: uN, east: uE, zenith: uZ);
  }

  @override
  String toString() => 'LocalHorizonBasis(N: $north, E: $east, Z: $zenith)';
}
