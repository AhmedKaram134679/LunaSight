import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';

/// Introductory header establishing LunaSight identity, purpose, and system status.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScientificCard(
      backgroundColor: isDark
          ? AppColors.darkSurfaceElevated
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      borderColor: isDark
          ? AppColors.darkBorder
          : theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.space12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.nights_stay_outlined,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space2),
                    Text(
                      AppConstants.appTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.space16),
          Wrap(
            spacing: AppConstants.space8,
            runSpacing: AppConstants.space8,
            children: [
              const StatusBadge(
                label: 'PHASE 01 FOUNDATION READY',
                color: AppColors.statusSuccess,
                icon: Icons.check_circle_outline,
              ),
              StatusBadge(
                label: 'OFFLINE ARCHITECTURE',
                color: theme.colorScheme.primary,
                icon: Icons.cloud_off_outlined,
              ),
              const StatusBadge(
                label: 'CLEAN ARCHITECTURE',
                color: AppColors.darkSecondary,
                icon: Icons.layers_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            'LunaSight is an analytical platform designed to evaluate and characterize optimal lunar landing sites. '
            'Phase 01 establishes the application shell, design system, responsive UI, routing, and logging foundation.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
