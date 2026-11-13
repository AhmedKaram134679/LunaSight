import 'package:flutter/material.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/features/home/data/repositories/local_system_module_repository.dart';
import 'package:luna_sight/features/home/domain/models/system_module.dart';
import 'package:luna_sight/features/home/domain/repositories/system_module_repository.dart';
import 'package:luna_sight/features/home/presentation/widgets/home_header.dart';
import 'package:luna_sight/features/home/presentation/widgets/module_status_card.dart';

/// LunaSight Home Page.
///
/// Presents the application identity, architectural foundation, and modular roadmap.
/// Fully offline-capable, responsive across all screen dimensions.
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
                const HomeHeader(),
                const SizedBox(height: AppConstants.space24),
                Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'System Architecture & Roadmap',
                      style: theme.textTheme.titleLarge,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${_modules.length} Modules',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space8),
                Text(
                  'Engineering components scheduled for progressive integration across release milestones.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppConstants.space16),
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
                const SizedBox(height: AppConstants.space24),
              ],
            ),
          ),
        ),
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
