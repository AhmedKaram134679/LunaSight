import 'package:flutter/foundation.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';

/// Classification of a lunar geographical area or site.
enum SiteClassification {
  /// Regions explicitly identified in NASA documentation as surrounding high-priority landing sites (e.g., Sites 1, 4, 7, 11).
  highPriorityLandingSiteRegion,

  /// General regional dataset or region of interest cataloged in NASA planetary geodesy archives (Product 78).
  nasaCatalogRegion,

  /// Custom coordinate location or point of interest specified by the user.
  userDefined,
}

/// Domain entity representing a lunar candidate site, reference region, or custom point of interest.
///
/// Grounded strictly in verified planetary geodesy metadata or explicit user input.
/// Never fabricates missing coordinates or scientific parameters.
@immutable
class LunarSite {
  /// Unique identifier (e.g., 'site_01', 'haworth_region', 'custom_1700000000').
  final String id;

  /// Official or primary display name (e.g., 'Connecting Ridge', 'Haworth Crater Region').
  final String name;

  /// Official short code or designator (e.g., 'Site01', 'LM1', 'SL2').
  final String siteCode;

  /// Classification of the site.
  final SiteClassification classification;

  /// Selenographic point coordinates.
  ///
  /// Null if coordinates are not published as a single point in the official source
  /// (e.g. region-of-interest footprints or bounding boxes).
  final LunarCoordinates? coordinates;

  /// Source catalog identifier or dataset reference (e.g., 'NASA_PGDA_PRODUCT_78').
  final String sourceId;

  /// Originating organization or publisher (e.g., 'NASA GSFC PGDA', 'User Defined').
  final String sourceOrganization;

  /// Authoritative documentation or catalog URL.
  final Uri? sourceUrl;

  /// Formal scientific or data citation.
  final String citation;

  /// Detailed descriptive text regarding features, morphology, or exploration context.
  final String description;

  /// Associated NASA product identifiers (e.g. ['ldem_87s_5mpp']).
  final List<String> relatedProductIds;

  const LunarSite({
    required this.id,
    required this.name,
    required this.siteCode,
    required this.classification,
    this.coordinates,
    required this.sourceId,
    required this.sourceOrganization,
    this.sourceUrl,
    required this.citation,
    required this.description,
    this.relatedProductIds = const [],
  });

  /// Whether valid selenographic coordinates are available for this site.
  bool get hasCoordinates => coordinates != null;

  /// Returns a copy of this site with updated fields.
  LunarSite copyWith({
    String? id,
    String? name,
    String? siteCode,
    SiteClassification? classification,
    LunarCoordinates? coordinates,
    String? sourceId,
    String? sourceOrganization,
    Uri? sourceUrl,
    String? citation,
    String? description,
    List<String>? relatedProductIds,
  }) {
    return LunarSite(
      id: id ?? this.id,
      name: name ?? this.name,
      siteCode: siteCode ?? this.siteCode,
      classification: classification ?? this.classification,
      coordinates: coordinates ?? this.coordinates,
      sourceId: sourceId ?? this.sourceId,
      sourceOrganization: sourceOrganization ?? this.sourceOrganization,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      citation: citation ?? this.citation,
      description: description ?? this.description,
      relatedProductIds: relatedProductIds ?? this.relatedProductIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarSite && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LunarSite($id, $name, $siteCode, $classification)';
}
