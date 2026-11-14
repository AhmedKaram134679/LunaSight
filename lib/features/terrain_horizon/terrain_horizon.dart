// Terrain Horizon Engine library.
//
// Implements Phase 05 of the LunaSight project:
// - Rigorous 3D terrain horizon calculation with lunar curvature ($R = 1,737,400\text{ m}$).
// - Real lunar elevation model ingestion (NASA LOLA South Pole 5 mpp mosaic, Product 81).
// - Polar stereographic projection forward/inverse transformations.
// - Bilinear and nearest-neighbor terrain elevation sampling.
// - Observer topocentric horizon frame evaluation.

export 'domain/models/dem_metadata.dart';
export 'domain/models/elevation_sample.dart';
export 'domain/models/geographic_extent.dart';
export 'domain/models/horizon_profile.dart';
export 'domain/projections/south_polar_stereographic.dart';
export 'domain/services/terrain_horizon_engine.dart';
export 'data/providers/tiled_terrain_data_provider.dart';
export 'data/services/dem_tile_loader.dart';
