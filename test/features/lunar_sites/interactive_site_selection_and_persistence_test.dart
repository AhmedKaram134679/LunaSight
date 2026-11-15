import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/home/presentation/pages/home_page.dart';
import 'package:luna_sight/features/lunar_sites/data/repositories/local_lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/lunar_map_coordinates_helper.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/lunar_site_details_page.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/lunar_site_explorer_page.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/site_comparison_page.dart';
import 'package:luna_sight/features/lunar_sites/presentation/widgets/lunar_polar_map_widget.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/mission_time_planner_page.dart';
import 'package:luna_sight/features/solar_earth_visibility/presentation/pages/visibility_analysis_page.dart';

void main() {
  group('Interactive Lunar Map Coordinates & Projection Mathematics', () {
    const helper = LunarMapCoordinatesHelper();
    const canvasSize = Size(400, 400);
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final mapRadius = 400 * 0.44; // 176.0

    test('Center tap maps strictly to Lunar South Pole (-90.0°S, 0.0°E)', () {
      final (lat, lon) = helper.screenOffsetToCoordinates(center, canvasSize);
      expect(lat, closeTo(-90.0, 1e-5));
      expect(lon, closeTo(0.0, 1e-5));
      expect(
        LunarMapCoordinatesHelper.distanceToSouthPoleKm(lat),
        closeTo(0.0, 1e-3),
      );
    });

    test('Prime Meridian (0°E, North) tap maps to expected latitude and 0° longitude', () {
      // Tap upwards (-Y) from center by half radius -> -85.0° latitude, 0° longitude
      final tapPos = Offset(center.dx, center.dy - (mapRadius * 0.5));
      final (lat, lon) = helper.screenOffsetToCoordinates(tapPos, canvasSize);
      expect(lat, closeTo(-85.0, 0.01));
      expect(lon, closeTo(0.0, 0.01));
    });

    test('East (90°E) tap maps to +90° longitude', () {
      // Tap right (+X) from center by half radius
      final tapPos = Offset(center.dx + (mapRadius * 0.5), center.dy);
      final (lat, lon) = helper.screenOffsetToCoordinates(tapPos, canvasSize);
      expect(lat, closeTo(-85.0, 0.01));
      expect(lon, closeTo(90.0, 0.01));
    });

    test('Far side (180°E) tap maps to +180° longitude', () {
      // Tap downwards (+Y) from center
      final tapPos = Offset(center.dx, center.dy + (mapRadius * 0.5));
      final (lat, lon) = helper.screenOffsetToCoordinates(tapPos, canvasSize);
      expect(lat, closeTo(-85.0, 0.01));
      expect(lon, closeTo(180.0, 0.01));
    });

    test(
      'West (270°E) tap maps to +270° longitude in East-positive convention',
      () {
        // Tap left (-X) from center
        final tapPos = Offset(center.dx - (mapRadius * 0.5), center.dy);
        final (lat, lon) = helper.screenOffsetToCoordinates(tapPos, canvasSize);
        expect(lat, closeTo(-85.0, 0.01));
        expect(lon, closeTo(270.0, 0.01));
      },
    );

    test('Outer boundary limit clamps latitude to map boundary (-80.0°)', () {
      // Tap far outside the map circle (e.g. at corner)
      final cornerPos = const Offset(10, 10);
      final (lat, lon) = helper.screenOffsetToCoordinates(
        cornerPos,
        canvasSize,
      );
      expect(lat, closeTo(-80.0, 0.01));
      expect(lon, inInclusiveRange(0.0, 360.0));
    });

    test('Forward and inverse projection round-trip identity preserves coordinates', () {
      const testCoordinates = [
        (-89.9, 0.0),
        (-88.5, 45.0),
        (-87.0, 120.0),
        (-86.2, 210.0),
        (-84.1, 315.0),
      ];

      for (final (origLat, origLon) in testCoordinates) {
        final screenPos = helper.coordinatesToScreenOffset(
          origLat,
          origLon,
          canvasSize,
        );
        final (calcLat, calcLon) = helper.screenOffsetToCoordinates(
          screenPos,
          canvasSize,
        );

        expect(
          calcLat,
          closeTo(origLat, 0.01),
          reason: 'Latitude roundtrip failed for $origLat',
        );
        expect(
          calcLon,
          closeTo(origLon, 0.01),
          reason: 'Longitude roundtrip failed for $origLon',
        );
      }
    });

    test('Nearest landmark identifies Shackleton Crater at South Pole', () {
      final info = helper.findNearestLandmark(-89.9, 0.0);
      expect(info.landmark.name, 'Shackleton Crater');
      expect(info.distanceKm, lessThan(2.0));
    });

    test('Nearest landmark identifies Faustini Crater near 87°S, 77°E', () {
      final info = helper.findNearestLandmark(-87.1, 77.0);
      expect(info.landmark.name, 'Faustini Crater');
      expect(info.distanceKm, lessThan(1.0));
    });

    test('Location evaluation generates un-fabricated terrain status and live celestial visibility', () {
      final loc = helper.evaluateSelectedLocation(
        latitude: -88.5,
        longitude: 140.0,
        existingSites: const [],
      );

      expect(loc.formattedLatitude, '88.5000°S');
      expect(loc.formattedLongitudeEast, '140.0000°E');
      expect(loc.distanceToSouthPoleKm, closeTo(45.48, 0.5));
      expect(loc.terrainStatus.datumDescription, contains('1,737,400.0 m'));
      expect(
        loc.terrainStatus.measurementNotice,
        contains('Synthetic elevations strictly avoided'),
      );
      expect(loc.visibility.sunElevationDegrees.isFinite, isTrue);
      expect(loc.visibility.earthElevationDegrees.isFinite, isTrue);
    });
  });

  group('LocalLunarSiteRepository Persistence & Invariants', () {
    late Directory tempDir;
    late File storageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('luna_sight_repo_test_');
      storageFile = File('${tempDir.path}/custom_lunar_sites.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Saves custom site to persistent file and reloads upon re-instantiation',
      () async {
        final repo1 = LocalLunarSiteRepository(
          storageFileOverride: storageFile,
        );
        final initialCount = (await repo1.getAllSites()).length;

        final coords = LunarCoordinates(
          latitude: -88.4215,
          longitude: 142.3051,
          longitudeConvention: LongitudeConvention.eastPositive,
          provenance: CoordinateProvenance.userEntered,
        );

        final savedSite = await repo1.addCustomSite(
          name: 'Artemis Alpha Landing Point',
          coordinates: coords,
          description: 'Targeted polar rim landing coordinates.',
        );

        expect(savedSite.id, startsWith('custom_site_'));
        expect(savedSite.name, 'Artemis Alpha Landing Point');
        expect(savedSite.coordinates?.latitude, -88.4215);
        expect(await storageFile.exists(), isTrue);

        // Verify second repository instance pointing to same file loads persisted site
        final repo2 = LocalLunarSiteRepository(
          storageFileOverride: storageFile,
        );
        final sitesAfterRestart = await repo2.getAllSites();
        expect(sitesAfterRestart.length, initialCount + 1);

        final found = await repo2.getSiteById(savedSite.id);
        expect(found, isNotNull);
        expect(found!.name, 'Artemis Alpha Landing Point');
        expect(found.coordinates?.latitude, -88.4215);
        expect(found.coordinates?.longitude, 142.3051);
      },
    );

    test('Duplicate site name is strictly rejected', () async {
      final repo = LocalLunarSiteRepository(storageFileOverride: storageFile);

      final coords = LunarCoordinates(latitude: -89.0, longitude: 10.0);

      await repo.addCustomSite(
        name: 'Unique Candidate Zeta',
        coordinates: coords,
      );

      // Attempting to add duplicate name throws ArgumentError
      expect(
        () => repo.addCustomSite(
          name: 'Unique Candidate Zeta',
          coordinates: coords,
        ),
        throwsArgumentError,
      );

      // Case-insensitive duplicate name is also rejected
      expect(
        () => repo.addCustomSite(
          name: 'unique candidate zeta',
          coordinates: coords,
        ),
        throwsArgumentError,
      );
    });

    test(
      'Invalid coordinates are rejected with descriptive ArgumentError',
      () async {
        final repo = LocalLunarSiteRepository(storageFileOverride: storageFile);

        expect(
          () => repo.addCustomSite(
            name: 'Invalid Lat Site',
            coordinates: LunarCoordinates(latitude: -95.0, longitude: 0.0),
          ),
          throwsArgumentError,
        );

        expect(
          () => repo.addCustomSite(
            name: '',
            coordinates: LunarCoordinates(latitude: -88.0, longitude: 0.0),
          ),
          throwsArgumentError,
        );
      },
    );

    test('Deleting custom site removes it from disk persistence', () async {
      final repo = LocalLunarSiteRepository(storageFileOverride: storageFile);

      final site = await repo.addCustomSite(
        name: 'Temporary Evaluation Site',
        coordinates: LunarCoordinates(latitude: -88.0, longitude: 50.0),
      );

      expect(await repo.getSiteById(site.id), isNotNull);

      final deleted = await repo.deleteCustomSite(site.id);
      expect(deleted, isTrue);

      // Reload repo and verify site is gone
      await repo.reload();
      expect(await repo.getSiteById(site.id), isNull);
    });
  });

  group('LunarPolarMapWidget Interactive Tap & Registration UI Tests', () {
    late Directory tempDir;
    late File storageFile;
    late LocalLunarSiteRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('luna_sight_widget_test_');
      storageFile = File('${tempDir.path}/test_custom_sites.json');
      repository = LocalLunarSiteRepository(storageFileOverride: storageFile);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'Tapping on polar map converts coordinates, updates reticle, and displays location card',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sites = await repository.getAllSites();
        SelectedLunarLocation? selectedLoc;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LunarPolarMapWidget(
                  sites: sites,
                  repository: repository,
                  enablePulseAnimation: false,
                  onLocationSelected: (loc) => selectedLoc = loc,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final canvasFinder = find.byKey(const Key('lunar_polar_map_canvas'));
        expect(canvasFinder, findsOneWidget);

        await tester.tapAt(
          tester.getCenter(canvasFinder) + const Offset(40, -40),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(selectedLoc, isNotNull);
        expect(selectedLoc!.latitude, inInclusiveRange(-90.0, -80.0));
        expect(selectedLoc!.longitude, inInclusiveRange(0.0, 360.0));

        // Selected Location Card is displayed with coordinates and Save button
        expect(find.textContaining('Selenographic'), findsWidgets);
        expect(
          find.byKey(const Key('save_selected_location_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Complete registration workflow: Tap -> Inspect -> Save -> Confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sites = await repository.getAllSites();
        LunarSite? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LunarPolarMapWidget(
                  sites: sites,
                  repository: repository,
                  enablePulseAnimation: false,
                  onSiteSaved: (site) => savedResult = site,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 1. Tap on the map to choose a location
        final canvasFinder = find.byKey(const Key('lunar_polar_map_canvas'));
        await tester.tapAt(
          tester.getCenter(canvasFinder) + const Offset(50, 30),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 2. Tap "Save Custom Landing Site"
        final saveButton = find.byKey(
          const Key('save_selected_location_button'),
        );
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pump(const Duration(milliseconds: 400));

        // 3. Modal bottom sheet opens with site name and save button
        expect(find.text('Save Custom Landing Site'), findsWidgets);
        final nameInput = find.byKey(const Key('custom_site_name_input'));
        expect(nameInput, findsOneWidget);

        await tester.enterText(nameInput, 'Shackleton South Basin Alpha');
        await tester.pump(const Duration(milliseconds: 200));

        // 4. Confirm Save
        final confirmBtn = find.byKey(
          const Key('confirm_save_custom_site_button'),
        );
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pump(const Duration(milliseconds: 400));

        // 5. Verify site was saved and callback fired
        expect(savedResult, isNotNull);
        expect(savedResult!.name, 'Shackleton South Basin Alpha');
        expect(savedResult!.classification, SiteClassification.userDefined);

        // Verify persistent disk write
        expect(storageFile.existsSync(), isTrue);
        final reloadedSites = await repository.getAllSites();
        expect(
          reloadedSites.any((s) => s.name == 'Shackleton South Basin Alpha'),
          isTrue,
        );

        // Dismiss SnackBar and drain its timer
        ScaffoldMessenger.of(tester.element(canvasFinder)).clearSnackBars();
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('Cross-Screen Integration of Saved Custom Site', () {
    late Directory tempDir;
    late File storageFile;
    late LocalLunarSiteRepository repository;
    late LunarSite customSite;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'luna_sight_integration_test_',
      );
      storageFile = File('${tempDir.path}/shared_custom_sites.json');
      repository = LocalLunarSiteRepository(storageFileOverride: storageFile);

      customSite = await repository.addCustomSite(
        name: 'Artemis VII Basecamp Site',
        coordinates: LunarCoordinates(
          latitude: -88.95,
          longitude: 215.4,
          altitudeMeters: -1250.0,
        ),
        description: 'Persistent high-latitude candidate basecamp.',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'Custom site appears in LunarSiteExplorerPage list and search',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(home: LunarSiteExplorerPage(repository: repository)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Search for the custom site
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'Artemis VII');
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Artemis VII Basecamp Site'), findsOneWidget);
        expect(find.text('USER DEFINED'), findsOneWidget);
      },
    );

    testWidgets(
      'Custom site opens LunarSiteDetailsPage with verified geometry',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(home: LunarSiteDetailsPage(site: customSite)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Artemis VII Basecamp Site'), findsWidgets);
        expect(find.text('USER DEFINED CANDIDATE'), findsOneWidget);
        expect(find.textContaining('-88.9500'), findsOneWidget);
        expect(find.textContaining('215.4000'), findsWidgets);
      },
    );

    testWidgets(
      'Custom site is selectable in VisibilityAnalysisPage dropdown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: VisibilityAnalysisPage(
              initialSite: customSite,
              repository: repository,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.textContaining('Artemis VII Basecamp Site'), findsWidgets);
        expect(find.text('LOCAL HORIZON SKY DOME (SEZ FRAME)'), findsOneWidget);
      },
    );

    testWidgets(
      'Custom site is selectable in MissionTimePlannerPage dropdown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: MissionTimePlannerPage(
              initialSite: customSite,
              repository: repository,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.textContaining('Artemis VII Basecamp Site'), findsWidgets);
        expect(find.text('Artemis Lunar Mission Parameters'), findsOneWidget);
      },
    );

    testWidgets('Custom site is selectable in SiteComparisonPage dropdown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(home: SiteComparisonPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Candidate Site Comparison'), findsOneWidget);
    });

    testWidgets(
      'Custom site appears in HomePage active landing site selector chips',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(home: HomePage(lunarSiteRepository: repository)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.textContaining('Artemis VII Basecamp Site'),
          findsOneWidget,
        );
      },
    );
  });
}
