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

/// Default development and console logger utilizing [debugPrint].
class ConsoleLogHandler implements LogHandler {
  const ConsoleLogHandler();

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
    if (stackTrace != null) {
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

  /// Register an additional log handler (useful for testing or diagnostics).
  static void addHandler(LogHandler handler) {
    _handlers.add(handler);
  }

  /// Reset handlers to default console logger.
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
