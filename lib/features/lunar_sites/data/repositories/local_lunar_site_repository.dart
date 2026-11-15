import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/lunar_sites/data/datasources/bundled_lunar_site_catalog.dart';
import 'package:luna_sight/features/lunar_sites/data/models/lunar_site_model.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';

/// Persistent file-backed and bundled implementation of [LunarSiteRepository].
///
/// Combines the immutable NASA Product 78 official catalog with dynamic,
/// locally persisted user-defined custom sites surviving app termination.
class LocalLunarSiteRepository implements LunarSiteRepository {
  /// Test-only or custom storage file injection override.
  final File? storageFileOverride;

  final List<LunarSite> _customSites = [];
  bool _isLoaded = false;
  File? _resolvedFile;

  LocalLunarSiteRepository({this.storageFileOverride}) {
    if (storageFileOverride != null) {
      _resolvedFile = storageFileOverride;
      _loadFromDiskSync();
    }
  }

  /// Resolves the persistent JSON file on disk.
  Future<File?> _resolveStorageFile() async {
    if (_resolvedFile != null) return _resolvedFile;
    if (storageFileOverride != null) {
      _resolvedFile = storageFileOverride;
      return _resolvedFile;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      // In test mode without storageFileOverride, keep persistence isolated in-memory
      return null;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      _resolvedFile = File(
        '${dir.path}${Platform.pathSeparator}custom_lunar_sites.json',
      );
      return _resolvedFile;
    } catch (e) {
      // In unit test or headless environments without path_provider mocks, fallback gracefully
      return null;
    }
  }

  void _loadFromDiskSync() {
    final file = _resolvedFile;
    if (file != null && file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            _customSites.clear();
            for (final item in decoded) {
              if (item is Map) {
                try {
                  final model = LunarSiteModel.fromJson(
                    Map<String, dynamic>.from(item),
                  );
                  _customSites.add(model);
                } catch (e) {
                  AppLogger.warning('Failed to parse persisted site: $e');
                }
              }
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Error reading persisted custom lunar sites: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
    _isLoaded = true;
  }

  /// Ensures persisted custom sites are loaded from disk.
  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    final file = await _resolveStorageFile();
    if (file != null && file.existsSync()) {
      _loadFromDiskSync();
    } else {
      _isLoaded = true;
    }
  }

  /// Persists the in-memory custom sites list to disk.
  Future<void> _persist() async {
    try {
      final file = await _resolveStorageFile();
      if (file != null) {
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        final listJson = _customSites.map((site) {
          if (site is LunarSiteModel) {
            return site.toJson();
          }
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
          ).toJson();
        }).toList();

        file.writeAsStringSync(jsonEncode(listJson), flush: true);
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to persist custom lunar sites: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Forces a reload from disk (primarily for test verification).
  Future<void> reload() async {
    _isLoaded = false;
    _loadFromDiskSync();
  }

  @override
  Future<List<LunarSite>> getAllSites() async {
    await _ensureLoaded();
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
    await _ensureLoaded();

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Site name cannot be empty.');
    }

    // Duplicate detection: reject if an official or custom site with the same name exists
    final all = await getAllSites();
    final nameLower = trimmedName.toLowerCase();
    final duplicate = all.any((s) => s.name.trim().toLowerCase() == nameLower);
    if (duplicate) {
      throw ArgumentError(
        'A landing site named "$trimmedName" already exists. Please choose a distinct name.',
      );
    }

    final latErr = LunarCoordinates.validateLatitude(coordinates.latitude);
    if (latErr != null) throw ArgumentError(latErr);

    final lonErr = LunarCoordinates.validateLongitude(coordinates.longitude);
    if (lonErr != null) throw ArgumentError(lonErr);

    final altErr = LunarCoordinates.validateAltitude(
      coordinates.altitudeMeters,
    );
    if (altErr != null) throw ArgumentError(altErr);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'custom_site_$timestamp';
    final siteCode = 'USR-${_customSites.length + 1}';

    final customSite = LunarSiteModel(
      id: id,
      name: trimmedName,
      siteCode: siteCode,
      classification: SiteClassification.userDefined,
      coordinates: coordinates,
      sourceId: 'USER_DEFINED_COORDINATES',
      sourceOrganization: 'User Defined',
      sourceUrl: null,
      citation: 'Manual operator input via LunaSight Interactive Polar Map.',
      description: description?.trim().isNotEmpty == true
          ? description!.trim()
          : 'User-specified selenographic coordinates for targeted surface exploration analysis.',
      relatedProductIds: const [],
    );

    _customSites.add(customSite);
    await _persist();
    return customSite;
  }

  @override
  Future<bool> deleteCustomSite(String id) async {
    await _ensureLoaded();
    final index = _customSites.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _customSites.removeAt(index);
      await _persist();
      return true;
    }
    return false;
  }
}
