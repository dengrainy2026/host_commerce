import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'commerce_catalog.dart';
import 'host_commerce_repository.dart';
import 'host_commerce_state.dart';
import 'host_in_app_purchase_client.dart';
import 'host_store_product.dart';
import 'host_purchase_verification.dart';
import 'store_operation_coordinator.dart';

final class HostPurchaseCanceledException implements Exception {
  const HostPurchaseCanceledException();

  @override
  String toString() => 'The purchase was cancelled.';
}

/// Drives the store purchase/restore lifecycle and records the resulting
/// entitlement changes on a [HostCommerceRepository].
///
/// The purchase stream is process-wide; every state change is funneled through
/// a [StoreOperationCoordinator] so host and H5 store behaviors stay isolated.
final class HostPurchaseService {
  HostPurchaseService(
    this._commerceRepository, {
    required HostProductCatalog catalog,
    HostInAppPurchaseClient? client,
    HostPurchaseVerifier? verifier,
    HostVerifiedCommerceReporter reporter =
        const NoopHostVerifiedCommerceReporter(),
    StoreOperationCoordinator? operationCoordinator,
    this.restoreSettleDuration = const Duration(milliseconds: 500),
  }) : _catalog = catalog, // ignore: prefer_initializing_formals
       _client = client ?? PluginHostInAppPurchaseClient(),
       _verifier = verifier ?? NoReceiptHostPurchaseVerifier(catalog),
       _reporter = reporter, // ignore: prefer_initializing_formals
       _operationCoordinator =
           operationCoordinator ?? StoreOperationCoordinator();

  final HostCommerceRepository _commerceRepository;
  final HostProductCatalog _catalog;
  final HostInAppPurchaseClient _client;
  final HostPurchaseVerifier _verifier;
  final HostVerifiedCommerceReporter _reporter;
  final StoreOperationCoordinator _operationCoordinator;
  final Duration restoreSettleDuration;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _processingTail = Future<void>.value();
  _HostPurchaseOperation? _activePurchase;
  _HostRestoreOperation? _activeRestore;
  final Map<String, ProductDetails> _productDetails =
      <String, ProductDetails>{};

  HostCommerceState get commerceState => _commerceRepository.state;

  void initialize() {
    _subscription ??= _client.purchaseStream.listen(
      _queuePurchaseUpdates,
      onError: _handlePurchaseStreamError,
    );
  }

  Future<Map<String, HostStoreProduct>> loadProducts(
    Set<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      return const <String, HostStoreProduct>{};
    }
    if (!await _client.isAvailable()) {
      throw StateError('The store is unavailable.');
    }
    final ProductDetailsResponse response = await _client.queryProductDetails(
      productIds,
    );
    if (response.error case final IAPError error) {
      throw StateError(error.toString());
    }

