import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/site_scientific_analysis_service.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/lunar_site_details_page.dart';

/// Side-by-side scientific comparison of candidate lunar landing sites.
///
/// Strictly compares verified observational, geodetic, and topographical properties.
/// In adherence to scientific data integrity, composite suitability scores, simulated illumination
/// percentages, and unverified safety rankings are strictly omitted.
class SiteComparisonPage extends StatefulWidget {
  final LunarSiteRepository repository;
  final SiteScientificAnalysisService analysisService;

  const SiteComparisonPage({
    super.key,
    required this.repository,
    this.analysisService = const SiteScientificAnalysisService(),
  });

  @override
  State<SiteComparisonPage> createState() => _SiteComparisonPageState();
}

class _SiteComparisonPageState extends State<SiteComparisonPage> {
  List<LunarSite> _allSites = [];
  bool _isLoading = true;

  LunarSite? _siteA;
  LunarSite? _siteB;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);
    try {
      final sites = await widget.repository.getAllSites();
      if (!mounted) return;
      setState(() {
        _allSites = sites;
        if (sites.isNotEmpty) {
          _siteA = sites.firstWhere(
            (s) => s.siteCode == 'Site01',
            orElse: () => sites[0],
          );
          _siteB = sites.firstWhere(
            (s) => s.siteCode == 'Site04',
            orElse: () => sites.length > 1 ? sites[1] : sites[0],
          );
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ResponsiveLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Site Comparison')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact
                          ? AppConstants.space16
                          : AppConstants.space24,
                      vertical: AppConstants.space16,
                    ),
                    children: [
                      // Header Card
                      ScientificCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.compare_arrows_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: AppConstants.space8),
                                Text(
                                  'Candidate Site Comparison Matrix',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.space8),
                            Text(
                              'Evaluate selenographic coordinates, south pole proximity, and data readiness between candidate landing sites.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),

                      // Selectors Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildSiteDropdown(
                              label: 'Candidate Site A',
                              selectedSite: _siteA,
                              onChanged: (s) => setState(() => _siteA = s),
                            ),
                          ),
                          const SizedBox(width: AppConstants.space16),
                          Expanded(
                            child: _buildSiteDropdown(
                              label: 'Candidate Site B',
                              selectedSite: _siteB,
                              onChanged: (s) => setState(() => _siteB = s),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space16),

                      // Comparison Body
                      if (_siteA != null && _siteB != null) ...[
                        if (isCompact) ...[
                          _buildSingleSiteCard(_siteA!, 'Site A'),
                          const SizedBox(height: AppConstants.space16),
                          _buildSingleSiteCard(_siteB!, 'Site B'),
                        ] else ...[
                          _buildSideBySideComparison(_siteA!, _siteB!),
                        ],
                        const SizedBox(height: AppConstants.space16),
                      ],

                      // Scientific Integrity Policy Notice
                      ScientificCard(
                        backgroundColor: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppConstants.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scientific Integrity & Objectivity Policy',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'LunaSight compares only verified observational, geodetic, and topographical properties. Composite landing safety scores, illumination percentage predictions, and direct communication window calculations are strictly omitted in the absence of verified ephemeris and cached high-resolution DEM data.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSiteDropdown({
    required String label,
    required LunarSite? selectedSite,
    required ValueChanged<LunarSite?> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LunarSite>(
              isExpanded: true,
              value: selectedSite,
              items: _allSites.map((site) {
                return DropdownMenuItem<LunarSite>(
                  value: site,
                  child: Text(
                    '${site.siteCode}: ${site.name}',
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySideComparison(LunarSite a, LunarSite b) {
    final analysisA = widget.analysisService.analyzeSite(a);
    final analysisB = widget.analysisService.analyzeSite(b);

    return ScientificCard(
      child: Column(
        children: [
          _buildRow(
            'Classification',
            _formatClassification(a),
            _formatClassification(b),
          ),
          const Divider(),
          _buildRow(
            'Source Catalog',
            a.sourceOrganization,
            b.sourceOrganization,
          ),
          const Divider(),
          _buildRow(
            'Point Coordinates',
            a.hasCoordinates ? 'Available' : 'Null (Regional Footprint)',
            b.hasCoordinates ? 'Available' : 'Null (Regional Footprint)',
          ),
          const Divider(),
          _buildRow(
            'Latitude',
            a.coordinates != null
                ? '${a.coordinates!.latitude.toStringAsFixed(4)}°'
                : 'N/A',
            b.coordinates != null
                ? '${b.coordinates!.latitude.toStringAsFixed(4)}°'
                : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Longitude',
            a.coordinates != null
                ? '${a.coordinates!.longitude.toStringAsFixed(4)}°'
                : 'N/A',
            b.coordinates != null
                ? '${b.coordinates!.longitude.toStringAsFixed(4)}°'
                : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Distance to South Pole',
            analysisA != null
                ? analysisA.formattedDistanceToSouthPoleKm
                : 'N/A',
            analysisB != null
                ? analysisB.formattedDistanceToSouthPoleKm
                : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Body-Fixed Radius',
            analysisA != null ? analysisA.formattedEffectiveRadiusKm : 'N/A',
            analysisB != null ? analysisB.formattedEffectiveRadiusKm : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Body-Fixed X (km)',
            analysisA != null ? analysisA.formattedXKm : 'N/A',
            analysisB != null ? analysisB.formattedXKm : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Body-Fixed Y (km)',
            analysisA != null ? analysisA.formattedYKm : 'N/A',
            analysisB != null ? analysisB.formattedYKm : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Body-Fixed Z (km)',
            analysisA != null ? analysisA.formattedZKm : 'N/A',
            analysisB != null ? analysisB.formattedZKm : 'N/A',
          ),
          const Divider(),
          _buildRow(
            'Detailed Analysis',
            _buildDetailsLink(a),
            _buildDetailsLink(b),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSiteCard(LunarSite site, String role) {
    final analysis = widget.analysisService.analyzeSite(site);

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$role: ${site.name}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              StatusBadge(
                label: site.siteCode,
                color: AppColors.darkPrimary,
                icon: Icons.place_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'Classification: ${_formatClassification(site)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Source: ${site.sourceOrganization}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppConstants.space8),
          if (site.hasCoordinates && analysis != null) ...[
            Text(
              'Coordinates: ${site.coordinates!.latitude.toStringAsFixed(4)}°, ${site.coordinates!.longitude.toStringAsFixed(4)}°',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Distance to South Pole: ${analysis.formattedDistanceToSouthPoleKm}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Body-Fixed Cartesian: (${analysis.formattedXKm}, ${analysis.formattedYKm}, ${analysis.formattedZKm})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            Text(
              'Coordinates: Null (Official Product 78 Regional Footprint)',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: AppConstants.space12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildDetailsLink(site),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String attribute, dynamic valA, dynamic valB) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              attribute,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: valA is Widget
                ? valA
                : Text(valA.toString(), style: theme.textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: valB is Widget
                ? valB
                : Text(valB.toString(), style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsLink(LunarSite site) {
    return TextButton.icon(
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: const Text('Inspect Site'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LunarSiteDetailsPage(site: site),
          ),
        );
      },
    );
  }

  String _formatClassification(LunarSite site) {
    return switch (site.classification) {
      SiteClassification.highPriorityLandingSiteRegion =>
        'High-Priority Landing Region',
      SiteClassification.nasaCatalogRegion => 'NASA Catalog Region',
      SiteClassification.userDefined => 'User Defined Candidate',
    };
  }
}
