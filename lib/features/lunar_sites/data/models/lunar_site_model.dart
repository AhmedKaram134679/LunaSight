import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';

/// Data Transfer Object / Model for [LunarSite] supporting JSON serialization.
class LunarSiteModel extends LunarSite {
  const LunarSiteModel({
    required super.id,
    required super.name,
    required super.siteCode,
    required super.classification,
    super.coordinates,
    required super.sourceId,
    required super.sourceOrganization,
    super.sourceUrl,
    required super.citation,
    required super.description,
    super.relatedProductIds = const [],
  });

  factory LunarSiteModel.fromJson(Map<String, dynamic> json) {
    final classifName = json['classification'] as String?;
    final classif = SiteClassification.values.firstWhere(
      (c) => c.name == classifName,
      orElse: () => SiteClassification.referenceRegion,
    );

    final rawCoordinates = json['coordinates'] as Map<String, dynamic>?;
    final coordinates = rawCoordinates != null
        ? LunarCoordinates.fromJson(rawCoordinates)
        : null;

    final rawUrl = json['source_url'] as String?;
    final sourceUrl = rawUrl != null ? Uri.tryParse(rawUrl) : null;

    final rawRelated = json['related_product_ids'] as List<dynamic>?;
    final related = rawRelated != null
        ? rawRelated.map((e) => e.toString()).toList()
        : const <String>[];

    return LunarSiteModel(
      id: json['id'] as String,
      name: json['name'] as String,
      siteCode: json['site_code'] as String,
      classification: classif,
      coordinates: coordinates,
      sourceId: json['source_id'] as String,
      sourceOrganization: json['source_organization'] as String,
      sourceUrl: sourceUrl,
      citation: json['citation'] as String,
      description: json['description'] as String,
      relatedProductIds: related,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'site_code': siteCode,
      'classification': classification.name,
      if (coordinates != null) 'coordinates': coordinates!.toJson(),
      'source_id': sourceId,
      'source_organization': sourceOrganization,
      if (sourceUrl != null) 'source_url': sourceUrl.toString(),
      'citation': citation,
      'description': description,
      'related_product_ids': relatedProductIds,
    };
  }

  factory LunarSiteModel.fromEntity(LunarSite site) {
    return LunarSiteModel(
      id: site.id,
      name: site.name,
      siteCode: site.siteCode,
      classification: site.classification,
      coordinates: site.coordinates,
      sourceId: site.sourceId,
      sourceOrganization: site.sourceOrganization,
      sourceUrl: site.sourceUrl,
      citation: site.citation,
      description: site.description,
      relatedProductIds: site.relatedProductIds,
    );
  }
}
