import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_coordinate_transformer.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';

/// Immutable domain value object representing the output of a forward lunar coordinate
/// transformation paired with its complete source-coordinate provenance and reference geometry.
///
/// Satisfies the Phase 04C provenance integrity contract:
/// - Guarantees provenance truthfulness: instances can ONLY be instantiated by computing
///   the forward Cartesian transformation directly from [sourceCoordinates] via the trusted
///   [LunarCoordinateTransformer]. Callers cannot independently supply an arbitrary or fabricated
///   [FramedVector3], preventing any same-frame or cross-frame provenance inconsistency.
/// - Preserves the resulting [framedVector] ([FramedVector3]) with zero modifications to Phase 04B.
/// - Retains full diagnostic and scientific traceability to the original [sourceCoordinates] ([LunarGeographicCoordinates]).
/// - Exposes direct accessors for source latitude, longitude, conventions, height datum, and reference surface dimensions.
@immutable
class LunarCoordinateTransformationResult {
  /// The resulting Cartesian body-fixed position vector with origin, frame, and units.
  final FramedVector3 framedVector;

  /// The immutable source geographic coordinates and reference datum from which [framedVector] was computed.
  final LunarGeographicCoordinates sourceCoordinates;

  /// Private constructor enforcing provenance integrity.
  ///
  /// External callers cannot independently inject arbitrary vectors and unrelated source coordinates.
  const LunarCoordinateTransformationResult._({
    required this.framedVector,
    required this.sourceCoordinates,
  });

  /// Factory constructor that guarantees provenance integrity by directly deriving
  /// the [FramedVector3] from [sourceCoordinates] using [transformer].
  ///
  /// This ensures that [framedVector] is mathematically and geometrically bound to
  /// [sourceCoordinates], making it impossible for callers to pair valid geographic
  /// coordinates with an arbitrary, fabricated, or inconsistent Cartesian vector.
  factory LunarCoordinateTransformationResult.fromCoordinates(
    LunarGeographicCoordinates sourceCoordinates, {
    LunarCoordinateTransformer transformer = const LunarCoordinateTransformer(),
  }) {
    final framedVector = transformer.toBodyFixedCartesian(sourceCoordinates);
    return LunarCoordinateTransformationResult._(
      framedVector: framedVector,
      sourceCoordinates: sourceCoordinates,
    );
  }

  /// Package-private factory method allowing an authorized [LunarCoordinateTransformer]
  /// to construct a result from precomputed components after verifying mathematical consistency.
  ///
  /// Enforces that [framedVector] must match the reference frame, origin, and units of
  /// the transformation contract, and that its components match the transformation of [sourceCoordinates].
  @internal
  factory LunarCoordinateTransformationResult.fromTransformation({
    required FramedVector3 framedVector,
    required LunarGeographicCoordinates sourceCoordinates,
  }) {
    if (framedVector.frame != sourceCoordinates.frame) {
      throw ArgumentError(
        'Provenance frame mismatch: framedVector frame (${framedVector.frame.name}) '
        'does not match sourceCoordinates frame (${sourceCoordinates.frame.name}).',
      );
    }
    // Verify that framedVector is genuinely the transformation of sourceCoordinates
    const transformer = LunarCoordinateTransformer();
    final expectedVector = transformer.toBodyFixedCartesian(sourceCoordinates);
    if (framedVector != expectedVector) {
      throw ArgumentError(
        'Provenance integrity violation: framedVector (${framedVector.vector}) '
        'does not match the Cartesian coordinates computed from sourceCoordinates (${expectedVector.vector}).',
      );
    }
    return LunarCoordinateTransformationResult._(
      framedVector: framedVector,
      sourceCoordinates: sourceCoordinates,
    );
  }

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
