import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luna_sight/app/app.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/core/error/app_error_handler.dart';
import 'package:luna_sight/core/logging/app_logger.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize global error-handling hooks
      AppErrorHandler.initialize();

      final config = AppConfig.production();
      AppLogger.info('Starting ${config.appName} (v${config.version})...');

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
