import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:luna_sight/core/logging/app_logger.dart';

/// Global error-handling foundation for LunaSight.
///
/// Configures Flutter framework diagnostics, asynchronous error zoning, and
/// safe fallback presentation widgets that protect users from technical stack traces.
class AppErrorHandler {
  AppErrorHandler._();

  /// Initializes global error hooks for Flutter and asynchronous Dart execution.
  static void initialize() {
    // 1. Flutter framework error dispatcher (rendering, widget build, lifecycle)
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'Flutter framework error: ${details.exceptionAsString()}',
        error: details.exception,
        stackTrace: details.stack,
      );
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // 2. Uncaught asynchronous errors from Dart runtime
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error(
        'Uncaught platform/async error: $error',
        error: error,
        stackTrace: stack,
      );
      return true; // handled
    };

    // 3. User-facing fallback widget when a widget build fails catastrophically
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return AppErrorFallbackView(details: details);
    };
  }
}

/// A restrained, user-friendly fallback screen rendered when an unexpected widget error occurs.
class AppErrorFallbackView extends StatelessWidget {
  final FlutterErrorDetails details;

  const AppErrorFallbackView({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B0F19)
            : const Color(0xFFF3F5F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Application Error',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LunaSight encountered an unexpected presentation issue. Diagnostics have been logged.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        details.exceptionAsString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
