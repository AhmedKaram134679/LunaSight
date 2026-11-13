import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/lunar_sites/lunar_sites.dart';

void main() {
  group('LunarCoordinates Domain Tests', () {
    test('Constructs valid coordinates within boundaries', () {
      const coords = LunarCoordinates(
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

    test('Throws assertion error if latitude exceeds bounds', () {
      expect(
        () => LunarCoordinates(latitude: -91.0, longitude: 0.0),
        throwsAssertionError,
      );
      expect(
        () => LunarCoordinates(latitude: 90.1, longitude: 0.0),
        throwsAssertionError,
      );
    });

    test(
      'Validates latitude and longitude accurately via static validators',
      () {
        expect(LunarCoordinates.validateLatitude(null), isNotNull);
        expect(LunarCoordinates.validateLatitude(-90.1), isNotNull);
        expect(LunarCoordinates.validateLatitude(90.1), isNotNull);
        expect(LunarCoordinates.validateLatitude(-89.9), isNull);
        expect(LunarCoordinates.validateLatitude(0.0), isNull);
        expect(LunarCoordinates.validateLatitude(90.0), isNull);

        expect(LunarCoordinates.validateLongitude(null), isNotNull);
        expect(LunarCoordinates.validateLongitude(-180.1), isNotNull);
        expect(LunarCoordinates.validateLongitude(360.1), isNotNull);
        expect(LunarCoordinates.validateLongitude(-179.0), isNull);
        expect(LunarCoordinates.validateLongitude(0.0), isNull);
        expect(LunarCoordinates.validateLongitude(359.0), isNull);
      },
    );

    test('Formats coordinates correctly with directional conventions', () {
      const eastPositive = LunarCoordinates(
        latitude: -89.9,
        longitude: 120.0,
        longitudeConvention: LongitudeConvention.eastPositive,
      );
      expect(eastPositive.formattedCoordinates, '89.9000° S, 120.0000° E');

      const westPositive = LunarCoordinates(
        latitude: 15.5,
        longitude: 45.0,
        longitudeConvention: LongitudeConvention.westPositive,
      );
      expect(westPositive.formattedCoordinates, '15.5000° N, 45.0000° W');

      const negativeEast = LunarCoordinates(
        latitude: -10.0,
        longitude: -50.0,
        longitudeConvention: LongitudeConvention.eastPositive,
      );
      expect(negativeEast.formattedCoordinates, '10.0000° S, 50.0000° W');
    });

    test('Serializes to and from JSON faithfully', () {
      const original = LunarCoordinates(
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
  });

  group('LunarSite Domain & Model Tests', () {
    test(
      'Constructs site without coordinates and maintains hasCoordinates flag',
      () {
        final site = LunarSite(
          id: 'test_p78_site',
          name: 'Test Polar Ridge',
          siteCode: 'SiteXX',
          classification: SiteClassification.candidateSite,
          coordinates: null,
          sourceId: 'NASA_PGDA_PRODUCT_78',
          sourceOrganization: 'NASA GSFC PGDA',
          sourceUrl: Uri.parse('https://pgda.gsfc.nasa.gov/products/78'),
          citation: 'Barker et al. (2021)',
          description: 'Test region description',
          relatedProductIds: const ['ldem_87s_5mpp'],
        );

        expect(site.hasCoordinates, isFalse);
        expect(site.coordinates, isNull);
        expect(site.relatedProductIds, ['ldem_87s_5mpp']);
      },
    );

    test('LunarSiteModel serialization preserves all fields', () {
      final model = LunarSiteModel(
        id: 'model_site_01',
        name: 'Model Site',
        siteCode: 'MS1',
        classification: SiteClassification.userDefined,
        coordinates: const LunarCoordinates(
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
        relatedProductIds: const ['test_product'],
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

    test('All 27 sites contain verified NASA PGDA Product 78 provenance', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      final codes = sites.map((s) => s.siteCode).toSet();

      // Check required codes from NASA Product 78
      final expectedCodes = {
        'Site01',
        'Site04',
        'Site06',
        'Site07',
        'Site11',
        'Site20',
        'Site20v2',
        'Site23',
        'Site42',
        'Haworth',
        'Shoemaker',
        'DM1',
        'DM2',
        'SL2',
        'SL3',
        'NPA',
        'NPB',
        'NPC',
        'NPD',
        'LM1',
        'LM2',
        'LM3',
        'LM4',
        'LM5',
        'LM6',
        'LM7',
        'LM8',
      };

      expect(codes, expectedCodes);

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
        // Crucial: coordinates must be null to prevent fabricated center points
        expect(site.coordinates, isNull);
      }
    });

    test('Only sites within 87°S to 90°S link to Product 81 ldem_87s_5mpp', () {
      final sites = BundledLunarSiteCatalog.officialSites;
      for (final site in sites) {
        if (site.siteCode == 'Site01' ||
            site.siteCode == 'Site04' ||
            site.siteCode == 'Site07' ||
            site.siteCode == 'Site11' ||
            site.siteCode == 'Haworth' ||
            site.siteCode == 'Shoemaker' ||
            site.siteCode == 'SL2' ||
            site.siteCode == 'SL3' ||
            site.siteCode.startsWith('LM')) {
          expect(
            site.relatedProductIds,
            contains('ldem_87s_5mpp'),
            reason: '${site.siteCode} should link ldem_87s_5mpp',
          );
        } else {
          expect(
            site.relatedProductIds,
            isEmpty,
            reason: '${site.siteCode} is outside 87°S mosaic coverage',
          );
        }
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
      final candidateSites = await repository.filterSites(
        classification: SiteClassification.candidateSite,
      );
      expect(candidateSites.length, 25); // 27 minus Haworth and Shoemaker

      final referenceRegions = await repository.filterSites(
        classification: SiteClassification.referenceRegion,
      );
      expect(referenceRegions.length, 2); // Haworth and Shoemaker
      expect(referenceRegions.map((r) => r.siteCode).toSet(), {
        'Haworth',
        'Shoemaker',
      });
    });

    test('addCustomSite adds new site, validates coordinates, and lists with official sites', () async {
      const customCoords = LunarCoordinates(
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
