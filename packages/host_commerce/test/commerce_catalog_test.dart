import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';

void main() {
  test('catalog exposes subscription ids and durations by tier', () {
    const HostProductCatalog catalog = HostProductCatalog(
      weeklySubscriptionId: 'week.test.base',
      yearlySubscriptionId: 'year.test.base',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.test.500', credits: 500),
        HostCreditProduct(productId: 'coins.test.1000', credits: 1000),
      ],
    );

    expect(catalog.allSubscriptionIds, <String>{
      'week.test.base',
      'year.test.base',
    });
    expect(catalog.weeklyDuration, const Duration(days: 7));
    expect(catalog.yearlyDuration, const Duration(days: 365));
    expect(
      catalog.membershipDurationFor('week.test.base'),
      const Duration(days: 7),
    );
    expect(
      catalog.membershipDurationFor('year.test.base'),
      const Duration(days: 365),
    );
    expect(
      () => catalog.membershipDurationFor('unknown.product'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('custom subscription durations are honored', () {
    const HostProductCatalog catalog = HostProductCatalog(
      weeklySubscriptionId: 'week.test.base',
      yearlySubscriptionId: 'year.test.base',
      weeklyDuration: Duration(days: 14),
      yearlyDuration: Duration(days: 90),
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.test.500', credits: 500),
      ],
    );

    expect(
      catalog.membershipDurationFor('week.test.base'),
      const Duration(days: 14),
    );
    expect(
      catalog.membershipDurationFor('year.test.base'),
      const Duration(days: 90),
    );
  });

  test('credit packages keep display order and map both directions', () {
    const HostProductCatalog catalog = HostProductCatalog(
      weeklySubscriptionId: 'week.test.base',
      yearlySubscriptionId: 'year.test.base',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.test.500', credits: 500),
        HostCreditProduct(productId: 'coins.test.1000', credits: 1000),
        HostCreditProduct(productId: 'coins.test.2000', credits: 2000),
      ],
    );

    expect(catalog.availableCreditPackages, <int>[500, 1000, 2000]);
    expect(catalog.isCreditProduct('coins.test.500'), isTrue);
    expect(catalog.isCreditProduct('unknown.product'), isFalse);
    expect(catalog.creditsFor('coins.test.1000'), 1000);
    expect(catalog.productIdForCredits(2000), 'coins.test.2000');
    expect(
      () => catalog.creditsFor('unknown.product'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => catalog.productIdForCredits(999),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('subscriptionIdFor maps membership plans to catalog ids', () {
    const HostProductCatalog catalog = HostProductCatalog(
      weeklySubscriptionId: 'week.test.base',
      yearlySubscriptionId: 'year.test.base',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.test.500', credits: 500),
      ],
    );

    expect(catalog.subscriptionIdFor(MembershipPlan.weekly), 'week.test.base');
    expect(catalog.subscriptionIdFor(MembershipPlan.annual), 'year.test.base');
  });

  test('the first credit package is the default selection', () {
    const HostProductCatalog catalog = HostProductCatalog(
      weeklySubscriptionId: 'week.test.base',
      yearlySubscriptionId: 'year.test.base',
      creditProducts: <HostCreditProduct>[
        HostCreditProduct(productId: 'coins.test.300', credits: 300),
        HostCreditProduct(productId: 'coins.test.1000', credits: 1000),
      ],
    );

    expect(catalog.availableCreditPackages.first, 300);
  });
}
