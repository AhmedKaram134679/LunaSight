/// Core application error types and failures for LunaSight.
///
/// Designed to differentiate user-facing, system, and domain failures without
/// exposing internal technical details or stack traces to end users.
abstract class AppFailure implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppFailure({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AppFailure($message');
    if (code != null) {
      buffer.write(', code: $code');
    }
    if (cause != null) {
      buffer.write(', cause: $cause');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// Generic unexpected failure encountered at runtime.
class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'UNEXPECTED_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Navigation or routing related failure.
class NavigationFailure extends AppFailure {
  const NavigationFailure({
    required super.message,
    super.code = 'NAVIGATION_ERROR',
    super.cause,
    super.stackTrace,
  });
}

