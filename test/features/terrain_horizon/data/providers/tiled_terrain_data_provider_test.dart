import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/terrain_horizon/data/providers/tiled_terrain_data_provider.dart';
import 'package:luna_sight/features/terrain_horizon/data/services/dem_tile_loader.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/dem_metadata.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/geographic_extent.dart';

void main() {
  group('Real NASA LOLA South Pole Tile 78_78 Ingestion Tests', () {
    const fixturePath = 'test/fixtures/terrain';
    const fixtureFileName = 'lola_south_pole_tile_78_78.bin';

    test('Loads genuine decoded NASA LOLA BigTIFF tile from disk', () async {
      final file = File('$fixturePath/$fixtureFileName');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Authoritative test fixture must exist',
      );

      final loader = DemTileLoader(baseDirectoryPath: fixturePath);
      final tile = await loader.loadTile(
        tileX: 78,
        tileY: 78,
        metadata: DemMetadata.lolaProduct81,
        customFileName: fixtureFileName,
      );

      expect(tile, isNotNull);
      if (tile == null) return;
      expect(tile.width, 256);
      expect(tile.height, 256);
      expect(tile.elevations.length, 65536);

      // Verify spatial bounds of Tile (78, 78):
      // TiePoint: (-100000, 100000). Pixel scale: 5m.
      // Tile 78 X: -100000 + 78 * 256 * 5 = -100000 + 99840 = -160 m
      // Max X: -160 + 1280 = +1120 m.
      // Tile 78 Y: 100000 - 78 * 256 * 5 = 100000 - 99840 = +160 m
      // Min Y: 160 - 1280 = -1120 m.
      // Notice: The exact South Pole (0, 0) meters falls inside this tile!
      expect(tile.minX, closeTo(-160.0, 1e-4));
      expect(tile.maxX, closeTo(1120.0, 1e-4));
      expect(tile.minY, closeTo(-1120.0, 1e-4));
      expect(tile.maxY, closeTo(160.0, 1e-4));

      // Check elevation values (South Pole elevation is 1289.12m in this dataset)
      final southPoleSample = tile.sampleBilinear(0.0, 0.0);
      expect(southPoleSample, isNotNull);
      expect(southPoleSample!, greaterThan(600.0));
      expect(southPoleSample, lessThan(1400.0));
      expect(southPoleSample, closeTo(1289.12, 1.0));
    });

    test(
      'Pixel registration and tile boundary indexing consistency (Audit C)',
      () async {
        final loader = DemTileLoader(baseDirectoryPath: fixturePath);
        final tile = await loader.loadTile(
          tileX: 78,
          tileY: 78,
          metadata: DemMetadata.lolaProduct81,
          customFileName: fixtureFileName,
        );

        final provider = TiledTerrainDataProvider(
          metadata: DemMetadata.lolaProduct81,
        );
        provider.addTile(tile!);

        // 1. South Pole (0, 0) meters under PixelIsArea semantics:
        // In Tile (78, 78): minX = -160, maxY = 160, pixelScale = 5
        // Continuous pixel coordinates for cell center:
        // col = (0 - (-160)) / 5 - 0.5 = 32.0 - 0.5 = 31.5
        // row = (160 - 0) / 5 - 0.5 = 32.0 - 0.5 = 31.5
        // Bilinear interpolation between the 4 surrounding pixel centers:
        // (31, 31) [1289.858], (32, 31) [1288.849], (31, 32) [1290.082], (32, 32) [1289.124]
        // Mean = 1289.478 m.
        final sampleCenter = provider.getElevation(
          Angle.fromDegrees(-90.0),
          Angle.fromDegrees(0.0),
        );
        expect(sampleCenter.isValid, isTrue);
        expect(sampleCenter.elevationMeters, closeTo(1289.478, 0.01));

        // 2. Tile edge bounds:
        // Right edge of tile 78 is at x = 1120 m
        // Exactly at maxX, sample is within tile extent
        final sampleEdge = tile.sampleBilinear(1120.0, 0.0);
        expect(sampleEdge, isNotNull);

        // Just beyond maxX (e.g. 1120.1 m), tile 78 returns outsideCoverage
        final (sampleBeyond, statusBeyond) = tile.sampleDetailed(1120.1, 0.0);
        expect(sampleBeyond, isNull);
        expect(statusBeyond, ElevationSampleStatus.outsideCoverage);
      },
    );

    test('TiledTerrainDataProvider samples correctly at South Pole using real tile', () async {
      final loader = DemTileLoader(baseDirectoryPath: fixturePath);
      final tile = await loader.loadTile(
        tileX: 78,
        tileY: 78,
        metadata: DemMetadata.lolaProduct81,
        customFileName: fixtureFileName,
      );

      final provider = TiledTerrainDataProvider(
        metadata: DemMetadata.lolaProduct81,
      );
      provider.addTile(tile!);

      // Exact South Pole: Lat -90°, Lon 0°
      final samplePole = provider.getElevation(
        Angle.fromDegrees(-90.0),
        Angle.fromDegrees(0.0),
      );

      expect(samplePole.isValid, isTrue);
      expect(samplePole.elevationMeters, closeTo(1289.12, 1.0));
      expect(samplePole.projectedX, closeTo(0.0, 1e-4));
      expect(samplePole.projectedY, closeTo(0.0, 1e-4));

      // Sample outside loaded tile (e.g. 88°S, where projected distance is ~60 km)
      // Tile (78, 78) only covers roughly [-160, 1120]m x [-1120, 160]m (~1.28 km)
      final sampleOutside = provider.getElevation(
        Angle.fromDegrees(-88.0),
        Angle.fromDegrees(0.0),
      );

      expect(sampleOutside.isValid, isFalse);
      expect(sampleOutside.status, ElevationSampleStatus.outsideCoverage);
    });

    test('DemTileLoader rejects corrupted or truncated tile files', () async {
      final corruptFile = File('$fixturePath/corrupt_test_tile.bin');
      try {
        await corruptFile.writeAsBytes([1, 2, 3, 4], flush: true);

        final loader = DemTileLoader(baseDirectoryPath: fixturePath);
        expect(
          loader.loadTile(
            tileX: 0,
            tileY: 0,
            metadata: DemMetadata.lolaProduct81,
            customFileName: 'corrupt_test_tile.bin',
          ),
          throwsA(isA<FormatException>()),
        );
      } finally {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        try {
          if (await corruptFile.exists()) {
            await corruptFile.delete();
          }
        } catch (_) {}
      }
    });
  });

  group(
    'TiledTerrainDataProvider Boundary & Multi-Tile Selection Tests (Audit C)',
    () {
      late DemMetadata testMetadata;
      late DemTile tileA; // Tile (0, 0): X from 0 to 2560m, Y from 0 to -2560m (origin tiepoint (0, 0), pixelScale 10m)
      late DemTile
      tileB; // Tile (1, 0): X from 2560 to 5120m, Y from 0 to -2560m

      setUp(() {
        testMetadata = DemMetadata(
          productId: 'multi_tile_test',
          publisher: 'Test Laboratory',
          projectionType: ProjectionType.southPolarStereographic,
          referenceFrame: ReferenceFrameId.moonMeDe421,
          referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
          pixelRegistration: PixelRegistration.pixelIsArea,
          width: 512,
          height: 256,
          pixelScaleX: 10.0,
          pixelScaleY: 10.0,
          tiePointX: 0.0,
          tiePointY: 0.0,
          elevationUnit: ElevationUnit.meters,
          projectedExtent: const ProjectedExtent(
            minX: 0.0,
            maxX: 5120.0,
            minY: -2560.0,
            maxY: 0.0,
          ),
        );

        // Tile A (tileX=0, tileY=0): constant elevation 100.0 m
        final elevationsA = Float32List(256 * 256)
          ..fillRange(0, 256 * 256, 100.0);
        tileA = DemTile(
          tileX: 0,
          tileY: 0,
          width: 256,
          height: 256,
          elevations: elevationsA,
          minX: 0.0,
          maxX: 2560.0,
          minY: -2560.0,
          maxY: 0.0,
          pixelScale: 10.0,
        );

        // Tile B (tileX=1, tileY=0): constant elevation 200.0 m
        final elevationsB = Float32List(256 * 256)
          ..fillRange(0, 256 * 256, 200.0);
        tileB = DemTile(
          tileX: 1,
          tileY: 0,
          width: 256,
          height: 256,
          elevations: elevationsB,
          minX: 2560.0,
          maxX: 5120.0,
          minY: -2560.0,
          maxY: 0.0,
          pixelScale: 10.0,
        );
      });

      test('Provider selects correct tile inside Tile A and inside Tile B', () {
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);
        provider.addTile(tileB);

        // Point in A: X = 1000m, Y = -1000m
        final (latA, lonA) = provider.projection.inverse(x: 1000.0, y: -1000.0);
        final sampleA = provider.getElevation(latA, lonA);
        expect(sampleA.isValid, isTrue);
        expect(sampleA.elevationMeters, closeTo(100.0, 1e-4));

        // Point in B: X = 3500m, Y = -1000m
        final (latB, lonB) = provider.projection.inverse(x: 3500.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isTrue);
        expect(sampleB.elevationMeters, closeTo(200.0, 1e-4));
      });

      test('Shared boundary behavior between Tile A and Tile B (boundary at X = 2560m)', () {
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);
        provider.addTile(tileB);

        // 1. Immediately on A side: X = 2559.0m (tileX = 0)
        final (latA, lonA) = provider.projection.inverse(x: 2559.0, y: -1000.0);
        final sampleA = provider.getElevation(latA, lonA);
        expect(sampleA.isValid, isTrue);
        expect(sampleA.elevationMeters, closeTo(100.0, 1e-4));

        // 2. Immediately on B side: X = 2561.0m (tileX = 1)
        final (latB, lonB) = provider.projection.inverse(x: 2561.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isTrue);
        expect(sampleB.elevationMeters, closeTo(200.0, 1e-4));

        // 3. Exactly on shared boundary:
        // Tile A covers [0, 2560] and Tile B covers [2560, 5120].
        // When queried directly on DemTile boundaries:
        // Tile A at maxX (2560.0) returns 100.0 m.
        // Tile B at minX (2560.0) returns 200.0 m.
        expect(tileA.sampleBilinear(2560.0, -1000.0), closeTo(100.0, 1e-4));
        expect(tileB.sampleBilinear(2560.0, -1000.0), closeTo(200.0, 1e-4));

        // Provider selection for coordinates approaching boundary from left (Tile A) vs right (Tile B):
        final (latLeft, lonLeft) = provider.projection.inverse(
          x: 2559.9,
          y: -1000.0,
        );
        final (latRight, lonRight) = provider.projection.inverse(
          x: 2560.1,
          y: -1000.0,
        );
        expect(
          provider.getElevation(latLeft, lonLeft).elevationMeters,
          closeTo(100.0, 1e-4),
        );
        expect(
          provider.getElevation(latRight, lonRight).elevationMeters,
          closeTo(200.0, 1e-4),
        );
      });

      test('Missing neighboring tile behavior at boundary', () {
        // Load only Tile A, omitting Tile B
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);

        // Query on B side (X = 2561.0m)
        final (latB, lonB) = provider.projection.inverse(x: 2561.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isFalse);
        expect(sampleB.status, ElevationSampleStatus.outsideCoverage);
      });
    },
  );

  group(
    'TiledTerrainDataProvider Boundary & Multi-Tile Selection Tests (Audit C)',
    () {
      late DemMetadata testMetadata;
      late DemTile tileA; // Tile (0, 0): X from 0 to 2560m, Y from 0 to -2560m (origin tiepoint (0, 0), pixelScale 10m)
      late DemTile
      tileB; // Tile (1, 0): X from 2560 to 5120m, Y from 0 to -2560m

      setUp(() {
        testMetadata = DemMetadata(
          productId: 'multi_tile_test',
          publisher: 'Test Laboratory',
          projectionType: ProjectionType.southPolarStereographic,
          referenceFrame: ReferenceFrameId.moonMeDe421,
          referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
          pixelRegistration: PixelRegistration.pixelIsArea,
          width: 512,
          height: 256,
          pixelScaleX: 10.0,
          pixelScaleY: 10.0,
          tiePointX: 0.0,
          tiePointY: 0.0,
          elevationUnit: ElevationUnit.meters,
          projectedExtent: const ProjectedExtent(
            minX: 0.0,
            maxX: 5120.0,
            minY: -2560.0,
            maxY: 0.0,
          ),
        );

        // Tile A (tileX=0, tileY=0): constant elevation 100.0 m
        final elevationsA = Float32List(256 * 256)
          ..fillRange(0, 256 * 256, 100.0);
        tileA = DemTile(
          tileX: 0,
          tileY: 0,
          width: 256,
          height: 256,
          elevations: elevationsA,
          minX: 0.0,
          maxX: 2560.0,
          minY: -2560.0,
          maxY: 0.0,
          pixelScale: 10.0,
        );

        // Tile B (tileX=1, tileY=0): constant elevation 200.0 m
        final elevationsB = Float32List(256 * 256)
          ..fillRange(0, 256 * 256, 200.0);
        tileB = DemTile(
          tileX: 1,
          tileY: 0,
          width: 256,
          height: 256,
          elevations: elevationsB,
          minX: 2560.0,
          maxX: 5120.0,
          minY: -2560.0,
          maxY: 0.0,
          pixelScale: 10.0,
        );
      });

      test('Provider selects correct tile inside Tile A and inside Tile B', () {
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);
        provider.addTile(tileB);

        // Point in A: X = 1000m, Y = -1000m
        final (latA, lonA) = provider.projection.inverse(x: 1000.0, y: -1000.0);
        final sampleA = provider.getElevation(latA, lonA);
        expect(sampleA.isValid, isTrue);
        expect(sampleA.elevationMeters, closeTo(100.0, 1e-4));

        // Point in B: X = 3500m, Y = -1000m
        final (latB, lonB) = provider.projection.inverse(x: 3500.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isTrue);
        expect(sampleB.elevationMeters, closeTo(200.0, 1e-4));
      });

      test('Shared boundary behavior between Tile A and Tile B (boundary at X = 2560m)', () {
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);
        provider.addTile(tileB);

        // 1. Immediately on A side: X = 2559.0m (tileX = 0)
        final (latA, lonA) = provider.projection.inverse(x: 2559.0, y: -1000.0);
        final sampleA = provider.getElevation(latA, lonA);
        expect(sampleA.isValid, isTrue);
        expect(sampleA.elevationMeters, closeTo(100.0, 1e-4));

        // 2. Immediately on B side: X = 2561.0m (tileX = 1)
        final (latB, lonB) = provider.projection.inverse(x: 2561.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isTrue);
        expect(sampleB.elevationMeters, closeTo(200.0, 1e-4));

        // 3. Exactly on shared boundary:
        // Tile A covers [0, 2560] and Tile B covers [2560, 5120].
        // When queried directly on DemTile boundaries:
        // Tile A at maxX (2560.0) returns 100.0 m.
        // Tile B at minX (2560.0) returns 200.0 m.
        expect(tileA.sampleBilinear(2560.0, -1000.0), closeTo(100.0, 1e-4));
        expect(tileB.sampleBilinear(2560.0, -1000.0), closeTo(200.0, 1e-4));

        // Provider selection for coordinates approaching boundary from left (Tile A) vs right (Tile B):
        final (latLeft, lonLeft) = provider.projection.inverse(
          x: 2559.9,
          y: -1000.0,
        );
        final (latRight, lonRight) = provider.projection.inverse(
          x: 2560.1,
          y: -1000.0,
        );
        expect(
          provider.getElevation(latLeft, lonLeft).elevationMeters,
          closeTo(100.0, 1e-4),
        );
        expect(
          provider.getElevation(latRight, lonRight).elevationMeters,
          closeTo(200.0, 1e-4),
        );
      });

      test('Missing neighboring tile behavior at boundary', () {
        // Load only Tile A, omitting Tile B
        final provider = TiledTerrainDataProvider(metadata: testMetadata);
        provider.addTile(tileA);

        // Query on B side (X = 2561.0m)
        final (latB, lonB) = provider.projection.inverse(x: 2561.0, y: -1000.0);
        final sampleB = provider.getElevation(latB, lonB);
        expect(sampleB.isValid, isFalse);
        expect(sampleB.status, ElevationSampleStatus.outsideCoverage);
      });
    },
  );
}
