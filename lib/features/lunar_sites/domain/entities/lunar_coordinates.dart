import 'package:flutter/foundation.dart';

/// Longitude convention describing the direction in which longitude values increase.
enum LongitudeConvention {
  /// Longitude increases positively towards the East (standard IAU / planetary convention).
  eastPositive,

  /// Longitude increases positively towards the West.
  westPositive,

  /// Longitude convention is unspecified or undetermined from source metadata.
  unknown,
}

/// Provenance and origin of lunar coordinate values.
enum CoordinateProvenance {
  /// Published directly in authoritative NASA documentation or peer-reviewed literature.
  nasaPublished,

  /// Entered or defined manually by the user/operator.
  userEntered,
}

/// Selenographic coordinate representation with strict validation and provenance tracking.
///
/// Encapsulates latitude, longitude, convention, provenance, and optional altitude.
@immutable
class LunarCoordinates {
  /// Selenographic latitude in degrees. Must be within [-90.0, +90.0].
  final double latitude;

  /// Selenographic longitude in degrees.
  final double longitude;

  /// The directional convention applied to [longitude].
  final LongitudeConvention longitudeConvention;

  /// The origin and authority for this coordinate pair.
  final CoordinateProvenance provenance;

  /// Optional surface elevation / altitude in meters relative to lunar reference radius.
  final double? altitudeMeters;

  const LunarCoordinates({
    required this.latitude,
    required this.longitude,
    this.longitudeConvention = LongitudeConvention.eastPositive,
    this.provenance = CoordinateProvenance.userEntered,
    this.altitudeMeters,
  }) : assert(
         latitude >= -90.0 && latitude <= 90.0,
         'Latitude must be between -90.0 and +90.0 degrees.',
       );

  /// Validates whether a given latitude and longitude value pair is within valid bounds.
  static String? validateLatitude(double? lat) {
    if (lat == null) return 'Latitude is required';
    if (lat < -90.0 || lat > 90.0) {
      return 'Latitude must be between -90.0° and +90.0°';
    }
    return null;
  }

  /// Validates whether a given longitude value is valid.
  static String? validateLongitude(double? lon) {
    if (lon == null) return 'Longitude is required';
    if (lon < -180.0 || lon > 360.0) {
      return 'Longitude must be between -180.0° and +360.0°';
    }
    return null;
  }

  /// Formatted string representation for human-readable selenographic display.
  String get formattedCoordinates {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final latAbs = latitude.abs().toStringAsFixed(4);

    final lonDir = switch (longitudeConvention) {
      LongitudeConvention.eastPositive => longitude >= 0 ? 'E' : 'W',
      LongitudeConvention.westPositive => longitude >= 0 ? 'W' : 'E',
      LongitudeConvention.unknown => '',
    };
    final lonAbs = longitude.abs().toStringAsFixed(4);

    return '$latAbs° $latDir, $lonAbs° $lonDir'.trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'longitude_convention': longitudeConvention.name,
      'provenance': provenance.name,
      if (altitudeMeters != null) 'altitude_meters': altitudeMeters,
    };
  }

  factory LunarCoordinates.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num).toDouble();
    final lon = (json['longitude'] as num).toDouble();

    final convName = json['longitude_convention'] as String?;
    final conv = LongitudeConvention.values.firstWhere(
      (e) => e.name == convName,
      orElse: () => LongitudeConvention.unknown,
    );

    final provName = json['provenance'] as String?;
    final prov = CoordinateProvenance.values.firstWhere(
      (e) => e.name == provName,
      orElse: () => CoordinateProvenance.userEntered,
    );

    final alt = (json['altitude_meters'] as num?)?.toDouble();

    return LunarCoordinates(
      latitude: lat,
      longitude: lon,
      longitudeConvention: conv,
      provenance: prov,
      altitudeMeters: alt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarCoordinates &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          longitudeConvention == other.longitudeConvention &&
          provenance == other.provenance &&
          altitudeMeters == other.altitudeMeters;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    longitudeConvention,
    provenance,
    altitudeMeters,
  );

  @override
  String toString() =>
      'LunarCoordinates($latitude, $longitude, $longitudeConvention, $provenance)';
}
