import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/core/error/app_error_handler.dart';
import 'package:luna_sight/core/error/failures.dart';
import 'package:luna_sight/core/logging/app_logger.dart';

class TestLogHandler implements LogHandler {
  final List<String> logs = [];

  @override
  void handle(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    logs.add('${level.name.toUpperCase()}: $message');
  }
}

void main() {
  group('AppLogger Tests', () {
    late TestLogHandler testHandler;

    setUp(() {
      AppLogger.clearHandlers();
      testHandler = TestLogHandler();
      AppLogger.addHandler(testHandler);
      AppLogger.minLevel = LogLevel.debug;
    });

    tearDown(() {
      AppLogger.resetHandlers();
    });

    test('Logs message at all levels accurately', () {
      AppLogger.debug('Debug event');
      AppLogger.info('Info event');
      AppLogger.warning('Warning event');
      AppLogger.error('Error event');

      expect(testHandler.logs, contains('DEBUG: Debug event'));
      expect(testHandler.logs, contains('INFO: Info event'));
      expect(testHandler.logs, contains('WARNING: Warning event'));
      expect(testHandler.logs, contains('ERROR: Error event'));
    });

    test('Respects minLevel filter', () {
      AppLogger.minLevel = LogLevel.warning;

      AppLogger.debug('Ignored debug');
      AppLogger.info('Ignored info');
      AppLogger.warning('Observed warning');
      AppLogger.error('Observed error');

      expect(testHandler.logs.length, 2);
      expect(testHandler.logs, contains('WARNING: Observed warning'));
      expect(testHandler.logs, contains('ERROR: Observed error'));
    });

    test('AppLogger.configure applies AppConfig settings accurately', () {
      // Test development configuration (detailed logging enabled)
      final devConfig = AppConfig.development();
      AppLogger.configure(
        enableDetailedLogging: devConfig.enableDetailedLogging,
      );
      expect(AppLogger.minLevel, LogLevel.debug);

      // Test production configuration (detailed logging disabled)
      final prodConfig = AppConfig.production();
      AppLogger.configure(
        enableDetailedLogging: prodConfig.enableDetailedLogging,
      );
      expect(AppLogger.minLevel, LogLevel.info);
    });
  });

  group('AppFailure Tests', () {
    test('UnexpectedFailure formats message and default code', () {
      const failure = UnexpectedFailure();
      expect(
        failure.message,
        'An unexpected error occurred. Please try again.',
      );
      expect(failure.code, 'UNEXPECTED_ERROR');
      expect(failure.toString(), contains('AppFailure'));
    });

    test('NavigationFailure holds target message and custom code', () {
      const failure = NavigationFailure(message: 'Target route not found');
      expect(failure.message, 'Target route not found');
      expect(failure.code, 'NAVIGATION_ERROR');
    });
  });

  group('AppErrorHandler Fallback Widget Tests', () {
    testWidgets(
      'AppErrorFallbackView renders user-friendly message without raw crash',
      (tester) async {
        final details = FlutterErrorDetails(
          exception: Exception('Simulated test exception'),
          stack: StackTrace.current,
        );

        await tester.pumpWidget(AppErrorFallbackView(details: details));
        await tester.pumpAndSettle();

        expect(find.text('Application Error'), findsOneWidget);
        expect(
          find.text(
            'LunaSight encountered an unexpected presentation issue. Diagnostics have been logged.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
