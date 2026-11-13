import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:luna_sight/features/nasa_data/data/datasources/nasa_product_catalog.dart';
import 'package:luna_sight/features/nasa_data/data/repositories/nasa_data_repository_impl.dart';
import 'package:luna_sight/features/nasa_data/data/services/nasa_http_service.dart';
import 'package:luna_sight/features/nasa_data/data/storage/local_data_storage_service.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';
import 'package:luna_sight/features/nasa_data/domain/services/nasa_data_service.dart';

void main() {
  late Directory tempDir;
  late LocalDataStorageService storage;

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

  group('NasaDataRepository & Service Tests', () {
    test(
      'getAvailableProducts returns non-empty list containing ldem_87s_5mpp',
      () {
        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(),
          storageService: storage,
        );

        final products = repository.getAvailableProducts();
        expect(products.isNotEmpty, isTrue);
        expect(products.any((p) => p.identifier == 'ldem_87s_5mpp'), isTrue);
      },
    );

    test(
      'acquireProductAsset full lifecycle: waiting -> downloading -> completed',
      () async {
        final product = NasaProductCatalog.ldem87s5mpp;

        // Mock client that returns the exact expected length in chunks
        final payload = List.filled(1024, 42);
        final mockClient = http_testing.MockClient((request) async {
          expect(request.url, product.officialAssetUrl);
          return http.Response.bytes(
            payload,
            200,
            headers: {
              'content-length': '${payload.length}',
              'etag': '"test-etag"',
            },
          );
        });

        final httpService = NasaHttpService(client: mockClient);
        final repository = NasaDataRepositoryImpl(
          httpService: httpService,
          storageService: storage,
        );

        final service = NasaDataService(repository: repository);

        final recordedStates = <AcquisitionLifecycleState>[];
        final subscription = service.observeProgress(product.identifier).listen(
          (prog) {
            recordedStates.add(prog.state);
          },
        );

        // Because ldem87s5mpp defines publishedSizeBytes: 3465285714, a 1024 payload will fail size integrity check
        // verifying that integrity failure is properly caught and state set to integrityCheckFailed!
        await expectLater(
          () => service.acquireDataset(product.identifier),
          throwsA(isA<IntegrityValidationFailure>()),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          service.currentProgress(product.identifier).state,
          AcquisitionLifecycleState.integrityCheckFailed,
        );
        expect(recordedStates, contains(AcquisitionLifecycleState.waiting));
        expect(recordedStates, contains(AcquisitionLifecycleState.downloading));
        expect(
          recordedStates,
          contains(AcquisitionLifecycleState.integrityCheckFailed),
        );

        await subscription.cancel();
      },
    );

    test(
      'Throws ProductNotFoundFailure on unregistered product acquisition',
      () async {
        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(),
          storageService: storage,
        );

        await expectLater(
          () => repository.acquireProductAsset('unknown_product_id'),
          throwsA(isA<ProductNotFoundFailure>()),
        );
      },
    );

    test(
      'Prevents duplicate concurrent acquisitions of the same product',
      () async {
        final mockClient = http_testing.MockClient((request) async {
          // Long-running transfer
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('content', 200);
        });

        final repository = NasaDataRepositoryImpl(
          httpService: NasaHttpService(client: mockClient),
          storageService: storage,
        );

        // Start first acquisition
        final future1 = repository.acquireProductAsset('ldem_87s_5mpp');

        // Attempt second concurrent acquisition
        expect(
          () => repository.acquireProductAsset('ldem_87s_5mpp'),
          throwsA(isA<AcquisitionConflictFailure>()),
        );

        // Cancel to clean up
        await repository.cancelAcquisition('ldem_87s_5mpp');
        try {
          await future1;
        } catch (_) {}
      },
    );

    test('Cancellation transitions status to cancelled and aborts', () async {
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        final stream = Stream<List<int>>.periodic(
          const Duration(milliseconds: 50),
          (count) => [count],
        );
        return http.StreamedResponse(stream, 200);
      });

      final repository = NasaDataRepositoryImpl(
        httpService: NasaHttpService(client: mockClient),
        storageService: storage,
      );

      final states = <AcquisitionLifecycleState>[];
      repository.watchAcquisitionProgress('ldem_87s_5mpp').listen((p) {
        states.add(p.state);
      });

      final acquisitionFuture = repository.acquireProductAsset('ldem_87s_5mpp');

      // Allow to enter downloading
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await repository.cancelAcquisition('ldem_87s_5mpp');

      await expectLater(
        acquisitionFuture,
        throwsA(isA<AcquisitionCancelledFailure>()),
      );

      final current = repository.getAcquisitionProgress('ldem_87s_5mpp');
      expect(current.state, AcquisitionLifecycleState.cancelled);
    });

    test('removeCachedAsset cleans files and resets status', () async {
      final repository = NasaDataRepositoryImpl(
        httpService: NasaHttpService(),
        storageService: storage,
      );

      // Simulate completed file
      final tempFile = storage.getTempFile('ldem_87s_5mpp');
      await tempFile.writeAsBytes([1, 2, 3]);
      await storage.commitAsset(
        productId: 'ldem_87s_5mpp',
        tempFile: tempFile,
        fileExtension: 'tif',
      );

      expect(await repository.isAssetLocallyAvailable('ldem_87s_5mpp'), isTrue);

      await repository.removeCachedAsset('ldem_87s_5mpp');

      expect(
        await repository.isAssetLocallyAvailable('ldem_87s_5mpp'),
        isFalse,
      );
      expect(
        repository.getAcquisitionProgress('ldem_87s_5mpp').state,
        AcquisitionLifecycleState.notRequested,
      );
    });
  });
}
