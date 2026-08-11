import 'package:in_app_purchase/in_app_purchase.dart';

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

final class PluginHostInAppPurchaseClient implements HostInAppPurchaseClient {
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
}
