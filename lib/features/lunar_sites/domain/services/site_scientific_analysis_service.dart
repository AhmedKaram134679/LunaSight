import 'dart:math' as math;

import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/local_horizon_basis.dart';

/// Provenance-tracked geometric analysis result for a lunar landing site with verified coordinates.
class SiteGeometricAnalysis {
  final LunarGeographicCoordinates coordinates;
  final FramedVector3 bodyFixedCartesian;
  final LocalHorizonBasis horizonBasis;
  final double distanceToSouthPoleKm;
  final double effectiveRadiusKm;

  const SiteGeometricAnalysis({
    required this.coordinates,
    required this.bodyFixedCartesian,
    required this.horizonBasis,
    required this.distanceToSouthPoleKm,
    required this.effectiveRadiusKm,
  });

  /// Formatted Cartesian X position in kilometers.
  String get formattedXKm =>
      '${(bodyFixedCartesian.vector.x / 1000.0).toStringAsFixed(3)} km';

  /// Formatted Cartesian Y position in kilometers.
  String get formattedYKm =>
      '${(bodyFixedCartesian.vector.y / 1000.0).toStringAsFixed(3)} km';

  /// Formatted Cartesian Z position in kilometers.
  String get formattedZKm =>
      '${(bodyFixedCartesian.vector.z / 1000.0).toStringAsFixed(3)} km';

  /// Formatted distance to Lunar South Pole in kilometers.
  String get formattedDistanceToSouthPoleKm =>
      '${distanceToSouthPoleKm.toStringAsFixed(2)} km';

  /// Formatted effective radius in kilometers.
  String get formattedEffectiveRadiusKm =>
      '${effectiveRadiusKm.toStringAsFixed(3)} km';
}

/// Service providing scientifically verified geometric analysis for candidate lunar sites.
///
/// Strictly uses production domain engines:
/// - [LunarCoordinateTransformer] for body-fixed Cartesian coordinates ($X, Y, Z$).
/// - [LocalHorizonBasis] for local orthonormal horizon frame ($\hat{\mathbf{u}}_S, \hat{\mathbf{u}}_E, \hat{\mathbf{u}}_Z, \hat{\mathbf{u}}_N$).
class SiteScientificAnalysisService {
  final LunarCoordinateTransformer coordinateTransformer;

  const SiteScientificAnalysisService({
    this.coordinateTransformer = const LunarCoordinateTransformer(),
  });

  /// Evaluates geometric position and horizon basis for [site].
  ///
  /// Returns `null` if [site] does not have explicit point coordinates, preserving
  /// data integrity and strictly preventing false precision or assumed locations.
  SiteGeometricAnalysis? analyzeSite(LunarSite site) {
    final coords = site.coordinates;
    if (coords == null) {
      return null;
    }

    final lat = coords.latitude;
    var lon = coords.longitude;
    final alt = coords.altitudeMeters ?? 0.0;

    // Determine longitude domain
    final LongitudeDomain domain;
    if (lon >= -180.0 && lon <= 180.0) {
      domain = LongitudeDomain.symmetric180;
    } else {
      domain = LongitudeDomain.positive360;
    }

    final direction =
        coords.longitudeConvention == LongitudeConvention.westPositive
        ? LongitudeDirection.westPositive
        : LongitudeDirection.eastPositive;

    final lunarCoords = LunarGeographicCoordinates(
      latitude: Angle.fromDegrees(lat),
      latitudeType: LatitudeType.planetocentric,
      longitude: Angle.fromDegrees(lon),
      longitudeDirection: direction,
      longitudeDomain: domain,
      heightMeters: alt,
      heightReference: HeightReferenceId.sphereRelative,
      frame: ReferenceFrameId.moonMeDe421,
    );

    // 1. Transform to 3D body-fixed Cartesian position vector:
    final cartesian = coordinateTransformer.toBodyFixedCartesian(lunarCoords);

    // 2. Compute local orthonormal horizon basis (SEZ frame):
    final basis = LocalHorizonBasis.fromCoordinates(
      latitude: Angle.fromDegrees(lat),
      longitude: Angle.fromDegrees(lon),
    );

    // 3. Compute spherical great-circle distance to South Pole (lat = -90.0):
    final deltaLatRad = (lat - (-90.0)).abs() * (math.pi / 180.0);
    final distanceToSouthPoleKm = deltaLatRad * 1737.4;

    final effectiveRadiusKm = lunarCoords.effectiveRadiusMeters / 1000.0;

    return SiteGeometricAnalysis(
      coordinates: lunarCoords,
      bodyFixedCartesian: cartesian,
      horizonBasis: basis,
      distanceToSouthPoleKm: distanceToSouthPoleKm,
      effectiveRadiusKm: effectiveRadiusKm,
    );
  }
}
