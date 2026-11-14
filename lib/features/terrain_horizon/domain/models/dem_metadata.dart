import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/geographic_extent.dart';

/// Coordinate reference and projection definition for digital elevation models.
enum ProjectionType {
  /// Unprojected equirectangular / geographic grid (lat/lon).
  geographic,

  /// South Polar Stereographic projection (centered at South Pole -90°).
  southPolarStereographic,

  /// North Polar Stereographic projection (centered at North Pole +90°).
  northPolarStereographic,
}

/// Pixel registration convention.
enum PixelRegistration {
  /// Value represents the center point of the pixel cell.
  pixelIsPoint,

  /// Value represents the entire area of the pixel cell.
  pixelIsArea,
}

/// Elevation units of the raster data.
enum ElevationUnit { meters, kilometers }

/// Complete scientific metadata characterizing a lunar digital elevation raster.
class DemMetadata {
  /// Unique source product identifier (e.g. `ldem_87s_5mpp`).
  final String productId;

  /// Authoritative publisher and provenance.
  final String publisher;

  /// Horizontal projection type.
  final ProjectionType projectionType;

  /// Reference frame realization (e.g. `MOON_ME_DE421`).
  final ReferenceFrameId referenceFrame;

  /// Geometric vertical reference datum (e.g. `ReferenceSurfaceId.lunarSphere1737400`).
  final ReferenceSurfaceId referenceSurface;

  /// Pixel registration (pixel-is-point vs pixel-is-area).
  final PixelRegistration pixelRegistration;

  /// Raster width in columns (pixels).
  final int width;

  /// Raster height in rows (pixels).
  final int height;

  /// Horizontal grid spacing / resolution along X/Longitude.
  final double pixelScaleX;

  /// Horizontal grid spacing / resolution along Y/Latitude.
  final double pixelScaleY;

  /// Coordinate at upper-left corner (pixel 0,0).
  final double tiePointX;
  final double tiePointY;

  /// Elevation unit.
  final ElevationUnit elevationUnit;

  /// Value representing invalid or missing data.
  final double? noDataValue;

  /// Projected extent in meters (for polar stereographic products).
  final ProjectedExtent? projectedExtent;

  /// Geographic extent in latitude/longitude (if known/applicable).
  final GeographicExtent? geographicExtent;

  const DemMetadata({
    required this.productId,
    required this.publisher,
    required this.projectionType,
    required this.referenceFrame,
    required this.referenceSurface,
    required this.pixelRegistration,
    required this.width,
    required this.height,
    required this.pixelScaleX,
    required this.pixelScaleY,
    required this.tiePointX,
    required this.tiePointY,
    required this.elevationUnit,
    this.noDataValue,
    this.projectedExtent,
    this.geographicExtent,
  });

  /// Canonical metadata definition for NASA GSFC LOLA South Pole 5 mpp mosaic (Product 81).
  static final DemMetadata lolaProduct81 = DemMetadata(
    productId: 'ldem_87s_5mpp',
    publisher: 'NASA GSFC Planetary Geodynamics Laboratory (PGDA Product 81)',
    projectionType: ProjectionType.southPolarStereographic,
    referenceFrame: ReferenceFrameId.moonMeDe421,
    referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
    pixelRegistration: PixelRegistration.pixelIsArea,
    width: 40000,
    height: 40000,
    pixelScaleX: 5.0,
    pixelScaleY: 5.0,
    tiePointX: -100000.0,
    tiePointY: 100000.0,
    elevationUnit: ElevationUnit.meters,
    noDataValue: -3.4028234663852886e+38, // Standard GDAL/TIFF Float32 NoData
    projectedExtent: const ProjectedExtent(
      minX: -100000.0,
      maxX: 100000.0,
      minY: -100000.0,
      maxY: 100000.0,
    ),
  );
}
