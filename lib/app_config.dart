import 'package:flutter/foundation.dart';
import 'package:host_commerce/host_commerce.dart';

/// Template branding. A new app replaces these with its own display name and
/// legal URLs; a null URL hides the corresponding legal-footer link.
const String kAppDisplayName = 'Veditor';
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kPrivacyPolicyUrl = 'https://doc.veditor.top/privacy';
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kTermsOfUseUrl = 'https://doc.veditor.top/terms';

/// Builds the brand/legal/icon config consumed by the commerce UI.
CommerceAppearance buildAppearance() => const CommerceAppearance(
  appDisplayName: kAppDisplayName,
  privacyPolicyUrl: kPrivacyPolicyUrl,
  termsOfUseUrl: kTermsOfUseUrl,
);

/// Resolves the product catalog for the current platform and release mode.
///
/// The identifiers below are ported from the original app: iOS release uses
/// the Clipify production catalog, iOS debug/profile uses the StoreKit test
/// catalog, and every other platform uses the Android catalog. A new app
/// replaces these with its own StoreKit / Play Console product IDs.
HostProductCatalog buildCatalog() => buildCatalogFor(
  platform: defaultTargetPlatform,
  releaseMode: kReleaseMode,
);

@visibleForTesting
HostProductCatalog buildCatalogFor({
  required TargetPlatform platform,
  required bool releaseMode,
}) {
  if (platform != TargetPlatform.iOS) {
    return const HostProductCatalog(
      weeklySubscriptionId: 'com.vedtr.sub.week',
      yearlySubscriptionId: 'com.vedtr.sub.year',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'com.vedtr.cons.300', credits: 300),
        HostCreditProduct(productId: 'com.vedtr.cons.500', credits: 500),
        HostCreditProduct(productId: 'com.vedtr.cons.1000', credits: 1000),
        HostCreditProduct(productId: 'com.vedtr.cons.2000', credits: 2000),
      ],
    );
  }
  if (releaseMode) {
    return const HostProductCatalog(
      weeklySubscriptionId: 'week.clpfy.base',
      yearlySubscriptionId: 'year.clpfy.base',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.clpfy.500', credits: 500),
        HostCreditProduct(productId: 'coins.clpfy.1000', credits: 1000),
      ],
    );
  }
  return const HostProductCatalog(
    weeklySubscriptionId: 'test.week',
    yearlySubscriptionId: 'test.year',
    creditProducts: <HostCreditProduct>[
      HostCreditProduct(productId: 'test.1000', credits: 1000),
      HostCreditProduct(productId: 'test.2000', credits: 2000),
    ],
  );
}
