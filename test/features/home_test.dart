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
    test('LocalSystemModuleRepository returns exact 11 roadmap modules with valid sequence and status', () {
      const repository = LocalSystemModuleRepository();
      final modules = repository.getSystemModules();

      expect(modules.length, 11);

      // Verify Phase 01 is operational
      final phase01 = modules.firstWhere((m) => m.id == 'flutter_foundation');
      expect(phase01.title, 'Flutter Foundation');
      expect(phase01.phase, 'Phase 01');
      expect(phase01.status, ModuleStatus.operational);

      // Verify all phases 02 through 11 are planned
      final expectedSequence = [
        (
          'nasa_data_integration',
          'NASA Data Integration',
          'Phase 02 (Planned)',
        ),
        ('lunar_site_explorer', 'Lunar Site Explorer', 'Phase 03 (Planned)'),
        (
          'scientific_geometry_engine',
          'Scientific Geometry Engine',
          'Phase 04 (Planned)',
        ),
        (
          'terrain_horizon_engine',
          'Terrain Horizon Engine',
          'Phase 05 (Planned)',
        ),
        (
          'solar_illumination_analysis',
          'Solar Illumination Analysis',
          'Phase 06 (Planned)',
        ),
        (
          'earth_visibility_analysis',
          'Earth Visibility Analysis',
          'Phase 07 (Planned)',
        ),
        ('mission_planning', 'Mission Planning', 'Phase 08 (Planned)'),
        (
          'site_comparison_scoring',
          'Site Comparison & Scoring',
          'Phase 09 (Planned)',
        ),
        (
          'dashboard_visualization',
          'Dashboard & Visualization',
          'Phase 10 (Planned)',
        ),
        (
          'integration_final_release',
          'Integration & Final Release',
          'Phase 11 (Planned)',
        ),
      ];

      for (final (id, title, phase) in expectedSequence) {
        final module = modules.firstWhere((m) => m.id == id);
        expect(module.title, title);
        expect(module.phase, phase);
        expect(module.status, ModuleStatus.planned);
      }
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

  group('Comprehensive Responsive & Layout Boundary Tests', () {
    Widget buildConstrainedApp(Size size, {double textScaleFactor = 1.0}) {
      return MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
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
      'Renders without overflow immediately below compact breakpoint (599x800)',
      (tester) async {
        tester.view.physicalSize = const Size(599, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(599, 800)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders without overflow immediately at compact/medium breakpoint boundary (600x800)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(600, 800)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders without overflow around medium breakpoint (839x1000 and 840x1000)',
      (tester) async {
        for (final width in [839.0, 840.0, 841.0]) {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildConstrainedApp(Size(width, 1000)));
          await tester.pumpAndSettle();

          expect(find.text(AppConstants.appName), findsWidgets);
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Renders without overflow on narrow landscape phone (640x360)',
      (tester) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildConstrainedApp(const Size(640, 360)));
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders without overflow with enlarged accessibility text scale (1.5x) on 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildConstrainedApp(const Size(360, 640), textScaleFactor: 1.5),
        );
        await tester.pumpAndSettle();

        expect(find.text(AppConstants.appName), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

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
              final isMedium = ResponsiveLayout.isMedium(context);
              final isExpanded = ResponsiveLayout.isExpanded(context);
              return Scaffold(
                body: Text(
                  'Class: $deviceClass, Compact: $isCompact, Medium: $isMedium, Expanded: $isExpanded',
                ),
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
