import 'package:flutter/foundation.dart';

/// Strongly typed value object representing the physical coordinate origin.
///
/// Keeps coordinate origins strictly distinct from reference frames, preventing
/// conceptual conflation between axis orientations and coordinate centers.
@immutable
class CoordinateOriginId {
  /// Descriptive name of the coordinate origin.
  final String name;

  /// Optional NAIF SPICE body integer identifier.
  final int? naifBodyId;

  /// Optional topocentric site or station identifier.
  final String? siteIdentifier;

  const CoordinateOriginId({
    required this.name,
    this.naifBodyId,
    this.siteIdentifier,
  });

  /// Solar System Barycenter (SSB), NAIF ID 0.
  static const CoordinateOriginId ssb = CoordinateOriginId(
    name: 'SOLAR_SYSTEM_BARYCENTER',
    naifBodyId: 0,
  );

  /// Moon Center of Mass, NAIF ID 301.
  static const CoordinateOriginId moonCenterOfMass = CoordinateOriginId(
    name: 'MOON_CENTER_OF_MASS',
    naifBodyId: 301,
  );

  /// Earth Center of Mass, NAIF ID 399.
  static const CoordinateOriginId earthCenterOfMass = CoordinateOriginId(
    name: 'EARTH_CENTER_OF_MASS',
    naifBodyId: 399,
  );

  /// Factory creating a topocentric lunar surface site origin.
  factory CoordinateOriginId.topocentricSite(String siteId) {
    return CoordinateOriginId(
      name: 'TOPOCENTRIC_LUNAR_SITE',
      siteIdentifier: siteId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoordinateOriginId &&
          name == other.name &&
          naifBodyId == other.naifBodyId &&
          siteIdentifier == other.siteIdentifier);

  @override
  int get hashCode => Object.hash(name, naifBodyId, siteIdentifier);

  @override
  String toString() {
    final extra = [
      if (naifBodyId != null) 'naifBodyId: $naifBodyId',
      if (siteIdentifier != null) 'siteId: $siteIdentifier',
    ].join(', ');
    return extra.isEmpty
        ? 'CoordinateOriginId($name)'
        : 'CoordinateOriginId($name, $extra)';
  }
}
