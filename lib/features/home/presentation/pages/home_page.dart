import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/home/data/repositories/local_system_module_repository.dart';
import 'package:luna_sight/features/home/domain/models/system_module.dart';
import 'package:luna_sight/features/home/domain/repositories/system_module_repository.dart';
import 'package:luna_sight/features/home/presentation/widgets/home_header.dart';
import 'package:luna_sight/features/home/presentation/widgets/module_status_card.dart';
import 'package:luna_sight/features/lunar_sites/data/datasources/bundled_lunar_site_catalog.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/lunar_site_details_page.dart';

/// LunaSight Mission Dashboard.
///
/// Serves as the central mission-control interface for lunar south-pole landing site exploration,
/// geodetic analysis, candidate comparison, and scientific readiness tracking.
class HomePage extends StatefulWidget {
  final SystemModuleRepository repository;

  const HomePage({
    super.key,
    this.repository = const LocalSystemModuleRepository(),
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final List<SystemModule> _modules;
  bool _showRoadmap = false;

  @override
  void initState() {
    super.initState();
    _modules = widget.repository.getSystemModules();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ResponsiveLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.blur_on_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: AppConstants.space8),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'System Architecture',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showSystemInfoDialog(context),
          ),
          const SizedBox(width: AppConstants.space8),
        ],
      ),
      body: SafeArea(
        child: Center(
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
                // 1. Identity & Foundation Header
                const HomeHeader(),
                const SizedBox(height: AppConstants.space16),

                // 2. Lunar South Pole Mission Statement & Telemetry Hero Card
                _buildMissionHeroCard(context),
                const SizedBox(height: AppConstants.space24),

                // 3. Primary Mission Workflows & Action Cards
                Text(
                  'Mission Operations & Analysis',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.space4),
                Text(
                  'Access verified NASA landing site catalogs, side-by-side comparison matrix, and custom coordinates registration.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConstants.space16),

                if (isCompact) ...[
                  _buildActionCard(
                    context: context,
                    icon: Icons.travel_explore_rounded,
                    title: 'Lunar Site Explorer',
                    subtitle: 'Search and filter 27 official NASA GSFC PGDA Product 78 south-pole candidate regions.',
                    badge: '27 SITES',
                    badgeColor: AppColors.statusInfo,
                    onTap: () => Navigator.of(context).pushNamed('/sites'),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  _buildActionCard(
                    context: context,
                    icon: Icons.compare_arrows_rounded,
                    title: 'Candidate Site Comparison',
                    subtitle: 'Evaluate selenographic coordinates, polar proximity, and data readiness between candidate sites.',
                    badge: 'MATRIX',
                    badgeColor: AppColors.statusSuccess,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/sites/compare'),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  _buildActionCard(
                    context: context,
                    icon: Icons.add_location_alt_outlined,
                    title: 'Register Custom Candidate Site',
                    subtitle: 'Input user-defined selenographic coordinates with strict datum and provenance validation.',
                    badge: 'CUSTOM',
                    badgeColor: AppColors.darkPrimary,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/sites/custom'),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context: context,
                          icon: Icons.travel_explore_rounded,
                          title: 'Lunar Site Explorer',
                          subtitle: 'Search and filter 27 official NASA GSFC PGDA Product 78 south-pole candidate regions.',
                          badge: '27 SITES',
                          badgeColor: AppColors.statusInfo,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sites'),
                        ),
                      ),
                      const SizedBox(width: AppConstants.space16),
                      Expanded(
                        child: _buildActionCard(
                          context: context,
                          icon: Icons.compare_arrows_rounded,
                          title: 'Candidate Site Comparison',
                          subtitle: 'Evaluate selenographic coordinates, polar proximity, and data readiness between candidate sites.',
                          badge: 'MATRIX',
                          badgeColor: AppColors.statusSuccess,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sites/compare'),
                        ),
                      ),
                      const SizedBox(width: AppConstants.space16),
                      Expanded(
                        child: _buildActionCard(
                          context: context,
                          icon: Icons.add_location_alt_outlined,
                          title: 'Register Custom Site',
                          subtitle: 'Input user-defined selenographic coordinates with strict datum and provenance validation.',
                          badge: 'CUSTOM',
                          badgeColor: AppColors.darkPrimary,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sites/custom'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppConstants.space24),

                // 4. Featured High-Priority Artemis Candidate Sites Spotlight
                Text(
                  'Featured High-Priority Landing Regions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.space4),
                Text(
                  'Officially cataloged in NASA GSFC PGDA Product 78 documentation as regions surrounding high-priority landing sites.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConstants.space16),
                _buildFeaturedSitesSection(context, isCompact),
                const SizedBox(height: AppConstants.space24),

                // 5. Scientific Capabilities & Readiness Matrix
                _buildCapabilitiesStatusCard(context),
                const SizedBox(height: AppConstants.space24),

                // 6. Modular Architecture Roadmap (Collapsible)
                _buildRoadmapAccordion(context, isCompact),
                const SizedBox(height: AppConstants.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScientificCard(
      backgroundColor: isDark
          ? AppColors.darkSurface
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.space12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lunar South Pole Mission Scope',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Artemis Candidate Landing Zones (85°S – 90°S)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'POLAR GEODESY',
                color: AppColors.statusInfo,
                icon: Icons.satellite_alt_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            'LunaSight enables precision selenographic evaluation of candidate exploration zones near the lunar south pole. Utilizing verified body-fixed Cartesian transformations and topocentric SEZ horizon frames, the system provides traceable astronomical and spatial foundations for lunar surface missions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.space16),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.space12),
          Wrap(
            spacing: AppConstants.space12,
            runSpacing: AppConstants.space8,
            children: [
              _buildTelemetryChip(
                context,
                Icons.public,
                'Frame',
                'MOON_ME_DE421',
              ),
              _buildTelemetryChip(
                context,
                Icons.radio_button_checked,
                'Mean Radius',
                '1,737.4 km',
              ),
              _buildTelemetryChip(
                context,
                Icons.access_time_rounded,
                'Time Scale',
                'TDB / TT',
              ),
              _buildTelemetryChip(
                context,
                Icons.my_location,
                'Target Latitude',
                '≤ -85.0°',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ScientificCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.space8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  StatusBadge(label: badge, color: badgeColor),
                ],
              ),
              const SizedBox(height: AppConstants.space12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.space12),
              Row(
                children: [
                  Text(
                    'Open Workflow',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSitesSection(BuildContext context, bool isCompact) {
    final highPrioritySites = BundledLunarSiteCatalog.officialSites
        .where(
          (s) =>
              s.classification ==
              SiteClassification.highPriorityLandingSiteRegion,
        )
        .take(4)
        .toList();

    return Column(
      children: [
        for (final site in highPrioritySites) ...[
          _buildFeaturedSiteTile(context, site),
          const SizedBox(height: AppConstants.space8),
        ],
      ],
    );
  }

  Widget _buildFeaturedSiteTile(BuildContext context, LunarSite site) {
    final theme = Theme.of(context);

    return ScientificCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(AppConstants.space8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            ),
            child: Text(
              site.siteCode,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          title: Text(
            site.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            site.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LunarSiteDetailsPage(site: site),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCapabilitiesStatusCard(BuildContext context) {
    final theme = Theme.of(context);

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Scientific Capabilities & Engine Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space4),
          Text(
            'Operational readiness of underlying mathematical, geodetic, and astronomical engines.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.space16),

          _buildCapabilityRow(
            context,
            'Lunar Coordinate Transformer (Phase 04)',
            'Body-fixed Cartesian coordinates in MOON_ME_DE421',
            'OPERATIONAL',
            AppColors.statusSuccess,
          ),
          const Divider(),
          _buildCapabilityRow(
            context,
            'Local Topocentric Horizon Basis (Phase 06 M03)',
            'Right-handed orthonormal SEZ triad calculation',
            'OPERATIONAL',
            AppColors.statusSuccess,
          ),
          const Divider(),
          _buildCapabilityRow(
            context,
            'Astronomical Time Model (Phase 06 M02)',
            'Microsecond UTC, TAI, TT, and TDB time-scale conversions',
            'OPERATIONAL',
            AppColors.statusSuccess,
          ),
          const Divider(),
          _buildCapabilityRow(
            context,
            'NASA Product 78 Catalog (Phase 03)',
            '27 official lunar south-pole designated regions',
            'OPERATIONAL',
            AppColors.statusSuccess,
          ),
          const Divider(),
          _buildCapabilityRow(
            context,
            'Terrain Horizon Engine (Phase 05)',
            '360° raycasting requires local LOLA Product 81 DEM cache (3.3 GB)',
            'DATASET PENDING',
            AppColors.statusWarning,
          ),
          const Divider(),
          _buildCapabilityRow(
            context,
            'Solar & Earth Ephemeris Vectors (Phase 06/07)',
            'Instantaneous celestial vectors require JPL DE421 / SPICE integration',
            'PLANNED (M04+)',
            AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityRow(
    BuildContext context,
    String title,
    String subtitle,
    String badge,
    Color badgeColor,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.space8),
          StatusBadge(label: badge, color: badgeColor),
        ],
      ),
    );
  }

  Widget _buildRoadmapAccordion(BuildContext context, bool isCompact) {
    final theme = Theme.of(context);

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showRoadmap = !_showRoadmap),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppConstants.space8),
                    Text(
                      'Engineering Roadmap (${_modules.length} Modules)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showRoadmap
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          if (_showRoadmap) ...[
            const SizedBox(height: AppConstants.space16),
            Text(
              'Engineering roadmap scheduled for progressive integration across release milestones:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.space12),
            if (isCompact) ...[
              for (final module in _modules) ...[
                ModuleStatusCard(
                  module: module,
                  onTap: module.id == 'lunar_site_explorer'
                      ? () => Navigator.of(context).pushNamed('/sites')
                      : null,
                ),
                const SizedBox(height: AppConstants.space12),
              ],
            ] else ...[
              _buildTwoColumnModuleGrid(_modules),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnModuleGrid(List<SystemModule> modules) {
    return Column(
      children: [
        for (int i = 0; i < modules.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ModuleStatusCard(
                  module: modules[i],
                  onTap: modules[i].id == 'lunar_site_explorer'
                      ? () => Navigator.of(context).pushNamed('/sites')
                      : null,
                ),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: i + 1 < modules.length
                    ? ModuleStatusCard(
                        module: modules[i + 1],
                        onTap: modules[i + 1].id == 'lunar_site_explorer'
                            ? () => Navigator.of(context).pushNamed('/sites')
                            : null,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (i + 2 < modules.length)
            const SizedBox(height: AppConstants.space16),
        ],
      ],
    );
  }

  void _showSystemInfoDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.nights_stay_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppConstants.space12),
              const Text('About LunaSight'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LunaSight Core', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppConstants.space8),
              Text(
                'Phase 01 establishes production-oriented foundations: offline resilience, clean architecture, unified theming, and responsive UI scaling. Scientific algorithms and lunar ephemeris engines are planned for Phase 02+.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
