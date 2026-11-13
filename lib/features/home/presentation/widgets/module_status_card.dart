import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/home/domain/models/system_module.dart';

/// Card presenting a LunaSight system module, its description, and its actual roadmap status.
class ModuleStatusCard extends StatelessWidget {
  final SystemModule module;

  const ModuleStatusCard({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOperational = module.status == ModuleStatus.operational;

    final badgeColor = isOperational
        ? AppColors.statusSuccess
        : AppColors.darkTextTertiary;
    final badgeLabel = isOperational ? 'OPERATIONAL' : 'PLANNED';
    final badgeIcon = isOperational
        ? Icons.check_circle_outline
        : Icons.schedule_outlined;

    return ScientificCard(
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
                    Text(
                      module.phase,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isOperational
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space4),
                    Text(module.title, style: theme.textTheme.titleMedium),
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
          Text(module.description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
