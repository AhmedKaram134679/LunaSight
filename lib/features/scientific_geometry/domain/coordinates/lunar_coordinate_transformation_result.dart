import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';

/// Immutable domain value object representing the output of a forward lunar coordinate
/// transformation paired with its complete source-coordinate provenance and reference geometry.
///
/// Satisfies the Phase 04C provenance contract:
/// - Preserves the resulting [framedVector] ([FramedVector3]) with zero modifications to Phase 04B.
/// - Retains full diagnostic and scientific traceability to the original [sourceCoordinates] ([LunarGeographicCoordinates]).
/// - Exposes direct accessors for source latitude, longitude, conventions, height datum, and reference surface dimensions.
@immutable
class LunarCoordinateTransformationResult {
  /// The resulting Cartesian body-fixed position vector with origin, frame, and units.
  final FramedVector3 framedVector;

  /// The immutable source geographic coordinates and reference datum from which [framedVector] was computed.
  final LunarGeographicCoordinates sourceCoordinates;

  const LunarCoordinateTransformationResult({
    required this.framedVector,
    required this.sourceCoordinates,
  });

  /// The original source latitude.
  Angle get sourceLatitude => sourceCoordinates.latitude;

  /// The original source latitude type (`planetocentric` or `planetodetic`).
  LatitudeType get sourceLatitudeType => sourceCoordinates.latitudeType;

  /// The original source longitude.
  Angle get sourceLongitude => sourceCoordinates.longitude;

  /// The original source longitude direction (`eastPositive` or `westPositive`).
  LongitudeDirection get sourceLongitudeDirection =>
      sourceCoordinates.longitudeDirection;

  /// The original declared longitude domain (`symmetric180` or `positive360`).
  LongitudeDomain get sourceLongitudeDomain =>
      sourceCoordinates.longitudeDomain;

  /// The original signed radial height in meters.
  double get sourceHeightMeters => sourceCoordinates.heightMeters;

  /// The original height reference datum.
  HeightReferenceId get sourceHeightReference =>
      sourceCoordinates.heightReference;

  /// The geometric reference surface against which height was defined.
  ReferenceSurfaceId get sourceReferenceSurface =>
      sourceCoordinates.referenceSurface;

  /// The reference frame realization of the coordinates and resulting vector.
  ReferenceFrameId get sourceFrame => sourceCoordinates.frame;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LunarCoordinateTransformationResult &&
          framedVector == other.framedVector &&
          sourceCoordinates == other.sourceCoordinates);

  @override
  int get hashCode => Object.hash(framedVector, sourceCoordinates);

  @override
  String toString() =>
      'LunarCoordinateTransformationResult(vector: ${framedVector.vector}, frame: ${framedVector.frame.name}, source: $sourceCoordinates)';
}
