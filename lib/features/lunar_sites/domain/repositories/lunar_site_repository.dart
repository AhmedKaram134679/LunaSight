import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';

/// Pure domain contract for accessing lunar site catalogs and managing user sites.
///
/// Abstract repository decoupling presentation and domain consumers from
/// bundled datasets, remote APIs, and persistence mechanisms.
abstract class LunarSiteRepository {
  /// Retrieves all lunar sites (both bundled NASA sites and user-defined sites).
  Future<List<LunarSite>> getAllSites();

  /// Retrieves a specific site by its unique [id].
  Future<LunarSite?> getSiteById(String id);

  /// Searches sites matching [query] across name, code, description, and source.
  Future<List<LunarSite>> searchSites(String query);

  /// Filters sites by optional [classification] and [sourceOrganization].
  Future<List<LunarSite>> filterSites({
    SiteClassification? classification,
    String? sourceOrganization,
  });

  /// Adds a new user-defined custom site with coordinates.
  Future<LunarSite> addCustomSite({
    required String name,
    required LunarCoordinates coordinates,
    String? description,
  });

  /// Deletes a user-defined site by [id]. Cannot delete bundled NASA catalog sites.
  Future<bool> deleteCustomSite(String id);
}
