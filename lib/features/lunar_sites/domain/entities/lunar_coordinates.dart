import 'package:flutter/foundation.dart';

/// Longitude convention describing the direction in which longitude values increase.
enum LongitudeConvention {
  /// Longitude increases positively towards the East (standard IAU / planetary convention).
  /// Accepted domain range: [-180.0°, +180.0°] or [0.0°, +360.0°].
  eastPositive,

  /// Longitude increases positively towards the West.
  /// Accepted domain range: [-180.0°, +180.0°] or [0.0°, +360.0°].
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
/// All numeric values are strictly checked in both debug and release runtime modes:
/// - NaN and infinite values are rejected.
/// - Latitude is enforced within [-90.0°, +90.0°].
/// - Longitude is enforced within [-180.0°, +360.0°].
/// - Altitude, if specified, must be a finite numeric value representing surface height in meters
///   relative to the mean lunar spherical datum (radius = 1,737,400 meters).
@immutable
class LunarCoordinates {
  /// Selenographic latitude in degrees. Must be finite and within [-90.0, +90.0].
  final double latitude;

  /// Selenographic longitude in degrees. Must be finite and within [-180.0, +360.0].
  final double longitude;

  /// The directional convention applied to [longitude].
  final LongitudeConvention longitudeConvention;

  /// The origin and authority for this coordinate pair.
  final CoordinateProvenance provenance;

  /// Optional surface elevation / altitude in meters relative to lunar mean radius (1,737.4 km).
  final double? altitudeMeters;

  LunarCoordinates({
    required this.latitude,
    required this.longitude,
    this.longitudeConvention = LongitudeConvention.eastPositive,
    this.provenance = CoordinateProvenance.userEntered,
    this.altitudeMeters,
  }) {
    final latErr = validateLatitude(latitude);
    if (latErr != null) {
      throw ArgumentError(latErr);
    }
    final lonErr = validateLongitude(longitude);
    if (lonErr != null) {
      throw ArgumentError(lonErr);
    }
    final altErr = validateAltitude(altitudeMeters);
    if (altErr != null) {
      throw ArgumentError(altErr);
    }
  }

  /// Validates whether a given latitude value is finite and within valid bounds.
  static String? validateLatitude(double? lat) {
    if (lat == null) return 'Latitude is required';
    if (lat.isNaN || lat.isInfinite) {
      return 'Latitude must be a finite number';
    }
    if (lat < -90.0 || lat > 90.0) {
      return 'Latitude must be between -90.0° and +90.0°';
    }
    return null;
  }

  /// Validates whether a given longitude value is finite and within valid bounds.
  static String? validateLongitude(double? lon) {
    if (lon == null) return 'Longitude is required';
    if (lon.isNaN || lon.isInfinite) {
      return 'Longitude must be a finite number';
    }
    if (lon < -180.0 || lon > 360.0) {
      return 'Longitude must be between -180.0° and +360.0°';
    }
    return null;
  }

  /// Validates whether an optional altitude value is finite.
  static String? validateAltitude(double? alt) {
    if (alt == null) return null;
    if (alt.isNaN || alt.isInfinite) {
      return 'Altitude must be a finite number';
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
    final rawLat = json['latitude'];
    final rawLon = json['longitude'];

    if (rawLat is! num || rawLon is! num) {
      throw const FormatException(
        'Latitude and longitude must be valid numeric values.',
      );
    }

    final lat = rawLat.toDouble();
    final lon = rawLon.toDouble();

    final latErr = validateLatitude(lat);
    if (latErr != null) throw FormatException(latErr);

    final lonErr = validateLongitude(lon);
    if (lonErr != null) throw FormatException(lonErr);

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

    final rawAlt = json['altitude_meters'];
    double? alt;
    if (rawAlt != null) {
      if (rawAlt is! num) {
        throw const FormatException('Altitude must be a valid numeric value.');
      }
      alt = rawAlt.toDouble();
      final altErr = validateAltitude(alt);
      if (altErr != null) throw FormatException(altErr);
    }

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
