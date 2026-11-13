import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:luna_sight/app/app.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/core/error/app_error_handler.dart';
import 'package:luna_sight/core/logging/app_logger.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Configure environment and runtime settings
      final config = kReleaseMode
          ? AppConfig.production()
          : AppConfig.development();

      // Apply logger configuration from AppConfig
      AppLogger.configure(enableDetailedLogging: config.enableDetailedLogging);

      // Initialize global error-handling hooks
      AppErrorHandler.initialize();

      AppLogger.info('Starting ${config.appName}...');

      runApp(LunaSightApp(config: config));
    },
    (error, stackTrace) {
      AppLogger.error(
        'Uncaught root zone error: $error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
