import 'package:flutter/foundation.dart';

/// Supported log levels for LunaSight.
enum LogLevel { debug, info, warning, error }

/// Abstract log handler interface for flexible output (e.g. testing or production).
abstract class LogHandler {
  void handle(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Default console log handler.
///
/// In debug mode or when verbose details are enabled, outputs diagnostic details.
/// In release mode, guards against emitting raw stack traces or internal technical details.
class ConsoleLogHandler implements LogHandler {
  final bool outputStackTraces;

  const ConsoleLogHandler({this.outputStackTraces = kDebugMode});

  @override
  void handle(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = switch (level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warning => '[WARN]',
      LogLevel.error => '[ERROR]',
    };

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$timestamp $prefix $message');
    if (error != null) {
      debugPrint('$prefix Error: $error');
    }
    if (stackTrace != null && outputStackTraces) {
      debugPrint('$prefix StackTrace:\n$stackTrace');
    }
  }
}

/// Centralized application logger.
///
/// Provides structured logging without requiring third-party or paid dependencies.
class AppLogger {
  AppLogger._();

  static final List<LogHandler> _handlers = [const ConsoleLogHandler()];
  static LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  /// Configure the logger based on application settings.
  static void configure({
    required bool enableDetailedLogging,
    LogLevel? minimumLevel,
  }) {
    minLevel =
        minimumLevel ??
        (enableDetailedLogging ? LogLevel.debug : LogLevel.info);

    _handlers.clear();
    _handlers.add(ConsoleLogHandler(outputStackTraces: enableDetailedLogging));
  }

  /// Register an additional log handler (useful for testing or diagnostics).
  static void addHandler(LogHandler handler) {
    _handlers.add(handler);
  }

  /// Reset handlers to default console logger and standard level.
  static void resetHandlers() {
    _handlers.clear();
    _handlers.add(const ConsoleLogHandler());
    minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;
  }

  /// Remove all handlers (useful in unit tests to capture logs).
  @visibleForTesting
  static void clearHandlers() {
    _handlers.clear();
  }

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) {
      return;
    }
    for (final handler in _handlers) {
      handler.handle(level, message, error: error, stackTrace: stackTrace);
    }
  }

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }
}
