/// Membership subscription tiers offered by the catalog.
enum MembershipPlan { weekly, annual }

/// One purchasable credit package in the host catalog.
final class HostCreditProduct {
  const HostCreditProduct({required this.productId, required this.credits});

  final String productId;
  final int credits;
}

/// App-supplied product catalog: subscription tiers and credit packages.
///
/// This replaces the platform-aware static product-id lookup the original app
/// hardcoded. The host app resolves its platform/release-specific identifiers
/// (for example StoreKit test products) and supplies them here.
final class HostProductCatalog {
  const HostProductCatalog({
    required this.weeklySubscriptionId,
    required this.yearlySubscriptionId,
    required this.creditProducts,
    this.weeklyDuration = const Duration(days: 7),
    this.yearlyDuration = const Duration(days: 365),
  // Rejects the canonical empty list under const evaluation; `length` is not
  // const-evaluable, so the check compares against `const []` by identity.
  }) : assert(creditProducts != const <HostCreditProduct>[]);

  final String weeklySubscriptionId;
  final String yearlySubscriptionId;

  /// Credit packages in display order; the first is the default selection.
  final List<HostCreditProduct> creditProducts;

  final Duration weeklyDuration;
  final Duration yearlyDuration;

  Set<String> get allSubscriptionIds =>
      <String>{weeklySubscriptionId, yearlySubscriptionId};

  List<int> get availableCreditPackages =>
      <int>[for (final HostCreditProduct product in creditProducts) product.credits];

  Duration membershipDurationFor(String productId) {
    if (productId == weeklySubscriptionId) {
      return weeklyDuration;
    }
    if (productId == yearlySubscriptionId) {
      return yearlyDuration;
    }
    throw ArgumentError.value(productId, 'productId', 'Unknown subscription.');
  }

  int creditsFor(String productId) {
    for (final HostCreditProduct product in creditProducts) {
      if (product.productId == productId) {
        return product.credits;
      }
    }
    throw ArgumentError.value(productId, 'productId', 'Unknown credit product.');
  }

  bool isCreditProduct(String productId) =>
      creditProducts.any((HostCreditProduct product) => product.productId == productId);

  String productIdForCredits(int credits) {
    for (final HostCreditProduct product in creditProducts) {
      if (product.credits == credits) {
        return product.productId;
      }
    }
    throw ArgumentError.value(credits, 'credits', 'Unknown credit package.');
  }

  String subscriptionIdFor(MembershipPlan plan) => switch (plan) {
    MembershipPlan.weekly => weeklySubscriptionId,
    MembershipPlan.annual => yearlySubscriptionId,
  };
}
