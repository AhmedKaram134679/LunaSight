import 'dart:async';

import 'package:luna_sight/features/lunar_sites/data/datasources/bundled_lunar_site_catalog.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';

/// In-memory and bundled implementation of [LunarSiteRepository].
///
/// Combines the immutable NASA Product 78 official catalog with dynamic,
/// session-managed user-defined custom sites.
class LocalLunarSiteRepository implements LunarSiteRepository {
  final List<LunarSite> _customSites = [];

  LocalLunarSiteRepository();

  @override
  Future<List<LunarSite>> getAllSites() async {
    return [...BundledLunarSiteCatalog.officialSites, ..._customSites];
  }

  @override
  Future<LunarSite?> getSiteById(String id) async {
    final all = await getAllSites();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LunarSite>> searchSites(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return getAllSites();
    }

    final all = await getAllSites();
    return all.where((site) {
      final matchName = site.name.toLowerCase().contains(trimmed);
      final matchCode = site.siteCode.toLowerCase().contains(trimmed);
      final matchDesc = site.description.toLowerCase().contains(trimmed);
      final matchOrg = site.sourceOrganization.toLowerCase().contains(trimmed);
      final matchId = site.id.toLowerCase().contains(trimmed);

      return matchName || matchCode || matchDesc || matchOrg || matchId;
    }).toList();
  }

  @override
  Future<List<LunarSite>> filterSites({
    SiteClassification? classification,
    String? sourceOrganization,
  }) async {
    final all = await getAllSites();
    return all.where((site) {
      if (classification != null && site.classification != classification) {
        return false;
      }
      if (sourceOrganization != null &&
          site.sourceOrganization.toLowerCase() !=
              sourceOrganization.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<LunarSite> addCustomSite({
    required String name,
    required LunarCoordinates coordinates,
    String? description,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'custom_site_$timestamp';
    final siteCode = 'USR-${_customSites.length + 1}';

    final customSite = LunarSite(
      id: id,
      name: name.trim(),
      siteCode: siteCode,
      classification: SiteClassification.userDefined,
      coordinates: coordinates,
      sourceId: 'USER_DEFINED_COORDINATES',
      sourceOrganization: 'User Defined',
      sourceUrl: null,
      citation: 'Manual operator input via LunaSight Custom Site Entry.',
      description: description?.trim().isNotEmpty == true
          ? description!.trim()
          : 'User-specified selenographic coordinates for targeted surface exploration analysis.',
      relatedProductIds: const [],
    );

    _customSites.add(customSite);
    return customSite;
  }

  @override
  Future<bool> deleteCustomSite(String id) async {
    final index = _customSites.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _customSites.removeAt(index);
      return true;
    }
    return false;
  }
}
