import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:host_commerce/host_commerce.dart';

import 'src/test_catalog.dart';

void main() {
  test('loads localized store prices with their currency codes', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
    );

    final products = await service.loadProducts(testCatalog.allSubscriptionIds);

    expect(products.keys, containsAll(testCatalog.allSubscriptionIds));
    expect(
      products[testCatalog.weeklySubscriptionId]!.displayPrice,
      r'$1.99 USD',
    );
    await service.dispose();
    await client.dispose();
  });

  test(
    'real store success grants host membership without receipt verification',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
      )..initialize();

      final Future<void> purchase = service.purchaseSubscription(
        testCatalog.weeklySubscriptionId,
      );
      await _flushPurchaseStream();
      client.emit(
        _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
      );
      await purchase;

      expect(commerceRepository.state.isMember, isTrue);
      expect(commerceRepository.state.membershipCredits, 1000);
      expect(client.completedPurchases, 1);
      await service.dispose();
      await client.dispose();
    },
  );

  test(
    'recovers and finishes an unfinished subscription before a duplicate buy',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient()
        ..pendingPurchases = <PurchaseDetails>[
          _purchase(
            testCatalog.yearlySubscriptionId,
            PurchaseStatus.purchased,
            purchaseId: 'unfinished-test-year',
          ),
        ];
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
      )..initialize();

      await service.purchaseSubscription(testCatalog.yearlySubscriptionId);

      expect(commerceRepository.state.isMember, isTrue);
      expect(
        commerceRepository.state.processedPurchaseIds,
        contains('unfinished-test-year'),
      );
      expect(client.nonConsumablePurchases, 0);
      expect(client.completedPurchases, 1);
      expect(client.completedPendingPurchases, 1);
      await service.dispose();
      await client.dispose();
    },
  );

  test(
    'duplicate unfinished consumable delivery grants credits once',
    () async {
      final DateTime now = DateTime.utc(2026, 1, 1);
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(
          HostCommerceState(
            isMember: true,
            membershipExpiresAt: now.add(const Duration(days: 30)),
            membershipCreditPeriodStartedAt: now,
          ),
        ),
        clock: () => now,
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final String productId = testCatalog.productIdForCredits(300);
      final _FakePurchaseClient client = _FakePurchaseClient()
        ..pendingPurchases = <PurchaseDetails>[
          _purchase(
            productId,
            PurchaseStatus.purchased,
            purchaseId: 'unfinished-credit-300',
          ),
          _purchase(
            productId,
            PurchaseStatus.purchased,
            purchaseId: 'unfinished-credit-300',
          ),
        ];
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
      )..initialize();

      await service.purchaseCredits(productId);

      expect(commerceRepository.state.permanentCredits, 400);
      expect(client.consumablePurchases, 0);
      expect(client.completedPurchases, 2);
      expect(client.completedPendingPurchases, 2);
      await service.dispose();
      await client.dispose();
    },
  );

  test(
    'does not finish or duplicate a transaction that is still pending',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient()
        ..pendingPurchases = <PurchaseDetails>[
          _purchase(
            testCatalog.yearlySubscriptionId,
            PurchaseStatus.pending,
            pendingCompletePurchase: false,
            purchaseId: 'pending-test-year',
          ),
        ];
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
      )..initialize();

      await expectLater(
        service.purchaseSubscription(testCatalog.yearlySubscriptionId),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('still pending in the App Store'),
          ),
        ),
      );

      expect(commerceRepository.state.isMember, isFalse);
      expect(client.nonConsumablePurchases, 0);
      expect(client.completedPurchases, 0);
      expect(client.completedPendingPurchases, 0);
      await service.dispose();
      await client.dispose();
    },
  );

  test(
    'empty-product Android cancellation ends the active host purchase',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
        verifier: _AcceptingVerifier(testCatalog),
      )..initialize();

      final Future<void> purchase = service.purchaseSubscription(
        testCatalog.weeklySubscriptionId,
      );
      await _flushPurchaseStream();
      client.emit(
        _purchase('', PurchaseStatus.canceled, pendingCompletePurchase: false),
      );

      await expectLater(
        purchase,
        throwsA(isA<HostPurchaseCanceledException>()),
      );
      expect(commerceRepository.state.isMember, isFalse);
      expect(client.completedPurchases, 0);
      await service.dispose();
      await client.dispose();
    },
  );

  test('purchase stream errors reach the active checkout caller', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
    )..initialize();

    final Future<void> purchase = service.purchaseSubscription(
      testCatalog.weeklySubscriptionId,
    );
    await _flushPurchaseStream();
    client.emitError(StateError('StoreKit purchase stream disconnected'));

    await expectLater(
      purchase,
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'StoreKit purchase stream disconnected',
        ),
      ),
    );
    await service.dispose();
    await client.dispose();
  });

  test(
    'cancelled host purchase finishes StoreKit transaction before retry',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
        verifier: _AcceptingVerifier(testCatalog),
      )..initialize();

      final Future<void> firstPurchase = service.purchaseSubscription(
        testCatalog.weeklySubscriptionId,
      );
      await _flushPurchaseStream();
      client.emit(
        _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.canceled),
      );

      await expectLater(
        firstPurchase,
        throwsA(isA<HostPurchaseCanceledException>()),
      );
      expect(client.completedPurchases, 1);

      final Future<void> retry = service.purchaseSubscription(
        testCatalog.weeklySubscriptionId,
      );
      await _flushPurchaseStream();
      expect(client.nonConsumablePurchases, 2);
      client.emit(
        _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
      );
      await retry;

      expect(client.completedPurchases, 2);
      expect(commerceRepository.state.isMember, isTrue);
      await service.dispose();
      await client.dispose();
    },
  );

  test('orphaned failed StoreKit transaction is finished on startup', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
    )..initialize();

    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.canceled),
    );
    await _flushPurchaseStream();

    expect(client.completedPurchases, 1);
    expect(commerceRepository.state.isMember, isFalse);
    await service.dispose();
    await client.dispose();
  });

  test('host does not finish an H5-owned failed transaction', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final StoreOperationCoordinator coordinator = StoreOperationCoordinator();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
      operationCoordinator: coordinator,
    )..initialize();
    final Completer<void> finishH5 = Completer<void>();
    final Future<void> h5Operation = coordinator.run(
      StoreOperationOwner.h5,
      () => finishH5.future,
    );
    await Future<void>.delayed(Duration.zero);

    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.canceled),
    );
    await _flushPurchaseStream();

    expect(client.completedPurchases, 0);
    finishH5.complete();
    await h5Operation;
    await service.dispose();
    await client.dispose();
  });

  test(
    'successful host restore verifies and stores membership before finishing',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
        verifier: _AcceptingVerifier(testCatalog),
        restoreSettleDuration: const Duration(milliseconds: 50),
      )..initialize();

      final Future<void> restore = service.restorePurchases();
      await _flushPurchaseStream();
      client.emit(
        _purchase(testCatalog.yearlySubscriptionId, PurchaseStatus.restored),
      );
      await restore;

      expect(commerceRepository.state.isMember, isTrue);
      expect(client.completedPurchases, 1);
      await service.dispose();
      await client.dispose();
    },
  );

  test('successful consumable purchase adds its fixed credit amount', () async {
    final DateTime now = DateTime.utc(2026, 1, 1);
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(
        HostCommerceState(
          isMember: true,
          permanentCredits: 20,
          membershipExpiresAt: now.add(const Duration(days: 365)),
          membershipCreditPeriodStartedAt: now,
        ),
      ),
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
      verifier: _AcceptingVerifier(testCatalog),
    )..initialize();

    final String credits500 = testCatalog.productIdForCredits(500);
    final Future<void> purchase = service.purchaseCredits(credits500);
    await _flushPurchaseStream();
    client.emit(_purchase(credits500, PurchaseStatus.purchased));
    await purchase;

    expect(commerceRepository.state.creditBalance, 520);
    expect(client.consumablePurchases, 1);
    expect(client.completedPurchases, 1);
    await service.dispose();
    await client.dispose();
  });

  test(
    'purchase updates not initiated by the host do not change host state',
    () async {
      final HostCommerceRepository commerceRepository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await commerceRepository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        commerceRepository,
        catalog: testCatalog,
        client: client,
      )..initialize();

      client.emit(
        _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
      );
      client.emit(
        _purchase(testCatalog.yearlySubscriptionId, PurchaseStatus.restored),
      );
      await _flushPurchaseStream();

      expect(commerceRepository.state.isMember, isFalse);
      expect(client.completedPurchases, 0);
      await service.dispose();
      await client.dispose();
    },
  );

  test('H5 behavior cannot be consumed as a host purchase', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final StoreOperationCoordinator coordinator = StoreOperationCoordinator();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
      verifier: _AcceptingVerifier(testCatalog),
      operationCoordinator: coordinator,
    )..initialize();
    final Completer<void> finishH5 = Completer<void>();
    final Future<void> h5Operation = coordinator.run(
      StoreOperationOwner.h5,
      () => finishH5.future,
    );
    await Future<void>.delayed(Duration.zero);

    final Future<void> hostPurchase = service.purchaseSubscription(
      testCatalog.weeklySubscriptionId,
    );
    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
    );
    await _flushPurchaseStream();

    expect(commerceRepository.state.isMember, isFalse);
    expect(client.nonConsumablePurchases, 0);

    finishH5.complete();
    await h5Operation;
    await _flushPurchaseStream();
    expect(client.nonConsumablePurchases, 1);

    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
    );
    await hostPurchase;

    expect(commerceRepository.state.isMember, isTrue);
    await service.dispose();
    await client.dispose();
  });

  test('non-members cannot start a host credit purchase', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
    )..initialize();

    await expectLater(
      service.purchaseCredits(testCatalog.productIdForCredits(300)),
      throwsA(isA<StateError>()),
    );
    expect(client.consumablePurchases, 0);

    await service.dispose();
    await client.dispose();
  });

  test('backend rejection never grants or finishes a purchase', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
      verifier: const RejectingHostPurchaseVerifier(),
    )..initialize();

    final Future<void> purchase = service.purchaseSubscription(
      testCatalog.weeklySubscriptionId,
    );
    await _flushPurchaseStream();
    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
    );

    await expectLater(purchase, throwsA(isA<StateError>()));
    expect(commerceRepository.state.isMember, isFalse);
    expect(client.completedPurchases, 0);
    await service.dispose();
    await client.dispose();
  });

  test('analytics failure cannot strand a verified purchase', () async {
    final HostCommerceRepository commerceRepository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerceRepository.initialize();
    final _FakePurchaseClient client = _FakePurchaseClient();
    final HostPurchaseService service = HostPurchaseService(
      commerceRepository,
      catalog: testCatalog,
      client: client,
      verifier: _AcceptingVerifier(testCatalog),
      reporter: const _FailingReporter(),
    )..initialize();

    final Future<void> purchase = service.purchaseSubscription(
      testCatalog.weeklySubscriptionId,
    );
    await _flushPurchaseStream();
    client.emit(
      _purchase(testCatalog.weeklySubscriptionId, PurchaseStatus.purchased),
    );
    await purchase;

    expect(commerceRepository.state.isMember, isTrue);
    expect(client.completedPurchases, 1);
    await service.dispose();
    await client.dispose();
  });
}

