import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/site_scientific_analysis_service.dart';
import 'package:luna_sight/features/lunar_sites/presentation/widgets/coordinate_display_widget.dart';
import 'package:luna_sight/features/nasa_data/nasa_data.dart';

/// Site Details and Scientific Analysis page.
///
/// Presents selenographic coordinates, body-fixed Cartesian transformations (Phase 04),
/// local topocentric horizon basis SEZ triad (Phase 06 M03), provenance citations,
/// and honest status indicators for terrain horizon and ephemeris workflows.
class LunarSiteDetailsPage extends StatefulWidget {
  final LunarSite site;
  final NasaDataRepository? nasaDataRepository;
  final SiteScientificAnalysisService analysisService;

  const LunarSiteDetailsPage({
    super.key,
    required this.site,
    this.nasaDataRepository,
    this.analysisService = const SiteScientificAnalysisService(),
  });

  @override
  State<LunarSiteDetailsPage> createState() => _LunarSiteDetailsPageState();
}

class _LunarSiteDetailsPageState extends State<LunarSiteDetailsPage> {
  final Map<String, bool> _assetAvailability = {};
  bool _isLoadingAssets = false;

  @override
  void initState() {
    super.initState();
    _checkLinkedAssets();
  }

  Future<void> _checkLinkedAssets() async {
    final repo = widget.nasaDataRepository;
    if (repo == null || widget.site.relatedProductIds.isEmpty) return;

    setState(() => _isLoadingAssets = true);
    for (final productId in widget.site.relatedProductIds) {
      try {
        final available = await repo.isAssetLocallyAvailable(productId);
        if (mounted) {
          setState(() {
            _assetAvailability[productId] = available;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _assetAvailability[productId] = false;
          });
        }
      }
    }
    if (mounted) {
      setState(() => _isLoadingAssets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ResponsiveLayout.isCompact(context);
    final site = widget.site;
    final analysis = widget.analysisService.analyzeSite(site);

    final (badgeLabel, badgeColor, badgeIcon) = switch (site.classification) {
      SiteClassification.highPriorityLandingSiteRegion => (
        'HIGH PRIORITY LANDING REGION',
        AppColors.statusInfo,
        Icons.flag_outlined,
      ),
      SiteClassification.nasaCatalogRegion => (
        'NASA CATALOG REGION',
        AppColors.darkSecondary,
        Icons.terrain_outlined,
      ),
      SiteClassification.userDefined => (
        'USER DEFINED CANDIDATE',
        AppColors.statusSuccess,
        Icons.person_pin_circle_outlined,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact
                    ? AppConstants.space16
                    : AppConstants.space24,
                vertical: AppConstants.space16,
              ),
              children: [
                // 1. Site Header Card
                ScientificCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 3.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.radiusSmall,
                                        ),
                                      ),
                                      child: Text(
                                        site.siteCode,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppConstants.space8),
                                    Expanded(
                                      child: Text(
                                        site.name,
                                        style: theme.textTheme.headlineSmall,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.space4),
                                Text(
                                  site.sourceOrganization,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: badgeLabel,
                            color: badgeColor,
                            icon: badgeIcon,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space16),
                      Text(
                        'Exploration Context & Overview',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Text(site.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space16),

                // 2. Selenographic Coordinates Card
                CoordinateDisplayWidget(coordinates: site.coordinates),
                const SizedBox(height: AppConstants.space16),

                // 3. Body-Fixed Cartesian Position Vector (Phase 04 Verified Engine)
                if (analysis != null) ...[
                  ScientificCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Body-Fixed Cartesian Position (Phase 04)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppConstants.space8),
                            const StatusBadge(
                              label: 'COMPUTED (MOON_ME_DE421)',
                              color: AppColors.statusSuccess,
                              icon: Icons.check_circle_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.space8),
                        Text(
                          'Evaluated via LunarCoordinateTransformer from selenographic coordinates:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppConstants.space12),
                        _buildInfoRow(
                          context,
                          'Cartesian X',
                          analysis.formattedXKm,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildInfoRow(
                          context,
                          'Cartesian Y',
                          analysis.formattedYKm,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildInfoRow(
                          context,
                          'Cartesian Z',
                          analysis.formattedZKm,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildInfoRow(
                          context,
                          'Effective Radius (R+h)',
                          analysis.formattedEffectiveRadiusKm,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildInfoRow(
                          context,
                          'Distance to South Pole',
                          analysis.formattedDistanceToSouthPoleKm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.space16),

                  // 4. Local Topocentric Horizon Basis (Phase 06 M03 Verified Engine)
                  ScientificCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Local Horizon Frame SEZ Triad (Phase 06)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppConstants.space8),
                            const StatusBadge(
                              label: 'COMPUTED (ORTHONORMAL)',
                              color: AppColors.statusSuccess,
                              icon: Icons.check_circle_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.space8),
                        Text(
                          'Evaluated via LocalHorizonBasis in right-handed orthonormal SEZ frame:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppConstants.space12),
                        _buildVectorRow(
                          context,
                          'Zenith (Up / Normal)',
                          analysis.horizonBasis.zenith,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildVectorRow(
                          context,
                          'North (Meridian Tangent)',
                          analysis.horizonBasis.north,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildVectorRow(
                          context,
                          'East (Parallel Tangent)',
                          analysis.horizonBasis.east,
                        ),
                        const SizedBox(height: AppConstants.space4),
                        _buildVectorRow(
                          context,
                          'South (SEZ Axis)',
                          analysis.horizonBasis.south,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.space16),
                ] else ...[
                  ScientificCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local Geometric & Topocentric Vectors',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.space8),
                        Text(
                          'Body-fixed Cartesian coordinates (X, Y, Z) and local topocentric SEZ basis vectors are unsupported for regional footprints without explicit point coordinates.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppConstants.space8),
                        const StatusBadge(
                          label: 'REQUIRES POINT COORDINATES',
                          color: AppColors.statusWarning,
                          icon: Icons.info_outline,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.space16),
                ],

                // 5. Scientific Conditions & Mission Readiness
                ScientificCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scientific Analysis & Mission Readiness',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space12),

                      // Terrain Horizon Status
                      _buildConditionRow(
                        context: context,
                        icon: Icons.landscape_outlined,
                        title: 'Terrain Horizon Profile (Phase 05)',
                        badgeLabel: 'AWAITING DEM DATASET',
                        badgeColor: AppColors.statusWarning,
                        description: 'Raycasting along 360° azimuths requires LOLA Product 81 (3.3 GB GeoTIFF ldem_87s_5mpp). Currently not cached in local storage.',
                      ),
                      const Divider(height: AppConstants.space24),

                      // Solar Illumination Status
                      _buildConditionRow(
                        context: context,
                        icon: Icons.wb_sunny_outlined,
                        title: 'Solar Illumination & Elevation (Phase 06)',
                        badgeLabel: 'EPHEMERIS PENDING',
                        badgeColor: AppColors.darkTextTertiary,
                        description: 'Topocentric solar elevation angle requires instantaneous Sun celestial vectors in MOON_ME_DE421 from planetary ephemeris engine (Phase 06 M04+).',
                      ),
                      const Divider(height: AppConstants.space24),

                      // Earth Visibility Status
                      _buildConditionRow(
                        context: context,
                        icon: Icons.public_outlined,
                        title: 'Earth Visibility & Direct Comms (Phase 07)',
                        badgeLabel: 'EPHEMERIS PENDING',
                        badgeColor: AppColors.darkTextTertiary,
                        description: 'Direct-to-Earth line-of-sight and topocentric elevation require instantaneous Earth celestial vectors in MOON_ME_DE421.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space16),

                // 6. Official Scientific Provenance & Citation Card
                ScientificCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scientific Provenance & Documentation',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space12),
                      _buildInfoRow(
                        context,
                        'Source Identifier',
                        site.sourceId,
                      ),
                      const SizedBox(height: AppConstants.space8),
                      _buildInfoRow(
                        context,
                        'Originating Organization',
                        site.sourceOrganization,
                      ),
                      const SizedBox(height: AppConstants.space8),
                      _buildInfoRow(
                        context,
                        'Documentation URL',
                        site.sourceUrl?.toString() ??
                            'N/A (Local / User Entered)',
                      ),
                      const SizedBox(height: AppConstants.space12),
                      Text(
                        'Formal Citation:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.space12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                        ),
                        child: Text(
                          site.citation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space16),

                // 7. Associated NASA Datasets Card
                ScientificCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Associated NASA Planetary Datasets',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (_isLoadingAssets)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space8),
                      if (site.relatedProductIds.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No specific NASA DEM products are explicitly documented as associated with this site in official source metadata.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppConstants.space8),
                            Text(
                              'General NASA products (e.g. South Pole LOLA DEM Mosaic ldem_87s_5mpp) remain available independently through the application data catalog, but are not asserted as site-specific without authoritative documentation.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          'Directly documented site-associated NASA planetary datasets:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppConstants.space12),
                        for (final productId in site.relatedProductIds) ...[
                          _buildLinkedProductTile(context, productId),
                          const SizedBox(height: AppConstants.space8),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space16),

                // 8. Action Workflows Card
                ScientificCard(
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Launch Mission Analysis Workflows',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Text(
                        'Perform interactive topocentric celestial angle tracking, daylight simulation, and timeline planning for ${site.name}:',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppConstants.space16),
                      Wrap(
                        spacing: AppConstants.space12,
                        runSpacing: AppConstants.space8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed('/visibility', arguments: site);
                            },
                            icon: const Icon(Icons.wb_sunny_rounded),
                            label: const Text('Solar & Earth Visibility'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed('/planner', arguments: site);
                            },
                            icon: const Icon(Icons.access_time_rounded),
                            label: const Text('Mission Time Planner'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/sites/compare');
                            },
                            icon: const Icon(Icons.compare_arrows_rounded),
                            label: const Text('Compare Candidates'),
                          ),
                        ],
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

  Widget _buildConditionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String badgeLabel,
    required Color badgeColor,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppConstants.space8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            StatusBadge(label: badgeLabel, color: badgeColor),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildVectorRow(BuildContext context, String label, dynamic vector) {
    final theme = Theme.of(context);
    final vx = (vector.x as double).toStringAsFixed(4);
    final vy = (vector.y as double).toStringAsFixed(4);
    final vz = (vector.z as double).toStringAsFixed(4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '($vx, $vy, $vz)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedProductTile(BuildContext context, String productId) {
    final theme = Theme.of(context);
    final isAvailable = _assetAvailability[productId] ?? false;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productId,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  productId == 'ldem_87s_5mpp'
                      ? 'South Pole LOLA DEM Mosaic (87°S–90°S, 5 m/pixel)'
                      : 'NASA Planetary Data Product',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.space8),
          StatusBadge(
            label: isAvailable ? 'LOCAL ASSET READY' : 'NOT DOWNLOADED',
            color: isAvailable
                ? AppColors.statusSuccess
                : AppColors.darkTextTertiary,
            icon: isAvailable
                ? Icons.check_circle_outline
                : Icons.cloud_download_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
