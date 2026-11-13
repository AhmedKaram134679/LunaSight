import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/presentation/widgets/coordinate_display_widget.dart';
import 'package:luna_sight/features/nasa_data/nasa_data.dart';

/// Site Details page displaying full provenance, coordinate data, source citations,
/// and linked NASA dataset availability from [NasaDataRepository].
class LunarSiteDetailsPage extends StatefulWidget {
  final LunarSite site;
  final NasaDataRepository? nasaDataRepository;

  const LunarSiteDetailsPage({
    super.key,
    required this.site,
    this.nasaDataRepository,
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
        'USER DEFINED',
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
                // Site Header Card
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

                // Selenographic Coordinates Card
                CoordinateDisplayWidget(coordinates: site.coordinates),
                const SizedBox(height: AppConstants.space16),

                // Official Scientific Provenance & Citation Card
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

                // Associated NASA Datasets Card
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
                const SizedBox(height: AppConstants.space24),
              ],
            ),
          ),
        ),
      ),
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
          width: 160,
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
