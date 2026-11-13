import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/lunar_sites/lunar_sites.dart';

void main() {
  group('LunarCoordinates Domain Tests & Numeric Hardening', () {
    test('Constructs valid coordinates within boundaries', () {
      final coords = LunarCoordinates(
        latitude: -89.9,
        longitude: 120.5,
        longitudeConvention: LongitudeConvention.eastPositive,
        provenance: CoordinateProvenance.userEntered,
        altitudeMeters: -1250.0,
      );

      expect(coords.latitude, -89.9);
      expect(coords.longitude, 120.5);
      expect(coords.longitudeConvention, LongitudeConvention.eastPositive);
      expect(coords.provenance, CoordinateProvenance.userEntered);
      expect(coords.altitudeMeters, -1250.0);
    });

    test(
      'Throws ArgumentError if latitude exceeds bounds or is NaN/infinite',
      () {
        expect(
          () => LunarCoordinates(latitude: -90.001, longitude: 0.0),
          throwsArgumentError,
        );
        expect(
          () => LunarCoordinates(latitude: 90.001, longitude: 0.0),
          throwsArgumentError,
        );
        expect(
          () => LunarCoordinates(latitude: double.nan, longitude: 0.0),
          throwsArgumentError,
        );
        expect(
          () => LunarCoordinates(latitude: double.infinity, longitude: 0.0),
          throwsArgumentError,
        );
        expect(
          () => LunarCoordinates(
            latitude: double.negativeInfinity,
            longitude: 0.0,
          ),
          throwsArgumentError,
        );
      },
    );

    test('Throws ArgumentError if longitude is NaN/infinite or exceeds [-180, 360]', () {
      expect(
        () => LunarCoordinates(latitude: 0.0, longitude: -180.001),
        throwsArgumentError,
      );
      expect(
        () => LunarCoordinates(latitude: 0.0, longitude: 360.001),
        throwsArgumentError,
      );
      expect(
        () => LunarCoordinates(latitude: 0.0, longitude: double.nan),
        throwsArgumentError,
      );
      expect(
        () => LunarCoordinates(latitude: 0.0, longitude: double.infinity),
        throwsArgumentError,
      );
      expect(
        () =>
            LunarCoordinates(latitude: 0.0, longitude: double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if altitude is NaN or infinite', () {
      expect(
        () => LunarCoordinates(
          latitude: 0.0,
          longitude: 0.0,
          altitudeMeters: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => LunarCoordinates(
          latitude: 0.0,
          longitude: 0.0,
          altitudeMeters: double.infinity,
        ),
        throwsArgumentError,
      );
      expect(
        () => LunarCoordinates(
          latitude: 0.0,
          longitude: 0.0,
          altitudeMeters: double.negativeInfinity,
        ),
        throwsArgumentError,
      );
    });

    test(
      'Validates latitude and longitude accurately via static validators',
      () {
        expect(LunarCoordinates.validateLatitude(null), isNotNull);
        expect(
          LunarCoordinates.validateLatitude(double.nan),
          contains('finite'),
        );
        expect(
          LunarCoordinates.validateLatitude(double.infinity),
          contains('finite'),
        );
        expect(
          LunarCoordinates.validateLatitude(double.negativeInfinity),
          contains('finite'),
        );
        expect(LunarCoordinates.validateLatitude(-90.1), isNotNull);
        expect(LunarCoordinates.validateLatitude(90.1), isNotNull);
        expect(LunarCoordinates.validateLatitude(-90.0), isNull);
        expect(LunarCoordinates.validateLatitude(-89.9), isNull);
        expect(LunarCoordinates.validateLatitude(0.0), isNull);
        expect(LunarCoordinates.validateLatitude(90.0), isNull);

        expect(LunarCoordinates.validateLongitude(null), isNotNull);
        expect(
          LunarCoordinates.validateLongitude(double.nan),
          contains('finite'),
        );
        expect(
          LunarCoordinates.validateLongitude(double.infinity),
          contains('finite'),
        );
        expect(
          LunarCoordinates.validateLongitude(double.negativeInfinity),
          contains('finite'),
        );
        expect(LunarCoordinates.validateLongitude(-180.1), isNotNull);
        expect(LunarCoordinates.validateLongitude(360.1), isNotNull);
        expect(LunarCoordinates.validateLongitude(-180.0), isNull);
        expect(LunarCoordinates.validateLongitude(-179.0), isNull);
        expect(LunarCoordinates.validateLongitude(0.0), isNull);
        expect(LunarCoordinates.validateLongitude(360.0), isNull);

        expect(LunarCoordinates.validateAltitude(null), isNull);
        expect(LunarCoordinates.validateAltitude(-2500.0), isNull);
        expect(
          LunarCoordinates.validateAltitude(double.nan),
          contains('finite'),
        );
        expect(
          LunarCoordinates.validateAltitude(double.infinity),
          contains('finite'),
        );
      },
    );

    test('Formats coordinates correctly with directional conventions', () {
      final eastPositive = LunarCoordinates(
        latitude: -89.9,
        longitude: 120.0,
        longitudeConvention: LongitudeConvention.eastPositive,
      );
      expect(eastPositive.formattedCoordinates, '89.9000° S, 120.0000° E');

      final westPositive = LunarCoordinates(
        latitude: 15.5,
        longitude: 45.0,
        longitudeConvention: LongitudeConvention.westPositive,
      );
      expect(westPositive.formattedCoordinates, '15.5000° N, 45.0000° W');

      final negativeEast = LunarCoordinates(
        latitude: -10.0,
        longitude: -50.0,
        longitudeConvention: LongitudeConvention.eastPositive,
      );
      expect(negativeEast.formattedCoordinates, '10.0000° S, 50.0000° W');
    });

    test('Serializes to and from JSON faithfully', () {
      final original = LunarCoordinates(
        latitude: -85.25,
        longitude: 210.75,
        longitudeConvention: LongitudeConvention.eastPositive,
        provenance: CoordinateProvenance.nasaPublished,
        altitudeMeters: 450.0,
      );

      final json = original.toJson();
      final restored = LunarCoordinates.fromJson(json);

      expect(restored, original);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.longitudeConvention, original.longitudeConvention);
      expect(restored.provenance, original.provenance);
      expect(restored.altitudeMeters, original.altitudeMeters);
    });

    test('Rejects invalid JSON coordinate representations', () {
      expect(
        () => LunarCoordinates.fromJson({
          'latitude': 'invalid',
          'longitude': 0.0,
        }),
        throwsFormatException,
      );
      expect(
        () => LunarCoordinates.fromJson({'latitude': 100.0, 'longitude': 0.0}),
        throwsFormatException,
      );
      expect(
        () => LunarCoordinates.fromJson({'latitude': 0.0, 'longitude': 500.0}),
        throwsFormatException,
      );
      expect(
        () => LunarCoordinates.fromJson({
          'latitude': 0.0,
          'longitude': 0.0,
          'altitude_meters': 'not_a_number',
        }),
        throwsFormatException,
      );
    });
  });

  group('LunarSite Domain & Model Tests', () {
    test(
      'Constructs site without coordinates and maintains hasCoordinates flag',
      () {
        final site = LunarSite(
          id: 'test_p78_site',
          name: 'Test Polar Ridge',
          siteCode: 'SiteXX',
          classification: SiteClassification.nasaCatalogRegion,
          coordinates: null,
          sourceId: 'NASA_PGDA_PRODUCT_78',
          sourceOrganization: 'NASA GSFC PGDA',
          sourceUrl: Uri.parse('https://pgda.gsfc.nasa.gov/products/78'),
          citation: 'Barker et al. (2021)',
          description: 'Test region description',
          relatedProductIds: const [],
        );

        expect(site.hasCoordinates, isFalse);
        expect(site.coordinates, isNull);
        expect(site.relatedProductIds, isEmpty);
      },
    );

    test('LunarSiteModel serialization preserves all fields', () {
      final model = LunarSiteModel(
        id: 'model_site_01',
        name: 'Model Site',
        siteCode: 'MS1',
        classification: SiteClassification.userDefined,
        coordinates: LunarCoordinates(
          latitude: -88.5,
          longitude: 45.0,
          longitudeConvention: LongitudeConvention.eastPositive,
          provenance: CoordinateProvenance.userEntered,
          altitudeMeters: -500.0,
        ),
        sourceId: 'USER_DEFINED',
        sourceOrganization: 'User Defined',
        sourceUrl: Uri.parse('https://example.com/site'),
        citation: 'User Citation',
        description: 'Test User Site',
        relatedProductIds: const [],
      );

      final json = model.toJson();
      final restored = LunarSiteModel.fromJson(json);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.siteCode, model.siteCode);
      expect(restored.classification, model.classification);
      expect(restored.hasCoordinates, isTrue);
      expect(restored.coordinates, model.coordinates);
      expect(restored.sourceId, model.sourceId);
      expect(restored.sourceOrganization, model.sourceOrganization);
      expect(restored.sourceUrl, model.sourceUrl);
      expect(restored.citation, model.citation);
      expect(restored.description, model.description);
      expect(restored.relatedProductIds, model.relatedProductIds);
    });
  });

  group('BundledLunarSiteCatalog Verification', () {
    test('Contains exactly 27 official NASA Product 78 regions', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      expect(sites.length, 27);
    });

    test('Sites 1, 4, 7, and 11 are classified as highPriorityLandingSiteRegion and others as nasaCatalogRegion', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      final highPrioritySites = sites
          .where(
            (s) =>
                s.classification ==
                SiteClassification.highPriorityLandingSiteRegion,
          )
          .toList();

      expect(highPrioritySites.length, 4);
      expect(highPrioritySites.map((s) => s.siteCode).toSet(), {
        'Site01',
        'Site04',
        'Site07',
        'Site11',
      });

      final catalogRegions = sites
          .where(
            (s) => s.classification == SiteClassification.nasaCatalogRegion,
          )
          .toList();
      expect(catalogRegions.length, 23);
    });

    test('All 27 sites contain verified NASA PGDA Product 78 provenance and null coordinates', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      for (final site in sites) {
        expect(site.sourceId, 'NASA_PGDA_PRODUCT_78');
        expect(site.sourceOrganization, 'NASA GSFC PGDA');
        expect(
          site.sourceUrl.toString(),
          'https://pgda.gsfc.nasa.gov/products/78',
        );
        expect(site.citation, contains('Barker, M. K.'));
        expect(site.citation, contains('Product 78'));
        expect(site.name.trim().isNotEmpty, isTrue);
        expect(site.description.trim().isNotEmpty, isTrue);
        expect(site.coordinates, isNull);
      }
    });

    test('Zero Product 78 sites have unsupported Product 81 relatedProductIds', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      for (final site in sites) {
        expect(
          site.relatedProductIds,
          isEmpty,
          reason:
              '${site.siteCode} must not link to Product 81 without explicit source documentation',
        );
      }
    });
  });

  group('LocalLunarSiteRepository Operation & Custom Site Lifecycle', () {
    late LocalLunarSiteRepository repository;

    setUp(() {
      repository = LocalLunarSiteRepository();
    });

    test('getAllSites returns initial 27 official sites', () async {
      final sites = await repository.getAllSites();
      expect(sites.length, 27);
    });

    test('getSiteById returns site if present, or null if absent', () async {
      final site = await repository.getSiteById('nasa_p78_site01');
      expect(site, isNotNull);
      expect(site!.siteCode, 'Site01');

      final absent = await repository.getSiteById('non_existent_site');
      expect(absent, isNull);
    });

    test(
      'searchSites filters accurately across name, code, and description',
      () async {
        final shackletons = await repository.searchSites('Shackleton');
        expect(shackletons.isNotEmpty, isTrue);
        for (final s in shackletons) {
          final matches =
              s.name.contains('Shackleton') ||
              s.description.contains('Shackleton') ||
              s.siteCode.contains('Shackleton');
          expect(matches, isTrue);
        }

        final byCode = await repository.searchSites('LM3');
        expect(byCode.length, 1);
        expect(byCode.first.siteCode, 'LM3');

        final emptyQuery = await repository.searchSites('   ');
        expect(emptyQuery.length, 27);
      },
    );

    test('filterSites filters by classification correctly', () async {
      final highPriority = await repository.filterSites(
        classification: SiteClassification.highPriorityLandingSiteRegion,
      );
      expect(highPriority.length, 4);

      final catalogRegions = await repository.filterSites(
        classification: SiteClassification.nasaCatalogRegion,
      );
      expect(catalogRegions.length, 23);
    });

    test('addCustomSite adds new site, validates coordinates, and lists with official sites', () async {
      final customCoords = LunarCoordinates(
        latitude: -89.75,
        longitude: 15.2,
        longitudeConvention: LongitudeConvention.eastPositive,
        provenance: CoordinateProvenance.userEntered,
        altitudeMeters: -100.0,
      );

      final created = await repository.addCustomSite(
        name: 'Artemis Study Alpha',
        coordinates: customCoords,
        description: 'Candidate test point',
      );

      expect(created.id, startsWith('custom_site_'));
      expect(created.name, 'Artemis Study Alpha');
      expect(created.classification, SiteClassification.userDefined);
      expect(created.coordinates, customCoords);
      expect(created.hasCoordinates, isTrue);

      final all = await repository.getAllSites();
      expect(all.length, 28);
      expect(all.contains(created), isTrue);

      final userSites = await repository.filterSites(
        classification: SiteClassification.userDefined,
      );
      expect(userSites.length, 1);
      expect(userSites.first, created);

      // Deletion of custom site
      final deleted = await repository.deleteCustomSite(created.id);
      expect(deleted, isTrue);

      final allAfterDelete = await repository.getAllSites();
      expect(allAfterDelete.length, 27);
      expect(allAfterDelete.contains(created), isFalse);
    });
  });
}
