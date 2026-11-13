import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/app.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/app/router/app_router.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/features/home/presentation/pages/home_page.dart';

void main() {
  group('LunaSightApp Shell & Smoke Tests', () {
    testWidgets('Application launches and renders LunaSight identity', (
      tester,
    ) async {
      await tester.pumpWidget(LunaSightApp(config: AppConfig.development()));
      await tester.pumpAndSettle();

      // Verify LunaSight title appears in AppBar and Header
      expect(find.text(AppConstants.appName), findsWidgets);
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      // Verify default counter interface is absent
      expect(find.text('Flutter Demo Home Page'), findsNothing);
      expect(
        find.text('You have pushed the button this many times:'),
        findsNothing,
      );
      expect(find.byIcon(Icons.add), findsNothing);

      // Verify Phase 01 status is visible
      expect(find.text('PHASE 01 FOUNDATION READY'), findsOneWidget);
    });

    testWidgets('System architecture dialog opens and closes cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(LunaSightApp(config: AppConfig.development()));
      await tester.pumpAndSettle();

      final infoButton = find.byTooltip('System Architecture');
      expect(infoButton, findsOneWidget);

      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      expect(find.text('About LunaSight'), findsOneWidget);
      expect(
        find.textContaining(
          'Phase 01 establishes production-oriented foundations',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('About LunaSight'), findsNothing);
    });
  });

  group('Navigation & Routing Tests', () {
    testWidgets('Router resolves initial home route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: AppRouter.homeRoute,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets(
      'Router handles unknown route gracefully with fallback screen',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
            initialRoute: '/non_existent_route',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Route Not Found'), findsOneWidget);
        expect(
          find.text(
            'The requested navigation route "/non_existent_route" does not exist.',
          ),
          findsOneWidget,
        );
        expect(find.text('Return to Home'), findsOneWidget);
      },
    );
  });
}
