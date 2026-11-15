import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/theme/app_theme.dart';
import 'package:luna_sight/features/lunar_sites/lunar_sites.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/services/celestial_visibility_service.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/mission_time_planner_page.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/visibility_analysis_page.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
      routes: {
        '/visibility': (_) =>
            VisibilityAnalysisPage(repository: LocalLunarSiteRepository()),
        '/planner': (_) =>
            MissionTimePlannerPage(repository: LocalLunarSiteRepository()),
      },
    );
  }

  group('CelestialVisibilityService Domain Tests', () {
    const service = CelestialVisibilityService();

    test('Computes valid solar and Earth angles at Shackleton Rim', () {
      final state = service.computeVisibility(
        latitudeDeg: -89.9,
        longitudeDeg: 0.0,
        epochHours: 72.0, // 3 days into cycle
      );

      expect(state.sunElevationDegrees.isFinite, isTrue);
      expect(state.sunAzimuthDegrees.isFinite, isTrue);
      expect(state.earthElevationDegrees.isFinite, isTrue);
      expect(state.earthAzimuthDegrees.isFinite, isTrue);

      // Verify orthonormal SEZ horizon basis
      final uS = state.horizonBasis.south;
      final uE = state.horizonBasis.east;
      final uZ = state.horizonBasis.zenith;

      expect(uS.magnitude, closeTo(1.0, 1e-12));
      expect(uE.magnitude, closeTo(1.0, 1e-12));
      expect(uZ.magnitude, closeTo(1.0, 1e-12));
      expect(uS.dot(uE).abs(), lessThan(1e-12));
      expect(uS.dot(uZ).abs(), lessThan(1e-12));
      expect(uE.dot(uZ).abs(), lessThan(1e-12));

      // Demonstration flag asserted
      expect(state.isDemonstrationEphemeris, isTrue);
    });

    test('Generates mission time windows over 14 Earth days', () {
      final windows = service.generateMissionWindows(
        latitudeDeg: -89.9,
        longitudeDeg: 0.0,
        totalDurationHours: 336.0,
        timeStepHours: 4.0,
      );

      expect(windows.isNotEmpty, isTrue);
      for (final w in windows) {
        expect(w.durationHours, greaterThan(0.0));
        expect(w.label.isNotEmpty, isTrue);
      }
    });
  });

  group('VisibilityAnalysisPage Widget Tests', () {
    late LocalLunarSiteRepository repository;

    setUp(() {
      repository = LocalLunarSiteRepository();
    });

    testWidgets('Renders celestial sky dome visualizer and telemetry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(VisibilityAnalysisPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solar & Earth Visibility'), findsOneWidget);
      expect(find.text('Target Site:'), findsOneWidget);
      expect(find.text('LOCAL HORIZON SKY DOME (SEZ FRAME)'), findsOneWidget);
      expect(find.text('Solar Illumination Status'), findsOneWidget);
      expect(find.text('Earth Visibility & Comm Link'), findsOneWidget);
      expect(find.text('Scientific Domain Engine Integration'), findsOneWidget);
      expect(find.text('PHASE 06 M03 ACTIVE'), findsOneWidget);
    });
  });

  group('MissionTimePlannerPage Widget Tests', () {
    late LocalLunarSiteRepository repository;

    setUp(() {
      repository = LocalLunarSiteRepository();
    });

    testWidgets(
      'Renders timeline, multi-track Gantt, and operational milestones',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestableWidget(MissionTimePlannerPage(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mission Time Planner'), findsOneWidget);
        expect(find.text('Artemis Lunar Mission Parameters'), findsOneWidget);
        expect(
          find.text('Solar Illumination & Earth Comm Timeline'),
          findsOneWidget,
        );
        expect(
          find.text('Planned Surface Operational Milestones'),
          findsOneWidget,
        );
        expect(find.text('Lunar Descent & Touchdown'), findsOneWidget);
        expect(find.text('Lander Power & Thermal Simulation'), findsOneWidget);
      },
    );
  });
}
