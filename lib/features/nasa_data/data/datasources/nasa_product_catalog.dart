import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';

/// Authoritative catalog of official NASA lunar products supported by LunaSight.
///
/// Every product registered here must be grounded in officially published NASA metadata.
class NasaProductCatalog {
  NasaProductCatalog._();

  /// Primary lunar south polar digital elevation model from NASA GSFC PGDA Product #81.
  ///
  /// Reference: https://pgda.gsfc.nasa.gov/products/81
  /// Citation: Barker et al., 2021, Planetary & Space Science, 203, 105119.
  static final NasaProductDefinition ldem87s5mpp = NasaProductDefinition(
    identifier: 'ldem_87s_5mpp',
    title: 'South Pole LOLA DEM Mosaic',
    sourceOrganization: 'NASA Planetary Geology, Geophysics and Geochemistry Laboratory, Goddard Space Flight Center (GSFC)',
    author: 'Michael Kenneth Barker',
    officialProductPageUrl: Uri.parse('https://pgda.gsfc.nasa.gov/products/81'),
    officialAssetUrl: Uri.parse(
      'https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
    ),
    format: 'GeoTIFF',
    publishedSizeBytes: 3465285714, // Exact HTTP Content-Length (3.46 GB / ~3.3 GB uncompressed)
    publishedSizeDescription: '~3.3 GB',
    spatialResolution: 5.0,
    spatialResolutionUnit: 'm/pixel',
    horizontalCoordinateSystem: 'South Polar Stereographic, meters (X/Y coordinates follow Generic Mapping Tools convention)',
    horizontalCoordinateUnit: 'meters',
    referenceFrame: 'MOON_ME',
    ephemerisAssociation: 'DE421',
    pixelRegistration: PixelRegistration.pixelRegistered,
    elevationMeasurement:
        'Surface height Z with interpolation filling empty pixels',
    elevationUnit: 'meters',
    coverageDescription: 'Lunar South Pole mosaic covering 87°S to 90°S constructed from 97 individual 20x20 km fields with 2 km overlaps',
    processingNotes: 'Track adjustment, cleaning routines, rigid 3-D translations, and cosine taper weight blending in 2 km overlap regions. Interpolation is used to fill areas without measurements. Typical RMS residual of 30-55 cm with individual fields.',
    citation: 'Barker et al., 2021, "Improved LOLA Elevation Maps for South Pole Landing Sites: Error Estimates and Their Impact on Illumination Conditions", Planetary & Space Science, Volume 203, 105119, https://doi.org/10.1016/j.pss.2020.105119',
    publicationDate: DateTime.utc(2021, 10, 14, 12, 54, 49),
  );

  /// All officially supported product definitions.
  static final List<NasaProductDefinition> allProducts = List.unmodifiable([
    ldem87s5mpp,
  ]);

  /// Lookup a product by its unique identifier.
  static NasaProductDefinition? findById(String id) {
    try {
      return allProducts.firstWhere((p) => p.identifier == id);
    } catch (_) {
      return null;
    }
  }

  /// Validates whether a given URL matches an approved official NASA product URL in the catalog.
  static bool isApprovedNasaUrl(Uri uri) {
    return allProducts.any(
      (p) =>
          p.officialAssetUrl.scheme == uri.scheme &&
          p.officialAssetUrl.host == uri.host &&
          p.officialAssetUrl.path == uri.path,
    );
  }
}
