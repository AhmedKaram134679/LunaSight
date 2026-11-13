import 'package:luna_sight/core/constants/app_constants.dart';

/// System environment types.
enum AppEnvironment { development, staging, production }

/// Global runtime configuration for LunaSight.
///
/// Keeps environment setup and build properties decoupled from UI presentation.
class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final bool enableDetailedLogging;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.enableDetailedLogging,
  });

  /// Factory for standard production configuration.
  factory AppConfig.production() {
    return const AppConfig(
      environment: AppEnvironment.production,
      appName: AppConstants.appName,
      enableDetailedLogging: false,
    );
  }

  /// Factory for development configuration.
  factory AppConfig.development() {
    return const AppConfig(
      environment: AppEnvironment.development,
      appName: '${AppConstants.appName} (Dev)',
      enableDetailedLogging: true,
    );
  }
}