    final Map<String, HostStoreProduct> products = <String, HostStoreProduct>{};
    for (final ProductDetails details in response.productDetails) {
      if (!productIds.contains(details.id)) {
        continue;
      }
      _productDetails[details.id] = details;
      products[details.id] = HostStoreProduct(
        productId: details.id,
        localizedPrice: details.price,
        currencyCode: details.currencyCode,
      );
    }
    return Map<String, HostStoreProduct>.unmodifiable(products);
  }

  Future<void> purchaseSubscription(String productId) async {
    if (!_catalog.allSubscriptionIds.contains(productId)) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Unknown subscription.',
      );
    }
    await _operationCoordinator.run(
      StoreOperationOwner.host,
      () => _startPurchase(
        _HostPurchaseOperation.subscription(productId),
        consumable: false,
      ),
    );
  }

  Future<void> purchaseCredits(String productId) async {
    if (!_catalog.isCreditProduct(productId)) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Unknown host credit product.',
      );
    }
    await _commerceRepository.refresh();
    if (!_commerceRepository.state.isMember) {
      throw StateError('Only active members can buy credits.');
    }
    await _operationCoordinator.run(
      StoreOperationOwner.host,
      () => _startPurchase(
        _HostPurchaseOperation.credits(
          productId,
          _catalog.creditsFor(productId),
        ),
        consumable: true,
      ),
    );
  }

  Future<void> _startPurchase(
    _HostPurchaseOperation operation, {
    required bool consumable,
  }) async {
    ProductDetails? details = _productDetails[operation.productId];
    if (details == null) {
      final Map<String, HostStoreProduct> products = await loadProducts(
        <String>{operation.productId},
      );
      if (!products.containsKey(operation.productId)) {
        throw StateError('The product is unavailable.');
      }
      details = _productDetails[operation.productId];
    }
    if (details == null) {
      throw StateError('The product is unavailable.');
    }

    if (await _recoverPendingPurchases(operation)) {
      return;
    }

    _activePurchase = operation;
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: details,
      );
      final bool started = consumable
          ? await _client.buyConsumable(purchaseParam: purchaseParam)
          : await _client.buyNonConsumable(purchaseParam: purchaseParam);
      if (started) {
        await operation.completed.future.timeout(const Duration(minutes: 5));
        return;
      }
      throw StateError('The purchase could not be started.');
    } finally {
      if (identical(_activePurchase, operation)) {
        _activePurchase = null;
      }
    }
  }

  Future<bool> _recoverPendingPurchases(
    _HostPurchaseOperation operation,
  ) async {
    if (_client is! HostPendingPurchaseClient) {
      return false;
    }
    final HostPendingPurchaseClient recoveryClient =
        _client as HostPendingPurchaseClient;
    final List<PurchaseDetails> pending = await recoveryClient
        .pendingPurchasesFor(operation.productId);
    bool recoveredSuccess = false;
    bool stillPending = false;
    for (final PurchaseDetails purchase in pending) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          stillPending = true;
          continue;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await recoveryClient.completePendingPurchase(purchase);
          }
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final bool restored = purchase.status == PurchaseStatus.restored;
          final HostVerifiedPurchase verified = await _verifyPurchase(
            purchase,
            operation: operation,
            restored: restored,
          );
          final bool applied = await _applyVerifiedPurchase(verified);
          if (applied) {
            await _reportVerifiedPurchase(
              verified,
              restored: restored,
              storePurchase: purchase,
            );
          }
          if (purchase.pendingCompletePurchase) {
            await recoveryClient.completePendingPurchase(purchase);
          }
          recoveredSuccess = true;
      }
    }
    if (recoveredSuccess) {
      return true;
    }
    if (stillPending) {
      throw StateError(
        'A purchase for ${operation.productId} is still pending in the App Store.',
      );
    }
    return false;
  }

  Future<void> restorePurchases() =>
      _operationCoordinator.run(StoreOperationOwner.host, () async {
        if (!await _client.isAvailable()) {
          throw StateError('The store is unavailable.');
        }
        final _HostRestoreOperation operation = _HostRestoreOperation();
        _activeRestore = operation;
        try {
          await _client.restorePurchases();
          operation.invocationCompleted = true;
          _scheduleRestoreCompletion(operation);
          await operation.completed.future.timeout(const Duration(seconds: 30));
        } finally {
          operation.settleTimer?.cancel();
          if (identical(_activeRestore, operation)) {
            _activeRestore = null;
          }
        }
      });

  void _queuePurchaseUpdates(List<PurchaseDetails> purchases) {
    _processingTail = _processingTail
        .then((_) => _processPurchaseUpdates(purchases))
        .catchError((_) {});
  }

  void _handlePurchaseStreamError(Object error, StackTrace stackTrace) {
    final _HostPurchaseOperation? purchase = _activePurchase;
    if (purchase != null && !purchase.completed.isCompleted) {
      purchase.completed.completeError(error, stackTrace);
    }
    final _HostRestoreOperation? restore = _activeRestore;
    if (restore != null && !restore.completed.isCompleted) {
      restore.completed.completeError(error, stackTrace);
    }
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      final _HostPurchaseOperation? activePurchase = _activePurchase;
      if (activePurchase != null &&
          _belongsToActivePurchase(activePurchase, purchase)) {
        await _processActivePurchase(activePurchase, purchase);
        continue;
      }

      final _HostRestoreOperation? activeRestore = _activeRestore;
      if (activeRestore != null && purchase.status == PurchaseStatus.restored) {
        await _processActiveRestore(activeRestore, purchase);
        continue;
      }

      if (_operationCoordinator.activeOwner != StoreOperationOwner.h5 &&
          (purchase.status == PurchaseStatus.canceled ||
              purchase.status == PurchaseStatus.error)) {
        await _completeUnclaimedFailedPurchase(purchase);
      }
    }
  }

  bool _belongsToActivePurchase(
    _HostPurchaseOperation operation,
    PurchaseDetails purchase,
  ) {
    if (purchase.productID == operation.productId) {
      return true;
    }
    return purchase.productID.isEmpty &&
        (purchase.status == PurchaseStatus.canceled ||
            purchase.status == PurchaseStatus.error);
  }

  Future<void> _processActivePurchase(
    _HostPurchaseOperation operation,
    PurchaseDetails purchase,
  ) async {
    if (operation.completed.isCompleted) {
      return;
    }
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return;
      case PurchaseStatus.canceled:
        await _completeFailedPurchase(
          operation,
          purchase,
          const HostPurchaseCanceledException(),
        );
        return;
      case PurchaseStatus.error:
        await _completeFailedPurchase(
          operation,
          purchase,
          StateError(purchase.error?.toString() ?? 'The purchase failed.'),
        );
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        try {
          final HostVerifiedPurchase verified = await _verifyPurchase(
            purchase,
            operation: operation,
            restored: purchase.status == PurchaseStatus.restored,
          );
          final bool applied = await _applyVerifiedPurchase(verified);
          if (applied) {
            await _reportVerifiedPurchase(
              verified,
              restored: purchase.status == PurchaseStatus.restored,
              storePurchase: purchase,
            );
          }
          if (purchase.pendingCompletePurchase) {
            await _client.completePurchase(purchase);
          }
          operation.completed.complete();
        } catch (error, stackTrace) {
          operation.completed.completeError(error, stackTrace);
        }
    }
  }

  Future<void> _completeFailedPurchase(
    _HostPurchaseOperation operation,
    PurchaseDetails purchase,
    Object purchaseError,
  ) async {
    try {
      if (purchase.pendingCompletePurchase) {
        await _client.completePurchase(purchase);
      }
      operation.completed.completeError(purchaseError);
    } catch (error, stackTrace) {
      operation.completed.completeError(error, stackTrace);
    }
  }

  Future<void> _completeUnclaimedFailedPurchase(
    PurchaseDetails purchase,
  ) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }
    try {
      await _client.completePurchase(purchase);
    } on Object {
      // StoreKit redelivers unfinished transactions, so cleanup can be retried
      // on a later purchase-stream update.
    }
  }

  Future<void> _processActiveRestore(
    _HostRestoreOperation operation,
    PurchaseDetails purchase,
  ) async {
    if (operation.completed.isCompleted) {
      return;
    }
    try {
      if (_catalog.allSubscriptionIds.contains(purchase.productID)) {
        final HostVerifiedPurchase verified = await _verifyPurchase(
          purchase,
          operation: _HostPurchaseOperation.subscription(purchase.productID),
          restored: true,
        );
        final bool applied = await _applyVerifiedPurchase(verified);
        if (applied) {
          await _reportVerifiedPurchase(
            verified,
            restored: true,
            storePurchase: purchase,
          );
        }
        if (purchase.pendingCompletePurchase) {
          await _client.completePurchase(purchase);
        }
      }
      if (operation.invocationCompleted) {
        _scheduleRestoreCompletion(operation);
      }
    } catch (error, stackTrace) {
      operation.settleTimer?.cancel();
      operation.completed.completeError(error, stackTrace);
    }
  }

  Future<HostVerifiedPurchase> _verifyPurchase(
    PurchaseDetails purchase, {
    required _HostPurchaseOperation operation,
    required bool restored,
  }) async {
    final String transactionId = purchase.purchaseID?.trim() ?? '';
    if (transactionId.isEmpty) {
      throw StateError('The store did not provide a transaction identifier.');
    }
    final HostPurchaseKind kind = operation.credits == null
        ? HostPurchaseKind.subscription
        : HostPurchaseKind.credits;
    final HostPurchaseEvidence evidence = HostPurchaseEvidence(
      productId: operation.productId,
      transactionId: transactionId,
      platform: purchase.verificationData.source,
      receipt: purchase.verificationData.serverVerificationData,
      kind: kind,
      restored: restored,
      expectedCredits: operation.credits,
    );
    final HostVerifiedPurchase verified = await _verifier.verify(evidence);
    if (verified.productId != evidence.productId ||
        verified.transactionId != evidence.transactionId ||
        verified.kind != evidence.kind) {
      throw StateError(
        'Verified purchase does not match the store transaction.',
      );
    }
    if (kind == HostPurchaseKind.credits &&
        verified.creditsGranted != operation.credits) {
      throw StateError('Verified credit grant does not match the catalog.');
    }
    if (kind == HostPurchaseKind.subscription &&
        verified.membershipExpiresAt == null) {
      throw StateError('Verified membership expiration is missing.');
    }
    return verified;
  }

  Future<bool> _applyVerifiedPurchase(HostVerifiedPurchase purchase) {
    return switch (purchase.kind) {
      HostPurchaseKind.credits =>
        _commerceRepository.recordVerifiedCreditPurchase(
          transactionId: purchase.transactionId,
          credits: purchase.creditsGranted!,
        ),
      HostPurchaseKind.subscription =>
        _commerceRepository.recordVerifiedMembershipPurchase(
          transactionId: purchase.transactionId,
          membershipExpiresAt: purchase.membershipExpiresAt!,
        ),
    };
  }

  Future<void> _reportVerifiedPurchase(
    HostVerifiedPurchase purchase, {
    required bool restored,
    required PurchaseDetails storePurchase,
  }) async {
    try {
      await _reporter.report(
        purchase,
        restored: restored,
        storePurchase: storePurchase,
        storeProduct: _productDetails[purchase.productId],
      );
    } on Object {
      // Analytics must never strand a verified and persisted transaction.
    }
  }

  void _scheduleRestoreCompletion(_HostRestoreOperation operation) {
    if (operation.completed.isCompleted) {
      return;
    }
    operation.settleTimer?.cancel();
    operation.settleTimer = Timer(restoreSettleDuration, () {
      if (!operation.completed.isCompleted) {
        operation.completed.complete();
      }
    });
  }

  Future<void> dispose() async {
    _activeRestore?.settleTimer?.cancel();
    await _subscription?.cancel();
  }
}

final class _HostPurchaseOperation {
  _HostPurchaseOperation.subscription(this.productId) : credits = null;

  _HostPurchaseOperation.credits(this.productId, this.credits);

  final String productId;
  final int? credits;
  final Completer<void> completed = Completer<void>();
}

final class _HostRestoreOperation {
  final Completer<void> completed = Completer<void>();
  bool invocationCompleted = false;
  Timer? settleTimer;
}