Future<void> _flushPurchaseStream() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

PurchaseDetails _purchase(
  String productId,
  PurchaseStatus status, {
  bool pendingCompletePurchase = true,
  String purchaseId = 'purchase-id',
}) {
  final PurchaseDetails purchase = PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'not-verified',
      serverVerificationData: 'not-verified',
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  return purchase;
}

final class _FakePurchaseClient
    implements HostInAppPurchaseClient, HostPendingPurchaseClient {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  int completedPurchases = 0;
  int completedPendingPurchases = 0;
  int consumablePurchases = 0;
  int nonConsumablePurchases = 0;
  List<PurchaseDetails> pendingPurchases = <PurchaseDetails>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(PurchaseDetails purchase) =>
      _controller.add(<PurchaseDetails>[purchase]);

  void emitError(Object error) =>
      _controller.addError(error, StackTrace.current);

  @override
  Future<List<PurchaseDetails>> pendingPurchasesFor(String productId) async =>
      pendingPurchases
          .where((PurchaseDetails purchase) => purchase.productID == productId)
          .toList(growable: false);

  @override
  Future<void> completePendingPurchase(PurchaseDetails purchase) async {
    completedPendingPurchases += 1;
    await completePurchase(purchase);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: identifiers
        .map(
          (String identifier) => ProductDetails(
            id: identifier,
            title: 'Store product',
            description: 'Store product',
            price: r'$1.99',
            rawPrice: 1.99,
            currencyCode: 'USD',
          ),
        )
        .toList(),
    notFoundIDs: const <String>[],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    nonConsumablePurchases += 1;
    return true;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async {
    consumablePurchases += 1;
    return true;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases += 1;
  }

  Future<void> dispose() => _controller.close();
}

final class _AcceptingVerifier implements HostPurchaseVerifier {
  const _AcceptingVerifier(this.catalog);

  final HostProductCatalog catalog;

  @override
  Future<HostVerifiedPurchase> verify(HostPurchaseEvidence evidence) async {
    return switch (evidence.kind) {
      HostPurchaseKind.credits => HostVerifiedPurchase(
        productId: evidence.productId,
        transactionId: evidence.transactionId,
        kind: evidence.kind,
        creditsGranted: catalog.creditsFor(evidence.productId),
      ),
      HostPurchaseKind.subscription => HostVerifiedPurchase(
        productId: evidence.productId,
        transactionId: evidence.transactionId,
        kind: evidence.kind,
        membershipExpiresAt: DateTime.now().toUtc().add(
          catalog.membershipDurationFor(evidence.productId),
        ),
      ),
    };
  }
}

final class _FailingReporter implements HostVerifiedCommerceReporter {
  const _FailingReporter();

  @override
  Future<void> report(
    HostVerifiedPurchase purchase, {
    required bool restored,
    required PurchaseDetails storePurchase,
    ProductDetails? storeProduct,
  }) => Future<void>.error(StateError('analytics unavailable'));
}
