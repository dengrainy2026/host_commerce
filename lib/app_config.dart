import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:host_commerce/host_commerce.dart';

/// Edit this object when turning the template into a new tool app.
///
/// Native identifiers and release metadata still live in the platform
/// projects and `pubspec.yaml`; all runtime app customization lives here.
const AppConfig kAppConfig = AppConfig(
  appearance: CommerceAppearance(
    appDisplayName: 'Veditor',
    privacyPolicyUrl: 'https://doc.veditor.top/privacy',
    termsOfUseUrl: 'https://doc.veditor.top/terms',
  ),
  themeSeedColor: Colors.blueGrey,
  tool: HomeToolConfig(
    sectionLabel: 'YOUR TOOL',
    title: 'Sample tool',
    icon: Icons.auto_fix_high,
  ),
  commerceRules: CommerceRules(
    initialCredits: 100,
    creationCost: 100,
    memberCreditsPerPeriod: 1000,
    redemptionCredits: 2000,
    membershipCreditPeriod: Duration(days: 7),
  ),
  androidCatalog: HostProductCatalog(
    weeklySubscriptionId: 'com.vedtr.sub.week',
    yearlySubscriptionId: 'com.vedtr.sub.year',
    creditProducts: <HostCreditProduct>[
      HostCreditProduct(productId: 'com.vedtr.cons.300', credits: 300),
      HostCreditProduct(productId: 'com.vedtr.cons.500', credits: 500),
      HostCreditProduct(productId: 'com.vedtr.cons.1000', credits: 1000),
      HostCreditProduct(productId: 'com.vedtr.cons.2000', credits: 2000),
    ],
  ),
  iosReleaseCatalog: HostProductCatalog(
    weeklySubscriptionId: 'week.clpfy.base',
    yearlySubscriptionId: 'year.clpfy.base',
    creditProducts: <HostCreditProduct>[
      HostCreditProduct(productId: 'coins.clpfy.500', credits: 500),
      HostCreditProduct(productId: 'coins.clpfy.1000', credits: 1000),
    ],
  ),
  iosDevelopmentCatalog: HostProductCatalog(
    weeklySubscriptionId: 'test.week',
    yearlySubscriptionId: 'test.year',
    creditProducts: <HostCreditProduct>[
      HostCreditProduct(productId: 'test.1000', credits: 1000),
      HostCreditProduct(productId: 'test.2000', credits: 2000),
    ],
  ),
);

@immutable
final class AppConfig {
  const AppConfig({
    required this.appearance,
    required this.themeSeedColor,
    required this.tool,
    required this.commerceRules,
    required this.androidCatalog,
    required this.iosReleaseCatalog,
    required this.iosDevelopmentCatalog,
  });

  final CommerceAppearance appearance;
  final Color themeSeedColor;
  final HomeToolConfig tool;
  final CommerceRules commerceRules;
  final HostProductCatalog androidCatalog;
  final HostProductCatalog iosReleaseCatalog;
  final HostProductCatalog iosDevelopmentCatalog;

  HostProductCatalog get currentCatalog =>
      catalogFor(platform: defaultTargetPlatform, releaseMode: kReleaseMode);

  @visibleForTesting
  HostProductCatalog catalogFor({
    required TargetPlatform platform,
    required bool releaseMode,
  }) {
    if (platform != TargetPlatform.iOS) {
      return androidCatalog;
    }
    return releaseMode ? iosReleaseCatalog : iosDevelopmentCatalog;
  }
}

@immutable
final class HomeToolConfig {
  const HomeToolConfig({
    required this.sectionLabel,
    required this.title,
    required this.icon,
  });

  final String sectionLabel;
  final String title;
  final IconData icon;
}
