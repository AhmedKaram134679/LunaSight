import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/custom_site_entry_page.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/lunar_site_details_page.dart';
import 'package:luna_sight/features/lunar_sites/presentation/widgets/lunar_site_card.dart';
import 'package:luna_sight/features/nasa_data/nasa_data.dart';

/// Interactive Lunar Site Explorer page featuring search, classification filtering,
/// responsive grid/list presentation, and custom site creation.
class LunarSiteExplorerPage extends StatefulWidget {
  final LunarSiteRepository repository;
  final NasaDataRepository? nasaDataRepository;

  const LunarSiteExplorerPage({
    super.key,
    required this.repository,
    this.nasaDataRepository,
  });

  @override
  State<LunarSiteExplorerPage> createState() => _LunarSiteExplorerPageState();
}

class _LunarSiteExplorerPageState extends State<LunarSiteExplorerPage> {
  final _searchController = TextEditingController();
  List<LunarSite> _allSites = [];
  List<LunarSite> _filteredSites = [];
  bool _isLoading = true;
  String? _errorMessage;

  SiteClassification? _selectedClassification;
  bool _filterHasCoordinatesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sites = await widget.repository.getAllSites();
      if (!mounted) return;
      setState(() {
        _allSites = sites;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load lunar sites catalog: $e';
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredSites = _allSites.where((site) {
        if (_selectedClassification != null &&
            site.classification != _selectedClassification) {
          return false;
        }

        if (_filterHasCoordinatesOnly && !site.hasCoordinates) {
          return false;
        }

        if (query.isNotEmpty) {
          final matchName = site.name.toLowerCase().contains(query);
          final matchCode = site.siteCode.toLowerCase().contains(query);
          final matchDesc = site.description.toLowerCase().contains(query);
          final matchOrg = site.sourceOrganization.toLowerCase().contains(
            query,
          );
          if (!matchName && !matchCode && !matchDesc && !matchOrg) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _navigateToDetails(LunarSite site) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LunarSiteDetailsPage(
          site: site,
          nasaDataRepository: widget.nasaDataRepository,
        ),
      ),
    );
  }

  Future<void> _navigateToCustomEntry() async {
    final result = await Navigator.of(context).push<LunarSite?>(
      MaterialPageRoute<LunarSite?>(
        builder: (_) => CustomSiteEntryPage(repository: widget.repository),
      ),
    );

    if (result != null) {
      await _loadSites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom site "${result.name}" added successfully.'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ResponsiveLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lunar Site Explorer'),
        actions: [
          IconButton(
            tooltip: 'Add Custom Site',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _navigateToCustomEntry,
          ),
          const SizedBox(width: AppConstants.space8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search and Filters Bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact
                        ? AppConstants.space16
                        : AppConstants.space24,
                    vertical: AppConstants.space12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('lunar_site_search_field'),
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        decoration: InputDecoration(
                          hintText:
                              'Search by site name, code, or description...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              key: const Key('filter_all'),
                              label: const Text('All Sites'),
                              selected: _selectedClassification == null,
                              onSelected: (_) {
                                setState(() => _selectedClassification = null);
                                _applyFilters();
                              },
                            ),
                            const SizedBox(width: AppConstants.space8),
                            FilterChip(
                              key: const Key('filter_landing_regions'),
                              label: const Text('Landing Site Regions'),
                              selected:
                                  _selectedClassification ==
                                  SiteClassification
                                      .highPriorityLandingSiteRegion,
                              onSelected: (val) {
                                setState(() {
                                  _selectedClassification = val
                                      ? SiteClassification
                                            .highPriorityLandingSiteRegion
                                      : null;
                                });
                                _applyFilters();
                              },
                            ),
                            const SizedBox(width: AppConstants.space8),
                            FilterChip(
                              key: const Key('filter_catalog_regions'),
                              label: const Text('NASA Catalog Regions'),
                              selected:
                                  _selectedClassification ==
                                  SiteClassification.nasaCatalogRegion,
                              onSelected: (val) {
                                setState(() {
                                  _selectedClassification = val
                                      ? SiteClassification.nasaCatalogRegion
                                      : null;
                                });
                                _applyFilters();
                              },
                            ),
                            const SizedBox(width: AppConstants.space8),
                            FilterChip(
                              key: const Key('filter_user_defined'),
                              label: const Text('User Defined'),
                              selected:
                                  _selectedClassification ==
                                  SiteClassification.userDefined,
                              onSelected: (val) {
                                setState(() {
                                  _selectedClassification = val
                                      ? SiteClassification.userDefined
                                      : null;
                                });
                                _applyFilters();
                              },
                            ),
                            const SizedBox(width: AppConstants.space8),
                            FilterChip(
                              key: const Key('filter_has_coordinates'),
                              avatar: const Icon(
                                Icons.pin_drop_outlined,
                                size: 16,
                              ),
                              label: const Text('Coordinates Only'),
                              selected: _filterHasCoordinatesOnly,
                              onSelected: (val) {
                                setState(() => _filterHasCoordinatesOnly = val);
                                _applyFilters();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Site Count Summary
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact
                        ? AppConstants.space16
                        : AppConstants.space24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${_filteredSites.length} of ${_allSites.length} regions',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'NASA PGDA Product 78 (5 m/pix)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space8),

                // Body content
                Expanded(child: _buildBody(context, isCompact)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_custom_site_fab'),
        onPressed: _navigateToCustomEntry,
        icon: const Icon(Icons.add),
        label: const Text('New Custom Site'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isCompact) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppConstants.space16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: AppConstants.space16),
              OutlinedButton(onPressed: _loadSites, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_filteredSites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.travel_explore_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppConstants.space16),
              Text(
                'No lunar sites match your query',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppConstants.space8),
              Text(
                'Try adjusting search keywords or clearing active classification filters.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppConstants.space16 : AppConstants.space24,
        vertical: AppConstants.space8,
      ),
      itemCount: _filteredSites.length,
      itemBuilder: (context, index) {
        final site = _filteredSites[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.space12),
          child: LunarSiteCard(
            site: site,
            onTap: () => _navigateToDetails(site),
          ),
        );
      },
    );
  }
}
