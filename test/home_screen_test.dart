import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:veditor_commerce/app_config.dart';
import 'package:veditor_commerce/main.dart';

void main() {
  test('product catalog resolves by platform and release mode', () {
    final HostProductCatalog android = buildCatalogFor(
      platform: TargetPlatform.android,
      releaseMode: true,
    );
    expect(android.weeklySubscriptionId, 'com.vedtr.sub.week');
    expect(android.availableCreditPackages, <int>[300, 500, 1000, 2000]);

    final HostProductCatalog iosRelease = buildCatalogFor(
      platform: TargetPlatform.iOS,
      releaseMode: true,
    );
    expect(iosRelease.weeklySubscriptionId, 'week.clpfy.base');
    expect(iosRelease.availableCreditPackages, <int>[500, 1000]);

    final HostProductCatalog iosDebug = buildCatalogFor(
      platform: TargetPlatform.iOS,
      releaseMode: false,
    );
    expect(iosDebug.weeklySubscriptionId, 'test.week');
    expect(iosDebug.availableCreditPackages, <int>[1000, 2000]);
  });

  testWidgets(
    'fresh user runs the tool once, then runs out and reaches the paywall',
    (WidgetTester tester) async {
      final HostCommerceRepository repository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await repository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        repository,
        catalog: buildCatalogFor(
          platform: TargetPlatform.android,
          releaseMode: true,
        ),
        client: client,
      )..initialize();
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
      });

      await tester.pumpWidget(
        VeditorCommerceApp(
          commerceRepository: repository,
          purchaseService: service,
          appearance: buildAppearance(),
          catalog: buildCatalogFor(
            platform: TargetPlatform.android,
            releaseMode: true,
          ),
        ),
      );

      // A fresh user starts with 100 credits.
      expect(find.text('100'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);

      // First run consumes the creation cost.
      await tester.tap(find.byKey(const ValueKey<String>('run-tool')));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(repository.state.creditBalance, 0);

      // Second run hits the gate and routes a free user to the paywall.
      await tester.tap(find.byKey(const ValueKey<String>('run-tool')));
      await tester.pumpAndSettle();
      expect(find.byType(MembershipSubscriptionScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a member with an empty allowance is routed to the credit store',
    (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 1, 1);
      final HostCommerceRepository repository = HostCommerceRepository(
        MemoryHostCommerceStore(
          HostCommerceState(
            isMember: true,
            permanentCredits: 0,
            membershipCredits: 0,
            membershipExpiresAt: now.add(const Duration(days: 30)),
            membershipCreditPeriodStartedAt: now,
          ),
        ),
        clock: () => now,
        scheduleBoundaryTimers: false,
      );
      await repository.initialize();
      final _FakePurchaseClient client = _FakePurchaseClient();
      final HostPurchaseService service = HostPurchaseService(
        repository,
        catalog: buildCatalogFor(
          platform: TargetPlatform.android,
          releaseMode: true,
        ),
        client: client,
      )..initialize();
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
      });

      await tester.pumpWidget(
        VeditorCommerceApp(
          commerceRepository: repository,
          purchaseService: service,
          appearance: buildAppearance(),
          catalog: buildCatalogFor(
            platform: TargetPlatform.android,
            releaseMode: true,
          ),
        ),
      );

      expect(find.text('PRO'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('run-tool')));
      await tester.pumpAndSettle();
      expect(find.byType(CreditPurchaseScreen), findsOneWidget);
    },
  );
}

final class _FakePurchaseClient implements HostInAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: <ProductDetails>[
      for (final String identifier in identifiers)
        ProductDetails(
          id: identifier,
          title: 'Store product',
          description: 'Store product',
          price: r'$1.99',
          rawPrice: 1.99,
          currencyCode: 'USD',
        ),
    ],
    notFoundIDs: const <String>[],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  Future<void> dispose() => _controller.close();
}
