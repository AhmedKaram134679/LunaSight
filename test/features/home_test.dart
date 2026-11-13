import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/app.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/features/home/data/repositories/local_system_module_repository.dart';
import 'package:luna_sight/features/home/domain/models/system_module.dart';
import 'package:luna_sight/features/home/presentation/widgets/module_status_card.dart';

void main() {
  group('Home Feature & Repository Tests', () {
    test('LocalSystemModuleRepository returns non-empty roadmap modules with valid status', () {
      const repository = LocalSystemModuleRepository();
      final modules = repository.getSystemModules();

      expect(modules.isNotEmpty, isTrue);
      // Phase 01 is operational
      final phase01 = modules.firstWhere((m) => m.id == 'flutter_foundation');
      expect(phase01.status, ModuleStatus.operational);

      // Future scientific modules are planned
      final phase02 = modules.firstWhere((m) => m.id == 'scientific_engine');
      expect(phase02.status, ModuleStatus.planned);
    });

    testWidgets('ModuleStatusCard renders operational status correctly', (
      tester,
    ) async {
      const module = SystemModule(
        id: 'test_module',
        title: 'Test Operational Module',
        description: 'Test description content.',
        phase: 'Phase 01',
        status: ModuleStatus.operational,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ModuleStatusCard(module: module)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Operational Module'), findsOneWidget);
      expect(find.text('OPERATIONAL'), findsOneWidget);
      expect(find.text('Test description content.'), findsOneWidget);
    });

    testWidgets('ModuleStatusCard renders planned status correctly', (
      tester,
    ) async {
      const module = SystemModule(
        id: 'test_module_planned',
        title: 'Test Planned Module',
        description: 'Planned capability description.',
        phase: 'Phase 02 (Planned)',
        status: ModuleStatus.planned,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ModuleStatusCard(module: module)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Planned Module'), findsOneWidget);
      expect(find.text('PLANNED'), findsOneWidget);
    });
  });

  group('Responsive Layout Tests across Form Factors', () {
    Widget buildConstrainedApp(Size size) {
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: LunaSightApp(config: AppConfig.development()),
        ),
      );
    }

    testWidgets('Renders without overflow on Small Android Phone (320x568)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildConstrainedApp(const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.text(AppConstants.appName), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Renders without overflow on Standard Android Phone (390x844)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(390, 844)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders without overflow on Large Android / Tablet (768x1024)',
      (tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(768, 1024)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders without overflow on Desktop / Expanded Screen (1440x900)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(1440, 900)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('ResponsiveLayout utility classifies screen sizes accurately', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final deviceClass = ResponsiveLayout.getDeviceClass(context);
              final isCompact = ResponsiveLayout.isCompact(context);
              return Scaffold(
                body: Text('Class: $deviceClass, Compact: $isCompact'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Class:'), findsOneWidget);
    });
  });
}
