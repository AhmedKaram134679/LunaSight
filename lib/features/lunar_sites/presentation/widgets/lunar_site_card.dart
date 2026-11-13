import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';

/// Card widget presenting a summary of a [LunarSite] in the explorer list.
class LunarSiteCard extends StatelessWidget {
  final LunarSite site;
  final VoidCallback onTap;

  const LunarSiteCard({super.key, required this.site, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (badgeLabel, badgeColor, badgeIcon) = switch (site.classification) {
      SiteClassification.candidateSite => (
        'CANDIDATE SITE',
        AppColors.statusInfo,
        Icons.flag_outlined,
      ),
      SiteClassification.referenceRegion => (
        'REFERENCE REGION',
        AppColors.darkSecondary,
        Icons.terrain_outlined,
      ),
      SiteClassification.userDefined => (
        'USER DEFINED',
        AppColors.statusSuccess,
        Icons.person_pin_circle_outlined,
      ),
    };

    return ScientificCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space4),
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
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSmall,
                                ),
                              ),
                              child: Text(
                                site.siteCode,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.space8),
                            Expanded(
                              child: Text(
                                site.name,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.space4),
                        Text(
                          site.sourceOrganization,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.space8),
                  StatusBadge(
                    label: badgeLabel,
                    color: badgeColor,
                    icon: badgeIcon,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space12),
              Text(
                site.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppConstants.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        site.hasCoordinates
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                        size: 16,
                        color: site.hasCoordinates
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        site.hasCoordinates
                            ? site.coordinates!.formattedCoordinates
                            : 'Bounds only (no single point)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: site.hasCoordinates
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
