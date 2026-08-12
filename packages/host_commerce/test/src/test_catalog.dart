import 'package:host_commerce/host_commerce.dart';

/// Shared test catalog mirroring the original app's StoreKit test product
/// identifiers, used by the purchase-service and purchase-feedback tests.
const HostProductCatalog testCatalog = HostProductCatalog(
  weeklySubscriptionId: 'test.week',
  yearlySubscriptionId: 'test.year',
  creditProducts: <HostCreditProduct>[
    HostCreditProduct(productId: 'coins.test.300', credits: 300),
    HostCreditProduct(productId: 'coins.test.500', credits: 500),
    HostCreditProduct(productId: 'coins.test.1000', credits: 1000),
    HostCreditProduct(productId: 'coins.test.2000', credits: 2000),
  ],
);

/// Neutral branding for widget tests; 'Veditor Pro' keeps the expected
/// activation message.
const CommerceAppearance testAppearance = CommerceAppearance(
  appDisplayName: 'Veditor',
  privacyPolicyUrl: 'https://example.test/privacy',
  termsOfUseUrl: 'https://example.test/terms',
);
