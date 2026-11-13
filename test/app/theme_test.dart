import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/app/theme/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test(
      'Dark theme instantiates with expected colors and dark brightness',
      () {
        final theme = AppTheme.darkTheme;

        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
        expect(theme.colorScheme.primary, AppColors.darkPrimary);
        expect(theme.colorScheme.surface, AppColors.darkSurface);
        expect(theme.useMaterial3, isTrue);
      },
    );

    test(
      'Light theme instantiates with expected colors and light brightness',
      () {
        final theme = AppTheme.lightTheme;

        expect(theme.brightness, Brightness.light);
        expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
        expect(theme.colorScheme.primary, AppColors.lightPrimary);
        expect(theme.colorScheme.surface, AppColors.lightSurface);
        expect(theme.useMaterial3, isTrue);
      },
    );

    testWidgets(
      'App applies light and dark themes without rendering exceptions',
      (tester) async {
        // Test Light Theme render
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Light Theme Test')),
              body: const Center(child: Text('Laboratory View')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Light Theme Test'), findsOneWidget);

        // Test Dark Theme render
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Dark Theme Test')),
              body: const Center(child: Text('Obsidian Space View')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dark Theme Test'), findsOneWidget);
      },
    );
  });
}
