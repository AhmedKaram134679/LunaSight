import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:luna_sight/features/nasa_data/data/repositories/nasa_data_repository_impl.dart';
import 'package:luna_sight/features/nasa_data/data/services/nasa_http_service.dart';
import 'package:luna_sight/features/nasa_data/data/storage/local_data_storage_service.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';
import 'package:luna_sight/features/nasa_data/domain/services/nasa_data_service.dart';

void main() {
  late Directory tempDir;
  late LocalDataStorageService storage;

  final testProduct = NasaProductDefinition(
    identifier: 'test_lunar_elevation',
    title: 'Test Lunar Elevation Model',
    sourceOrganization: 'NASA GSFC PGDA',
    officialProductPageUrl: Uri.parse('https://pgda.gsfc.nasa.gov/products/81'),
    officialAssetUrl: Uri.parse(
      'https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
    ),
    format: 'GeoTIFF',
    publishedSizeBytes: 1024,
    publishedSizeDescription: '1 KB test',
    spatialResolution: 5.0,
    spatialResolutionUnit: 'm/pixel',
    horizontalCoordinateSystem: 'South Polar Stereographic',
    horizontalCoordinateUnit: 'meters',
    referenceFrame: 'MOON_ME',
    ephemerisAssociation: 'DE421',
    pixelRegistration: PixelRegistration.pixelRegistered,
    elevationMeasurement: 'Surface height',
    elevationUnit: 'meters',
    coverageDescription: 'Polar 87S-90S',
    processingNotes: 'Test fixture',
    citation: 'Barker et al., 2021',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nasa_repo_test_');
    storage = LocalDataStorageService(baseStorageDirectory: tempDir);
    await storage.initialize();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('NasaDataRepository Lifecycle Tests', () {
    test(
      'Successful acquisition lifecycle: waiting -> downloading -> completed',
      () async {
        final payload = List.generate(1024, (i) => i % 256);

        final mockClient = http_testing.MockClient((request) async {
          return http.Response.bytes(
            payload,
            200,
            headers: {'content-length': '1024', 'etag': '"complete-etag"'},
          );
        });

        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(client: mockClient),
          storageService: storage,
          customProductCatalog: [testProduct],
        );

        final service = NasaDataService(repository: repository);
        final states = <AcquisitionLifecycleState>[];

        final sub = service.observeProgress('test_lunar_elevation').listen((p) {
          states.add(p.state);
        });

        final metadata = await service.acquireDataset('test_lunar_elevation');

        expect(metadata.fileSizeBytes, 1024);
        expect(
          metadata.verificationLevel,
          IntegrityVerificationLevel.sizeVerified,
        );
        expect(metadata.isIntegrityVerified, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(states, contains(AcquisitionLifecycleState.waiting));
        expect(states, contains(AcquisitionLifecycleState.downloading));
        expect(states, contains(AcquisitionLifecycleState.completed));

        expect(
          await service.isDatasetAvailable('test_lunar_elevation'),
          isTrue,
        );

        await sub.cancel();
      },
    );

    test('Re-acquisition reuses existing verified asset without re-downloading unless forced', () async {
      int downloadAttempts = 0;
      final mockClient = http_testing.MockClient((request) async {
        downloadAttempts++;
        return http.Response.bytes(
          List.filled(1024, 0),
          200,
          headers: {'content-length': '1024'},
        );
      });

      final repository = NasaDataRepositoryImpl(
        httpService: NasaHttpService(client: mockClient),
        storageService: storage,
        customProductCatalog: [testProduct],
      );

      // First acquisition
      await repository.acquireProductAsset('test_lunar_elevation');
      expect(downloadAttempts, 1);

      // Second acquisition without force
      final cachedMeta = await repository.acquireProductAsset(
        'test_lunar_elevation',
      );
      expect(cachedMeta.fileSizeBytes, 1024);
      expect(downloadAttempts, 1); // No new download

      // Force re-acquisition
      await repository.acquireProductAsset(
        'test_lunar_elevation',
        forceReacquire: true,
      );
      expect(downloadAttempts, 2); // Downloaded again
    });

    test(
      'Prevents duplicate concurrent acquisitions of the same product',
      () async {
        final mockClient = http_testing.MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return http.Response('data', 200);
        });

        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(client: mockClient),
          storageService: storage,
          customProductCatalog: [testProduct],
        );

        final future1 = repository.acquireProductAsset('test_lunar_elevation');

        expect(
          () => repository.acquireProductAsset('test_lunar_elevation'),
          throwsA(isA<AcquisitionConflictFailure>()),
        );

        await repository.cancelAcquisition('test_lunar_elevation');
        try {
          await future1;
        } catch (_) {}
      },
    );

    test(
      'Cancellation transitions status to cancelled and aborts transfer',
      () async {
        final mockClient = http_testing.MockClient.streaming((
          request,
          bodyStream,
        ) async {
          final stream = Stream<List<int>>.periodic(
            const Duration(milliseconds: 30),
            (count) => [count],
          );
          return http.StreamedResponse(stream, 200);
        });

        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(client: mockClient),
          storageService: storage,
          customProductCatalog: [testProduct],
        );

        final future = repository.acquireProductAsset('test_lunar_elevation');

        await Future<void>.delayed(const Duration(milliseconds: 40));
        await repository.cancelAcquisition('test_lunar_elevation');

        await expectLater(future, throwsA(isA<AcquisitionCancelledFailure>()));

        expect(
          repository.getAcquisitionProgress('test_lunar_elevation').state,
          AcquisitionLifecycleState.cancelled,
        );
      },
    );

    test(
      'removeCachedAsset clears file, metadata, and resets progress',
      () async {
        final payload = List.generate(1024, (i) => i % 256);
        final mockClient = http_testing.MockClient((request) async {
          return http.Response.bytes(
            payload,
            200,
            headers: {'content-length': '1024'},
          );
        });

        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(client: mockClient),
          storageService: storage,
          customProductCatalog: [testProduct],
        );

        await repository.acquireProductAsset('test_lunar_elevation');
        expect(
          await repository.isAssetLocallyAvailable('test_lunar_elevation'),
          isTrue,
        );

        await repository.removeCachedAsset('test_lunar_elevation');
        expect(
          await repository.isAssetLocallyAvailable('test_lunar_elevation'),
          isFalse,
        );
        expect(
          repository.getAcquisitionProgress('test_lunar_elevation').state,
          AcquisitionLifecycleState.notRequested,
        );
      },
    );
  });
}
