import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/app/theme/app_theme.dart';
import 'package:luna_sight/features/lunar_sites/lunar_sites.dart';
import 'package:luna_sight/features/nasa_data/nasa_data.dart';

class _MockNasaDataRepository implements NasaDataRepository {
  _MockNasaDataRepository();

  @override
  Future<bool> isAssetLocallyAvailable(String productId) async {
    return false;
  }

  @override
  Future<LocalAssetMetadata> acquireProductAsset(
    String productId, {
    bool forceReacquire = false,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelAcquisition(String productId) =>
      throw UnimplementedError();

  @override
  AcquisitionProgress getAcquisitionProgress(String productId) =>
      throw UnimplementedError();

  @override
  List<NasaProductDefinition> getAvailableProducts() => const [];

  @override
  Future<LocalAssetMetadata?> getLocalAssetMetadata(String productId) async =>
      null;

  @override
  Future<NasaProductDefinition?> getProductById(String productId) async => null;

  @override
  Future<void> removeCachedAsset(String productId) async {}

  @override
  Stream<AcquisitionProgress> watchAcquisitionProgress(String productId) =>
      const Stream.empty();
}

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(theme: AppTheme.darkTheme, home: child);
  }

  group('Lunar Sites Presentation Widget Tests', () {
    late LocalLunarSiteRepository repository;

    setUp(() {
      repository = LocalLunarSiteRepository();
    });

    testWidgets(
      'LunarSiteExplorerPage renders official sites list and classification filters',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestableWidget(LunarSiteExplorerPage(repository: repository)),
        );

        await tester.pumpAndSettle();

        // Title and search bar
        expect(find.text('Lunar Site Explorer'), findsOneWidget);
        expect(
          find.byKey(const Key('lunar_site_search_field')),
          findsOneWidget,
        );

        // Verify cards rendered
        expect(find.text('Connecting Ridge'), findsOneWidget);
        expect(find.text('Site01'), findsOneWidget);
        expect(find.text('Shackleton Rim'), findsOneWidget);

        // Filter chips
        expect(find.byKey(const Key('filter_all')), findsOneWidget);
        expect(find.byKey(const Key('filter_landing_regions')), findsOneWidget);
        expect(find.byKey(const Key('filter_catalog_regions')), findsOneWidget);

        // Filter by Landing Site Regions
        await tester.tap(find.byKey(const Key('filter_landing_regions')));
        await tester.pumpAndSettle();

        expect(find.text('Connecting Ridge'), findsOneWidget);
        expect(find.text('Shackleton Rim'), findsOneWidget);
        expect(find.text('Haworth Crater Region'), findsNothing);

        // Filter by NASA Catalog Regions
        await tester.tap(find.byKey(const Key('filter_catalog_regions')));
        await tester.pumpAndSettle();

        expect(find.text('Haworth Crater Region'), findsOneWidget);
        expect(find.text('Shoemaker Crater Region'), findsOneWidget);
        expect(find.text('Connecting Ridge'), findsNothing);

        // Search field test
        await tester.enterText(
          find.byKey(const Key('lunar_site_search_field')),
          'Haworth',
        );
        await tester.pumpAndSettle();

        expect(find.text('Haworth Crater Region'), findsOneWidget);
        expect(find.text('Shoemaker Crater Region'), findsNothing);
      },
    );

    testWidgets(
      'LunarSiteDetailsPage displays provenance, coordinate warning, and unlinked Product 81 disclaimer',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final site = (await repository.getSiteById('nasa_p78_site01'))!;
        final mockNasaRepo = _MockNasaDataRepository();

        await tester.pumpWidget(
          buildTestableWidget(
            LunarSiteDetailsPage(site: site, nasaDataRepository: mockNasaRepo),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Connecting Ridge'), findsAtLeastNWidgets(1));
        expect(find.text('Point Coordinates Unavailable'), findsOneWidget);
        expect(
          find.text('Scientific Provenance & Documentation'),
          findsOneWidget,
        );
        expect(find.text('NASA_PGDA_PRODUCT_78'), findsOneWidget);
        expect(
          find.textContaining(
            'No specific NASA DEM products are explicitly documented',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CustomSiteEntryPage validates coordinates, altitude, and creates custom site',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestableWidget(CustomSiteEntryPage(repository: repository)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Custom Site Entry'), findsOneWidget);

        // Try submitting empty form
        await tester.ensureVisible(
          find.byKey(const Key('custom_site_submit_button')),
        );
        await tester.tap(find.byKey(const Key('custom_site_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Site name is required'), findsOneWidget);

        // Enter invalid latitude
        await tester.enterText(
          find.byKey(const Key('custom_site_name_field')),
          'Artemis Ridge Alpha',
        );
        await tester.enterText(
          find.byKey(const Key('custom_site_latitude_field')),
          '-95.0',
        );
        await tester.enterText(
          find.byKey(const Key('custom_site_longitude_field')),
          '45.0',
        );

        await tester.ensureVisible(
          find.byKey(const Key('custom_site_submit_button')),
        );
        await tester.tap(find.byKey(const Key('custom_site_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Latitude must be between -90.0° and +90.0°'),
          findsOneWidget,
        );

        // Correct latitude and submit
        await tester.enterText(
          find.byKey(const Key('custom_site_latitude_field')),
          '-89.8500',
        );
        await tester.enterText(
          find.byKey(const Key('custom_site_altitude_field')),
          '-120.5',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('custom_site_submit_button')),
        );
        await tester.tap(find.byKey(const Key('custom_site_submit_button')));
        await tester.pumpAndSettle();

        // Check repository contains created site
        final all = await repository.getAllSites();
        expect(all.length, 28);
        final customSite = all.firstWhere(
          (s) => s.name == 'Artemis Ridge Alpha',
        );
        expect(customSite.coordinates!.latitude, -89.8500);
        expect(customSite.coordinates!.longitude, 45.0);
        expect(customSite.coordinates!.altitudeMeters, -120.5);
        expect(
          customSite.coordinates!.provenance,
          CoordinateProvenance.userEntered,
        );
      },
    );
  });
}
