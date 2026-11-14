import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/terrain_horizon/data/providers/tiled_terrain_data_provider.dart';
import 'package:luna_sight/features/terrain_horizon/data/services/dem_tile_loader.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/dem_metadata.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';

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
}
