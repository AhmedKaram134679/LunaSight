import 'package:flutter/material.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/error/failures.dart';
import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/home/presentation/pages/home_page.dart';
import 'package:luna_sight/features/lunar_sites/lunar_sites.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/mission_time_planner_page.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/visibility_analysis_page.dart';

/// Centralized navigation and route generation for LunaSight.
///
/// Decouples UI screens from navigation mechanisms while gracefully handling
/// undefined or invalid routes without runtime exceptions.
class AppRouter {
  AppRouter._();

  static const String initialRoute = '/';
  static const String homeRoute = '/';
  static const String sitesRoute = '/sites';
  static const String siteDetailsRoute = '/sites/details';
  static const String customSiteRoute = '/sites/custom';
  static const String compareSitesRoute = '/sites/compare';
  static const String visibilityRoute = '/visibility';
  static const String plannerRoute = '/planner';

  /// Shared singleton repository instance ensuring user-added custom sites
  /// persist seamlessly across navigation routes during the application lifecycle.
  static final LunarSiteRepository sharedRepository =
      LocalLunarSiteRepository();

  /// Generates routes dynamically based on incoming [RouteSettings].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    AppLogger.debug('Navigating to route: ${settings.name}');

    switch (settings.name) {
      case homeRoute:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );

      case sitesRoute:
        return MaterialPageRoute<void>(
          builder: (_) => LunarSiteExplorerPage(repository: sharedRepository),
          settings: settings,
        );

      case customSiteRoute:
        return MaterialPageRoute<void>(
          builder: (_) => CustomSiteEntryPage(repository: sharedRepository),
          settings: settings,
        );

      case compareSitesRoute:
        return MaterialPageRoute<void>(
          builder: (_) => SiteComparisonPage(repository: sharedRepository),
          settings: settings,
        );

      case visibilityRoute:
        final arg = settings.arguments;
        final initialSite = arg is LunarSite ? arg : null;
        return MaterialPageRoute<void>(
          builder: (_) => VisibilityAnalysisPage(
            initialSite: initialSite,
            repository: sharedRepository,
          ),
          settings: settings,
        );

      case plannerRoute:
        final arg = settings.arguments;
        final initialSite = arg is LunarSite ? arg : null;
        return MaterialPageRoute<void>(
          builder: (_) => MissionTimePlannerPage(
            initialSite: initialSite,
            repository: sharedRepository,
          ),
          settings: settings,
        );

      case siteDetailsRoute:
        final site = settings.arguments;
        if (site is LunarSite) {
          return MaterialPageRoute<void>(
            builder: (_) => LunarSiteDetailsPage(site: site),
            settings: settings,
          );
        }
        AppLogger.warning('Invalid arguments for route: ${settings.name}');
        return MaterialPageRoute<void>(
          builder: (_) => RouteNotFoundPage(routeName: settings.name),
          settings: settings,
        );

      default:
        AppLogger.warning('Route not found: ${settings.name}');
        return MaterialPageRoute<void>(
          builder: (_) => RouteNotFoundPage(routeName: settings.name),
          settings: settings,
        );
    }
  }

  /// Safe route builder for unknown or invalid routes.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    final failure = NavigationFailure(
      message: 'Unknown navigation target: ${settings.name}',
    );
    AppLogger.error(failure.message);

    return MaterialPageRoute<void>(
      builder: (_) => RouteNotFoundPage(routeName: settings.name),
      settings: settings,
    );
  }
}

/// Fallback presentation page when an unknown route is accessed.
class RouteNotFoundPage extends StatelessWidget {
  final String? routeName;

  const RouteNotFoundPage({super.key, this.routeName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Destination Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 56,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: AppConstants.space16),
                Text(
                  'Route Not Found',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.space8),
                Text(
                  'The requested navigation route "${routeName ?? 'unknown'}" does not exist.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.space24),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.homeRoute,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
