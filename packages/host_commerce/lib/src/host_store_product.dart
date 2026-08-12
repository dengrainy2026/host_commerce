/// A store product with a localized price.
final class HostStoreProduct {
  const HostStoreProduct({
    required this.productId,
    required this.localizedPrice,
    required this.currencyCode,
  });

  final String productId;

  /// The store-formatted price for the user's current locale, including its
  /// localized currency symbol.
  final String localizedPrice;

  /// The ISO 4217 currency code returned by the store, such as USD or CNY.
  final String currencyCode;

  String get displayPrice {
    final String normalizedCurrencyCode = currencyCode.trim().toUpperCase();
    if (normalizedCurrencyCode.isEmpty) {
      return localizedPrice;
    }
    return '$localizedPrice $normalizedCurrencyCode';
  }
}

typedef HostProductLoader =
    Future<Map<String, HostStoreProduct>> Function(Set<String> productIds);
