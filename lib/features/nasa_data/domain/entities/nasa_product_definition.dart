import 'package:flutter/foundation.dart';

/// Pixel registration convention used in lunar raster products.
enum PixelRegistration {
  /// Coordinates correspond to the centers of the pixels (Generic Mapping Tools convention).
  pixelRegistered,

  /// Coordinates correspond to the corners/grid lines of pixels.
  gridRegistered,

  /// Unknown or unspecified registration convention.
  unknown,
}

/// Official published metadata for an authorized NASA planetary science dataset.
///
/// Immutable representation of the official product specification from NASA GSFC PGDA.
/// Grounded strictly in officially published metadata (https://pgda.gsfc.nasa.gov/products/81).
@immutable
class NasaProductDefinition {
  /// Unique identifier (e.g., 'ldem_87s_5mpp').
  final String identifier;

  /// Official title of the dataset product.
  final String title;

  /// Responsible NASA institution or laboratory.
  final String sourceOrganization;

  /// Primary researcher / author attribution.
  final String? author;

  /// Official product catalog or documentation URL.
  final Uri officialProductPageUrl;

  /// Resolved direct asset download URL from official NASA source.
  final Uri officialAssetUrl;

  /// File format (e.g., 'GeoTIFF').
  final String format;

  /// Officially published file size description (e.g. '3.3GB' or '~3.3 GB').
  final String? publishedSizeDescription;

  /// Expected file size in bytes, when officially published or established from authoritative source.
  /// Null if not published as an exact byte count in documentation.
  final int? publishedSizeBytes;

  /// Spatial resolution numeric value (e.g. 5.0).
  final double spatialResolution;

  /// Unit of spatial resolution (e.g., 'm/pixel').
  final String spatialResolutionUnit;

  /// Description of horizontal coordinate reference system.
  final String horizontalCoordinateSystem;

  /// Unit of horizontal coordinates (e.g., 'meters').
  final String horizontalCoordinateUnit;

  /// Planetary reference frame (e.g., 'MOON_ME').
  final String referenceFrame;

  /// Associated planetary ephemeris (e.g., 'DE421').
  final String ephemerisAssociation;

  /// Pixel registration convention.
  final PixelRegistration pixelRegistration;

  /// Elevation measurement description (e.g., 'surface height Z').
  final String elevationMeasurement;

  /// Elevation unit (e.g., 'meters').
  final String elevationUnit;

  /// Geographic / selenographic coverage description.
  final String coverageDescription;

  /// Processing and interpolation notes from the publisher.
  final String processingNotes;

  /// Primary scientific citation for the product.
  final String citation;

  /// Published or updated date from official NASA metadata, if explicitly stated in documentation.
  final DateTime? publicationDate;

  const NasaProductDefinition({
    required this.identifier,
    required this.title,
    required this.sourceOrganization,
    this.author,
    required this.officialProductPageUrl,
    required this.officialAssetUrl,
    required this.format,
    this.publishedSizeDescription,
    this.publishedSizeBytes,
    required this.spatialResolution,
    required this.spatialResolutionUnit,
    required this.horizontalCoordinateSystem,
    required this.horizontalCoordinateUnit,
    required this.referenceFrame,
    required this.ephemerisAssociation,
    required this.pixelRegistration,
    required this.elevationMeasurement,
    required this.elevationUnit,
    required this.coverageDescription,
    required this.processingNotes,
    required this.citation,
    this.publicationDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NasaProductDefinition &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => 'NasaProductDefinition($identifier, $title)';
}
