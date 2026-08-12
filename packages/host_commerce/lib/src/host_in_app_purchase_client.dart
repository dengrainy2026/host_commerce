import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Selects StoreKit 1 on iOS so stale queued transactions can be recovered
/// before another payment for the same product is submitted.
Future<void> initializeHostCommerceStoreKit() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  // StoreKit 1 exposes the payment queue used by the recovery path below.
  // ignore: deprecated_member_use
  await InAppPurchaseStoreKitPlatform.enableStoreKit1();
  InAppPurchaseStoreKitPlatform.registerPlatform();
}

/// Thin boundary around the store platform plugin so purchase flow can be
/// faked in tests.
abstract interface class HostInAppPurchaseClient {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<bool> buyConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

/// Optional iOS recovery surface implemented by the production store client.
///
/// Keeping it separate preserves compatibility with injected clients that do
/// not need platform pending-transaction recovery.
abstract interface class HostPendingPurchaseClient {
  Future<List<PurchaseDetails>> pendingPurchasesFor(String productId);

  Future<void> completePendingPurchase(PurchaseDetails purchase);
}

final class PluginHostInAppPurchaseClient
    implements HostInAppPurchaseClient, HostPendingPurchaseClient {
  PluginHostInAppPurchaseClient({InAppPurchase? plugin})
    : _plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase _plugin;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _plugin.purchaseStream;

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _plugin.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _plugin.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) =>
      _plugin.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);

  @override
  Future<void> restorePurchases() => _plugin.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _plugin.completePurchase(purchase);

  @override
  Future<List<PurchaseDetails>> pendingPurchasesFor(String productId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const <PurchaseDetails>[];
    }
    final List<SKPaymentTransactionWrapper> transactions =
        await SKPaymentQueueWrapper().transactions();
    return transactions
        .where(
          (SKPaymentTransactionWrapper transaction) =>
              transaction.payment.productIdentifier == productId,
        )
        .map(
          (SKPaymentTransactionWrapper transaction) =>
              AppStorePurchaseDetails.fromSKTransaction(transaction, ''),
        )
        .toList(growable: false);
  }

  @override
  Future<void> completePendingPurchase(PurchaseDetails purchase) =>
      _plugin.completePurchase(purchase);
}
