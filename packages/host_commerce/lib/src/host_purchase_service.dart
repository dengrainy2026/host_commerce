import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'commerce_catalog.dart';
import 'host_commerce_repository.dart';
import 'host_commerce_state.dart';
import 'host_in_app_purchase_client.dart';
import 'host_store_product.dart';
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
    StoreOperationCoordinator? operationCoordinator,
    this.restoreSettleDuration = const Duration(milliseconds: 500),
  }) : _catalog = catalog, // ignore: prefer_initializing_formals
       _client = client ?? PluginHostInAppPurchaseClient(),
       _operationCoordinator = operationCoordinator ?? StoreOperationCoordinator();

  final HostCommerceRepository _commerceRepository;
  final HostProductCatalog _catalog;
  final HostInAppPurchaseClient _client;
  final StoreOperationCoordinator _operationCoordinator;
  final Duration restoreSettleDuration;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _processingTail = Future<void>.value();
  _HostPurchaseOperation? _activePurchase;
  _HostRestoreOperation? _activeRestore;
  final Map<String, ProductDetails> _productDetails = <String, ProductDetails>{};

  HostCommerceState get commerceState => _commerceRepository.state;

  void initialize() {
    _subscription ??= _client.purchaseStream.listen(
      _queuePurchaseUpdates,
      onError: (_) {},
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
      throw StateError(error.message);
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
      throw ArgumentError.value(productId, 'productId', 'Unknown subscription.');
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
        _HostPurchaseOperation.credits(productId, _catalog.creditsFor(productId)),
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

    _activePurchase = operation;
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: details);
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

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      final _HostPurchaseOperation? activePurchase = _activePurchase;
      if (activePurchase != null && _belongsToActivePurchase(activePurchase, purchase)) {
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
          StateError(purchase.error?.message ?? 'The purchase failed.'),
        );
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        try {
          if (operation.credits case final int credits) {
            await _commerceRepository.recordCreditPurchase(credits);
          } else {
            await _commerceRepository.recordMembershipPurchase(
              membershipDuration: _catalog.membershipDurationFor(operation.productId),
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
        await _commerceRepository.recordMembershipPurchase(
          membershipDuration: _catalog.membershipDurationFor(purchase.productID),
        );
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
