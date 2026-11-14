import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Compile-Time Finality Regression Tests — LunarCoordinateTransformer', () {
    late String repoRoot;
    late String dartExecutable;

    setUpAll(() {
      repoRoot = Directory.current.path;
      // Resolve dart executable based on platform
      if (Platform.isWindows) {
        // Platform.resolvedExecutable in Flutter test is flutter_tester.exe
        // Check PATH or standard Flutter/Dart installation locations
        final whichResult = Process.runSync('where', ['dart.bat']);
        if (whichResult.exitCode == 0 &&
            whichResult.stdout.toString().trim().isNotEmpty) {
          dartExecutable = whichResult.stdout
              .toString()
              .split('\r\n')
              .first
              .trim();
        } else {
          dartExecutable = 'dart';
        }
      } else {
        final whichResult = Process.runSync('which', ['dart']);
        if (whichResult.exitCode == 0 &&
            whichResult.stdout.toString().trim().isNotEmpty) {
          dartExecutable = whichResult.stdout.toString().trim();
        } else {
          dartExecutable = 'dart';
        }
      }
    });

    test('Analyzer rejects external subclassing with invalid_use_of_type_outside_library', () {
      final fixturePath = [
        'test',
        'compile_time',
        'fixtures',
        'lunar_coordinate_transformer_subclass_invalid.dart',
      ].join(Platform.pathSeparator);

      final fullFixturePath = [
        repoRoot,
        fixturePath,
      ].join(Platform.pathSeparator);
      expect(
        File(fullFixturePath).existsSync(),
        isTrue,
        reason: 'Fixture file must exist at $fullFixturePath',
      );

      final result = Process.runSync(
        dartExecutable,
        ['analyze', fixturePath],
        workingDirectory: repoRoot,
        runInShell: true,
      );

      // Analyzer exit code 3 indicates static analysis errors found
      expect(
        result.exitCode,
        isNot(0),
        reason:
            'Dart analyzer must reject external subclassing of a final class.',
      );

      final output = '${result.stdout}\n${result.stderr}';

      // 1. Must contain the exact compile-time error diagnostic code
      expect(
        output.contains('invalid_use_of_type_outside_library'),
        isTrue,
        reason:
            'Analyzer output must include error code "invalid_use_of_type_outside_library". Output: $output',
      );

      // 2. Must specifically identify LunarCoordinateTransformer and final class constraint
      expect(
        output.contains(
          "'LunarCoordinateTransformer' can't be extended outside of its library because it's a final class",
        ),
        isTrue,
        reason:
            'Analyzer output must identify final class extension violation on LunarCoordinateTransformer. Output: $output',
      );
    });

    test('Analyzer rejects external implementation with invalid_use_of_type_outside_library', () {
      final fixturePath = [
        'test',
        'compile_time',
        'fixtures',
        'lunar_coordinate_transformer_implements_invalid.dart',
      ].join(Platform.pathSeparator);

      final fullFixturePath = [
        repoRoot,
        fixturePath,
      ].join(Platform.pathSeparator);
      expect(
        File(fullFixturePath).existsSync(),
        isTrue,
        reason: 'Fixture file must exist at $fullFixturePath',
      );

      final result = Process.runSync(
        dartExecutable,
        ['analyze', fixturePath],
        workingDirectory: repoRoot,
        runInShell: true,
      );

      expect(
        result.exitCode,
        isNot(0),
        reason: 'Dart analyzer must reject external implementation of a final class.',
      );

      final output = '${result.stdout}\n${result.stderr}';

      expect(
        output.contains('invalid_use_of_type_outside_library'),
        isTrue,
        reason:
            'Analyzer output must include error code "invalid_use_of_type_outside_library". Output: $output',
      );

      expect(
        output.contains(
          "'LunarCoordinateTransformer' can't be implemented outside of its library because it's a final class",
        ),
        isTrue,
        reason:
            'Analyzer output must identify final class implementation violation on LunarCoordinateTransformer. Output: $output',
      );
    });
  });
}
