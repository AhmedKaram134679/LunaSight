/// System environment types.
enum AppEnvironment { development, staging, production }

/// Global runtime configuration for LunaSight.
///
/// Keeps environment setup and build properties decoupled from UI presentation.
class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String version;
  final bool enableDetailedLogging;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.version,
    required this.enableDetailedLogging,
  });

  /// Factory for standard production configuration.
  factory AppConfig.production() {
    return const AppConfig(
      environment: AppEnvironment.production,
      appName: 'LunaSight',
      version: '1.0.0',
      enableDetailedLogging: false,
    );
  }

  /// Factory for development configuration.
  factory AppConfig.development() {
    return const AppConfig(
      environment: AppEnvironment.development,
      appName: 'LunaSight (Dev)',
      version: '1.0.0',
      enableDetailedLogging: true,
    );
  }
}

