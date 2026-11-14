import 'package:meta/meta.dart';

/// Exception thrown when a scientific or geometric computation encounters an
/// invalid state, non-finite value, or domain failure.
///
/// Features an immutable scalar context map that strictly rejects mutable collections
/// and non-scalar objects to prevent state tampering or diagnostic memory leaks.
@immutable
class ScientificComputationException implements Exception {
  /// A human-readable diagnostic description of the failure.
  final String message;

  /// A stable programmatic error code identifying the failure type.
  final String code;

  /// An unmodifiable map of scalar diagnostic metadata.
  final Map<String, Object?> context;

  ScientificComputationException({
    required this.message,
    required this.code,
    Map<String, Object?> context = const {},
  }) : context = _validateAndFreezeContext(context);

  static Map<String, Object?> _validateAndFreezeContext(
    Map<String, Object?> raw,
  ) {
    final copy = <String, Object?>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value == null ||
          value is int ||
          (value is double && value.isFinite) ||
          value is String ||
          value is bool) {
        copy[entry.key] = value;
      } else {
        throw ArgumentError(
          'ScientificComputationException context only supports immutable primitives '
          '(String, int, finite double, bool, null). Got ${value.runtimeType} ($value) for key "${entry.key}".',
        );
      }
    }
    return Map.unmodifiable(copy);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScientificComputationException) return false;
    if (message != other.message || code != other.code) return false;
    if (context.length != other.context.length) return false;
    for (final entry in context.entries) {
      if (!other.context.containsKey(entry.key) ||
          other.context[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    var contextHash = 0;
    for (final entry in context.entries) {
      contextHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(message, code, contextHash);
  }

  @override
  String toString() =>
      'ScientificComputationException($code: $message, context: $context)';
}
