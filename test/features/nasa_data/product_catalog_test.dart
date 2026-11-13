import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/nasa_data/data/datasources/nasa_product_catalog.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';

void main() {
  group('NASA Product Catalog & Metadata Provenance Tests', () {
    test('ldem_87s_5mpp metadata matches official NASA PGDA publication exactly', () {
      final product = NasaProductCatalog.ldem87s5mpp;

      expect(product.identifier, 'ldem_87s_5mpp');
      expect(product.title, 'South Pole LOLA DEM Mosaic');
      expect(product.format, 'GeoTIFF');
      expect(product.spatialResolution, 5.0);
      expect(product.spatialResolutionUnit, 'm/pixel');
      expect(product.horizontalCoordinateUnit, 'meters');
      expect(product.referenceFrame, 'MOON_ME');
      expect(product.ephemerisAssociation, 'DE421');
      expect(product.pixelRegistration, PixelRegistration.pixelRegistered);
      expect(product.elevationUnit, 'meters');

      // Requirement 5: Provenance separation
      // Published text states "3.3GB GeoTIFF of surface height Z (meters)"
      expect(product.publishedSizeDescription, '3.3GB');
      // Exact byte count is not published in documentation text, so it is null
      expect(product.publishedSizeBytes, isNull);
      // HTTP Last-Modified is not treated as an official publication date
      expect(product.publicationDate, isNull);

      expect(
        product.officialProductPageUrl.toString(),
        'https://pgda.gsfc.nasa.gov/products/81',
      );
      expect(
        product.officialAssetUrl.toString(),
        'https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
      );
      expect(product.citation, contains('Barker et al., 2021'));
      expect(product.processingNotes, contains('Interpolation is used'));
      expect(product.processingNotes, contains('cosine taper weight'));
    });

    test('Catalog lookup returns registered product and null for unknown', () {
      expect(NasaProductCatalog.findById('ldem_87s_5mpp'), isNotNull);
      expect(NasaProductCatalog.findById('non_existent_product'), isNull);
    });

    test('URL validation approves only registered official NASA product asset URLs', () {
      final validUri = Uri.parse(
        'https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
      );
      final untrustedUri = Uri.parse(
        'https://malicious-mirror.org/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
      );
      final arbitraryNasaUri = Uri.parse(
        'https://pgda.gsfc.nasa.gov/data/other_unregistered_file.tif',
      );

      expect(NasaProductCatalog.isApprovedNasaUrl(validUri), isTrue);
      expect(NasaProductCatalog.isApprovedNasaUrl(untrustedUri), isFalse);
      expect(NasaProductCatalog.isApprovedNasaUrl(arbitraryNasaUri), isFalse);
    });

    test('NasaProductDefinition handles unknown or missing fields explicitly without defaults', () {
      final custom = NasaProductDefinition(
        identifier: 'test_product',
        title: 'Test',
        sourceOrganization: 'NASA',
        officialProductPageUrl: Uri.parse('https://nasa.gov'),
        officialAssetUrl: Uri.parse('https://nasa.gov/file.tif'),
        format: 'GeoTIFF',
        spatialResolution: 10.0,
        spatialResolutionUnit: 'm/pix',
        horizontalCoordinateSystem: 'Stereographic',
        horizontalCoordinateUnit: 'meters',
        referenceFrame: 'MOON_ME',
        ephemerisAssociation: 'DE421',
        pixelRegistration: PixelRegistration.unknown,
        elevationMeasurement: 'height',
        elevationUnit: 'meters',
        coverageDescription: 'Polar',
        processingNotes: 'None',
        citation: 'N/A',
        publishedSizeBytes: null,
        publishedSizeDescription: null,
        publicationDate: null,
      );

      expect(custom.publishedSizeBytes, isNull);
      expect(custom.publishedSizeDescription, isNull);
      expect(custom.publicationDate, isNull);
      expect(custom.pixelRegistration, PixelRegistration.unknown);
    });
  });
}
