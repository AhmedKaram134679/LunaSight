import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/lunar_sites/data/datasources/bundled_lunar_site_catalog.dart';
import 'package:luna_sight/features/lunar_sites/data/repositories/local_lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/site_scientific_analysis_service.dart';
import 'package:luna_sight/features/lunar_sites/presentation/pages/site_comparison_page.dart';

void main() {
  group('SiteScientificAnalysisService Tests', () {
    const service = SiteScientificAnalysisService();

    test('Returns null analysis for catalog site with null coordinates', () {
      final site = BundledLunarSiteCatalog.officialSites.firstWhere(
        (s) => s.siteCode == 'Site01',
      );
      expect(site.coordinates, isNull);

      final analysis = service.analyzeSite(site);
      expect(analysis, isNull);
    });

    test('Computes exact body-fixed Cartesian coordinates at South Pole', () {
      final polarSite = LunarSite(
        id: 'test_south_pole',
        name: 'Exact South Pole Candidate',
        siteCode: 'SP01',
        classification: SiteClassification.userDefined,
        coordinates: LunarCoordinates(
          latitude: -90.0,
          longitude: 0.0,
          altitudeMeters: 0.0,
        ),
        sourceId: 'USER_TEST',
        sourceOrganization: 'Test Org',
        citation: 'Test Citation',
        description: 'Test Description',
      );

      final analysis = service.analyzeSite(polarSite);
      expect(analysis, isNotNull);

      // At exact South Pole (R = 1737.4 km, h = 0):
      // X = 0.0, Y = 0.0, Z = -1,737,400.0 m
      expect(analysis!.bodyFixedCartesian.vector.x.abs(), lessThan(1e-6));
      expect(analysis.bodyFixedCartesian.vector.y.abs(), lessThan(1e-6));
      expect(analysis.bodyFixedCartesian.vector.z, closeTo(-1737400.0, 1e-6));

      // Distance to South Pole is 0.0 km
      expect(analysis.distanceToSouthPoleKm, closeTo(0.0, 1e-6));

      // Zenith is (0, 0, -1) pointing outward
      expect(analysis.horizonBasis.zenith.x, closeTo(0.0, 1e-6));
      expect(analysis.horizonBasis.zenith.y, closeTo(0.0, 1e-6));
      expect(analysis.horizonBasis.zenith.z, closeTo(-1.0, 1e-6));
    });

    test('Computes Cartesian coordinates for non-polar candidate site', () {
      final site = LunarSite(
        id: 'test_shackleton_rim',
        name: 'Shackleton Rim Candidate',
        siteCode: 'SHK01',
        classification: SiteClassification.userDefined,
        coordinates: LunarCoordinates(
          latitude: -89.9,
          longitude: 0.0,
          altitudeMeters: 1000.0, // 1 km elevation
        ),
        sourceId: 'USER_TEST',
        sourceOrganization: 'Test Org',
        citation: 'Test Citation',
        description: 'Test Description',
      );

      final analysis = service.analyzeSite(site);
      expect(analysis, isNotNull);

      // Effective radius = 1737400 + 1000 = 1738.4 km
      expect(analysis!.effectiveRadiusKm, closeTo(1738.4, 1e-4));

      // Distance to South Pole: 0.1 deg * (pi/180) * 1737.4 km ~ 3.032 km
      expect(analysis.distanceToSouthPoleKm, closeTo(3.032, 0.01));
    });
  });

  group('SiteComparisonPage Widget Tests', () {
    testWidgets(
      'Renders site selectors, matrix rows, and integrity policy notice',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = LocalLunarSiteRepository();

        await tester.pumpWidget(
          MaterialApp(home: SiteComparisonPage(repository: repository)),
        );
        await tester.pumpAndSettle();

        // Verify Header & Title
        expect(find.text('Candidate Site Comparison'), findsOneWidget);
        expect(find.text('Candidate Site Comparison Matrix'), findsOneWidget);

        // Verify Selectors
        expect(find.text('Candidate Site A'), findsOneWidget);
        expect(find.text('Candidate Site B'), findsOneWidget);

        // Verify Integrity Notice
        expect(
          find.text('Scientific Integrity & Objectivity Policy'),
          findsOneWidget,
        );
        expect(
          find.textContaining('LunaSight compares only verified observational'),
          findsOneWidget,
        );
      },
    );
  });
}
