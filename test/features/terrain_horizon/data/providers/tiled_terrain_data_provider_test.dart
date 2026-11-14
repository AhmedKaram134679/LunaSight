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

  group('TiledTerrainDataProvider Boundary & Multi-Tile Selection Tests (Audit C)', () {
    late DemMetadata testMetadata;
    late DemTile tileA; // Tile (0, 0): X from -2560 to 0m, Y from 0 to -2560m
    late DemTile tileB; // Tile (1, 0): X from 0 to 2560m, Y from 0 to -2560m

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
        tiePointX: -2560.0,
        tiePointY: 0.0,
        elevationUnit: ElevationUnit.meters,
        projectedExtent: const ProjectedExtent(
          minX: -2560.0,
          maxX: 2560.0,
          minY: -2560.0,
          maxY: 0.0,
        ),
      );

      // Tile A (tileX=0, tileY=0): 2D spatial gradient:
      // Elevation = 100.0 + col * 0.1 + row * 0.01 m
      final elevationsA = Float32List(256 * 256);
      for (var r = 0; r < 256; r++) {
        for (var c = 0; c < 256; c++) {
          elevationsA[r * 256 + c] = 100.0 + c * 0.1 + r * 0.01;
        }
      }
      tileA = DemTile(
        tileX: 0,
        tileY: 0,
        width: 256,
        height: 256,
        elevations: elevationsA,
        minX: -2560.0,
        maxX: 0.0,
        minY: -2560.0,
        maxY: 0.0,
        pixelScale: 10.0,
      );

      // Tile B (tileX=1, tileY=0): 2D spatial gradient:
      // Elevation = 500.0 + col * 0.2 + row * 0.03 m
      final elevationsB = Float32List(256 * 256);
      for (var r = 0; r < 256; r++) {
        for (var c = 0; c < 256; c++) {
          elevationsB[r * 256 + c] = 500.0 + c * 0.2 + r * 0.03;
        }
      }
      tileB = DemTile(
        tileX: 1,
        tileY: 0,
        width: 256,
        height: 256,
        elevations: elevationsB,
        minX: 0.0,
        maxX: 2560.0,
        minY: -2560.0,
        maxY: 0.0,
        pixelScale: 10.0,
      );
    });

    test('Provider selects correct tile inside Tile A and inside Tile B via getElevation', () {
      final provider = TiledTerrainDataProvider(metadata: testMetadata);
      provider.addTile(tileA);
      provider.addTile(tileB);

      // Point strictly in A: X = -1000m, Y = -1000m.
      // In Tile A (minX=-2560, maxY=0):
      // col = (-1000 - (-2560)) / 10 - 0.5 = 156.0 - 0.5 = 155.5
      // row = (0 - (-1000)) / 10 - 0.5 = 100.0 - 0.5 = 99.5
      // Expected = 100.0 + 155.5 * 0.1 + 99.5 * 0.01 = 100.0 + 15.55 + 0.995 = 116.545 m
      final (latA, lonA) = provider.projection.inverse(x: -1000.0, y: -1000.0);
      final sampleA = provider.getElevation(latA, lonA);
      expect(sampleA.isValid, isTrue);
      expect(sampleA.status, ElevationSampleStatus.validBilinear);
      expect(sampleA.elevationMeters, closeTo(116.545, 1e-3));

      // Point strictly in B: X = 1000m, Y = -1000m.
      // In Tile B (minX=0, maxY=0):
      // col = (1000 - 0) / 10 - 0.5 = 99.5
      // row = (0 - (-1000)) / 10 - 0.5 = 99.5
      // Expected = 500.0 + 99.5 * 0.2 + 99.5 * 0.03 = 500.0 + 19.9 + 2.985 = 522.885 m
      final (latB, lonB) = provider.projection.inverse(x: 1000.0, y: -1000.0);
      final sampleB = provider.getElevation(latB, lonB);
      expect(sampleB.isValid, isTrue);
      expect(sampleB.status, ElevationSampleStatus.validBilinear);
      expect(sampleB.elevationMeters, closeTo(522.885, 1e-3));
    });

    test('Shared boundary behavior at exact South Pole projected origin (X = 0, Y = 0)', () {
      final provider = TiledTerrainDataProvider(metadata: testMetadata);
      provider.addTile(tileA);
      provider.addTile(tileB);

      // The exact South Pole (-90° lat, any lon) forward-projects mathematically to (0.0, 0.0) meters.
      // Under half-open tile indexing [X_0, X_1):
      // Tile A: [-2560, 0)
      // Tile B: [0, 2560)
      // At X = 0.0: col = (0.0 - (-2560)) / 10 = 256.0. tileX = floor(256.0 / 256) = 1 (Tile B).
      // In Tile B (minX=0, maxX=2560, minY=-2560, maxY=0):
      // col = (0.0 - 0) / 10 - 0.5 = -0.5
      // row = (0 - 0.0) / 10 - 0.5 = -0.5
      // Outer border (col < 0, row < 0) falls back to nearest neighbor (c=0, r=0).
      // Expected Tile B sample at (c=0, r=0): 500.0 + 0 * 0.2 + 0 * 0.03 = 500.0 m.
      final southPoleLat = Angle.fromDegrees(-90.0);
      final southPoleLon = Angle.fromDegrees(0.0);

      final samplePole = provider.getElevation(southPoleLat, southPoleLon);
      expect(samplePole.isValid, isTrue);
      expect(samplePole.status, ElevationSampleStatus.validNearestNeighbor);
      // Strictly proves Tile B ownership at exact boundary:
      expect(samplePole.elevationMeters, closeTo(500.0, 1e-3));
      // If Tile A were erroneously selected, sample would be near 100 + 255 * 0.1 = ~125.5 m!
      expect(samplePole.elevationMeters, isNot(closeTo(125.5, 10.0)));
    });

    test('Shared boundary behavior immediately before, at, and immediately after boundary via getElevation', () {
      final provider = TiledTerrainDataProvider(metadata: testMetadata);
      provider.addTile(tileA);
      provider.addTile(tileB);

      // 1. Immediately on A side: X = -10.0m, Y = -1000m
      // In Tile A: col = (-10.0 - (-2560)) / 10 - 0.5 = 255.0 - 0.5 = 254.5.
      // row = (0 - (-1000)) / 10 - 0.5 = 99.5.
      // Valid bilinear: 100.0 + 254.5 * 0.1 + 99.5 * 0.01 = 126.445 m.
      final (latBefore, lonBefore) = provider.projection.inverse(
        x: -10.0,
        y: -1000.0,
      );
      final sampleBefore = provider.getElevation(latBefore, lonBefore);
      expect(sampleBefore.isValid, isTrue);
      expect(sampleBefore.elevationMeters, closeTo(126.445, 1e-2));

      // 2. Exact South Pole meridian boundary at Y = 0:
      // Exact South Pole (0, 0) is owned by Tile B:
      final sampleBoundary = provider.getElevation(
        Angle.fromDegrees(-90.0),
        Angle.fromDegrees(0.0),
      );
      expect(sampleBoundary.elevationMeters, closeTo(500.0, 1e-3));

      // 3. Immediately on B side: X = +10.0m, Y = -1000m
      // In Tile B: col = (10.0 - 0) / 10 - 0.5 = 0.5.
      // row = (0 - (-1000)) / 10 - 0.5 = 99.5.
      // Valid bilinear: 500.0 + 0.5 * 0.2 + 99.5 * 0.03 = 500.0 + 0.1 + 2.985 = 503.085 m.
      final (latAfter, lonAfter) = provider.projection.inverse(
        x: 10.0,
        y: -1000.0,
      );
      final sampleAfter = provider.getElevation(latAfter, lonAfter);
      expect(sampleAfter.isValid, isTrue);
      expect(sampleAfter.elevationMeters, closeTo(503.085, 1e-2));
    });

    test('Tile loading order invariance: rigorous comparison of providerAB vs providerBA across boundary', () {
      final providerAB = TiledTerrainDataProvider(metadata: testMetadata);
      providerAB.addTile(tileA);
      providerAB.addTile(tileB);

      final providerBA = TiledTerrainDataProvider(metadata: testMetadata);
      providerBA.addTile(tileB);
      providerBA.addTile(tileA);

      final testPoints = <(Angle, Angle)>[
        // Exact shared boundary at South Pole:
        (Angle.fromDegrees(-90.0), Angle.fromDegrees(0.0)),
        (Angle.fromDegrees(-90.0), Angle.fromDegrees(45.0)),
        // Inside Tile A:
        providerAB.projection.inverse(x: -1000.0, y: -1000.0),
        providerAB.projection.inverse(x: -200.0, y: -500.0),
        providerAB.projection.inverse(x: -10.0, y: -1000.0),
        // Inside Tile B:
        providerAB.projection.inverse(x: 10.0, y: -1000.0),
        providerAB.projection.inverse(x: 500.0, y: -500.0),
        providerAB.projection.inverse(x: 1000.0, y: -1000.0),
      ];

      for (final (lat, lon) in testPoints) {
        final sampleAB = providerAB.getElevation(lat, lon);
        final sampleBA = providerBA.getElevation(lat, lon);

        expect(
          sampleAB.status,
          sampleBA.status,
          reason: 'Sample status must be identical for lat $lat, lon $lon',
        );
        expect(sampleAB.isValid, sampleBA.isValid);
        expect(
          sampleAB.elevationMeters,
          sampleBA.elevationMeters,
          reason:
              'Elevation meters must match identically across loading orders for lat $lat, lon $lon',
        );
      }
    });

    test(
      'Missing neighboring tile behavior at shared boundary via getElevation',
      () {
        // Load only Tile A (Tile B missing)
        final providerOnlyA = TiledTerrainDataProvider(metadata: testMetadata);
        providerOnlyA.addTile(tileA);

        // Query exact South Pole (0, 0), which is routed to Tile B:
        final samplePoleWithoutB = providerOnlyA.getElevation(
          Angle.fromDegrees(-90.0),
          Angle.fromDegrees(0.0),
        );
        // Because Tile B is missing, query at boundary must return outsideCoverage:
        expect(samplePoleWithoutB.isValid, isFalse);
        expect(
          samplePoleWithoutB.status,
          ElevationSampleStatus.outsideCoverage,
        );

        // Query on A side must still succeed:
        final (latA, lonA) = providerOnlyA.projection.inverse(
          x: -1000.0,
          y: -1000.0,
        );
        final sampleA = providerOnlyA.getElevation(latA, lonA);
        expect(sampleA.isValid, isTrue);
        expect(sampleA.elevationMeters, closeTo(116.545, 1e-3));

        // Load only Tile B (Tile A missing)
        final providerOnlyB = TiledTerrainDataProvider(metadata: testMetadata);
        providerOnlyB.addTile(tileB);

        // Query exact South Pole (0, 0), which is routed to Tile B:
        final samplePoleWithB = providerOnlyB.getElevation(
          Angle.fromDegrees(-90.0),
          Angle.fromDegrees(0.0),
        );
        // Since Tile B is loaded, it owns (0,0) and succeeds:
        expect(samplePoleWithB.isValid, isTrue);
        expect(samplePoleWithB.elevationMeters, closeTo(500.0, 1e-3));

        // Query on A side must return outsideCoverage:
        final sampleAWithoutA = providerOnlyB.getElevation(latA, lonA);
        expect(sampleAWithoutA.isValid, isFalse);
        expect(sampleAWithoutA.status, ElevationSampleStatus.outsideCoverage);
      },
    );

    test('NoData at the selected tile nearest sample returns noData status via getElevation', () {
      // Modify sample (0, 0) of Tile B to be NoData (-9999.0)
      final elevationsBWithNoData = Float32List.fromList(tileB.elevations);
      elevationsBWithNoData[0] = -9999.0;
      final tileBWithNoData = DemTile(
        tileX: 1,
        tileY: 0,
        width: 256,
        height: 256,
        elevations: elevationsBWithNoData,
        minX: 0.0,
        maxX: 2560.0,
        minY: -2560.0,
        maxY: 0.0,
        pixelScale: 10.0,
        noDataValue: -9999.0,
      );

      final provider = TiledTerrainDataProvider(metadata: testMetadata);
      provider.addTile(tileA);
      provider.addTile(tileBWithNoData);

      // Query at South Pole (0, 0) falls back to nearest neighbor (0, 0) in Tile B,
      // which has NoData:
      final sample = provider.getElevation(
        Angle.fromDegrees(-90.0),
        Angle.fromDegrees(0.0),
      );
      expect(sample.isValid, isFalse);
      expect(sample.status, ElevationSampleStatus.noData);
    });
  });
}
