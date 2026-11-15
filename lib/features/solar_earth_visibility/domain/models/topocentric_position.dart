import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/astronomical_time.dart';

/// Topocentric spherical and Cartesian coordinates of a target celestial body
/// relative to a lunar surface observer in the local SEZ horizon system.
class TopocentricPosition {
  /// Local azimuth measured clockwise from true North ($[0^\circ, 360^\circ)$).
  /// Null if the target is directly overhead (Zenith) or directly below (Nadir) where horizontal range is zero.
  final Angle? azimuth;

  /// Local elevation angle (altitude) above the horizontal plane ($[-90^\circ, +90^\circ]$).
  final Angle elevation;

  /// Slant range (Euclidean distance) from observer to target in meters.
  final double slantRangeMeters;

  /// Horizontal ground range in meters: $H = \sqrt{S^2 + E^2}$.
  final double horizontalRangeMeters;

  /// South component in meters ($S = -\boldsymbol{\rho} \cdot \hat{\mathbf{u}}_N$).
  final double southMeters;

  /// East component in meters ($E = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_E$).
  final double eastMeters;

  /// Zenith component in meters ($Z = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_Z$).
  final double zenithMeters;

  /// The observation epoch of this topocentric state.
  final AstronomicalTime epoch;

  /// The reference frame of the underlying position vectors (`MOON_ME_DE421`).
  final ReferenceFrameId frame;

  const TopocentricPosition({
    required this.azimuth,
    required this.elevation,
    required this.slantRangeMeters,
    required this.horizontalRangeMeters,
    required this.southMeters,
    required this.eastMeters,
    required this.zenithMeters,
    required this.epoch,
    required this.frame,
  });

  /// Whether the azimuth is mathematically defined (true unless target is strictly at Zenith/Nadir).
  bool get hasDefinedAzimuth => azimuth != null;

  @override
  String toString() {
    final azStr = azimuth != null
        ? '${azimuth!.inDegrees.toStringAsFixed(3)}°'
        : 'UNDEFINED';
    return 'TopocentricPosition(Az: $azStr, El: ${elevation.inDegrees.toStringAsFixed(3)}°, Range: ${(slantRangeMeters / 1000.0).toStringAsFixed(1)}km)';
  }
}
