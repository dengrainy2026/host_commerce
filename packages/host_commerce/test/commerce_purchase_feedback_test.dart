import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';

import 'src/test_catalog.dart';

void main() {
  testWidgets(
    'membership page keeps privacy and terms visible without scrolling',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MembershipSubscriptionScreen(
            catalog: testCatalog,
            appearance: testAppearance,
            rules: CommerceRules(),
          ),
        ),
      );

      _expectRequiredLegalActions(tester);
    },
  );

  testWidgets('credit page keeps privacy and terms visible without scrolling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CreditPurchaseScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          balance: 100,
        ),
      ),
    );

    _expectRequiredLegalActions(tester);
  });

  testWidgets(
    'membership purchase shows HUD then exits with success feedback',
    (WidgetTester tester) async {
      final Completer<void> purchase = Completer<void>();

      await tester.pumpWidget(
        _ScreenLauncher(
          child: MembershipSubscriptionScreen(
            catalog: testCatalog,
            appearance: testAppearance,
            rules: const CommerceRules(),
            onLoadProducts: _loadStoreProducts,
            onSubscribe: (_) => purchase.future,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(r'$1.99 USD'), findsWidgets);
      expect(find.text('Store price'), findsNothing);

      final Finder list = find.byKey(
        const PageStorageKey<String>('subscription-list'),
      );
      final Finder scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final Finder continueButton = find.byKey(
        const ValueKey<String>('subscribe-continue'),
      );
      await tester.scrollUntilVisible(
        continueButton,
        160,
        scrollable: scrollable,
      );
      await tester.drag(scrollable, const Offset(0, -80));
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('commerce-loading-hud')),
        findsOneWidget,
      );
      expect(find.text('Processing purchase…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('commerce-loading-hud')),
          matching: find.byType(Material),
        ),
        findsOneWidget,
      );

      purchase.complete();
      await tester.pumpAndSettle();

      expect(find.byType(MembershipSubscriptionScreen), findsNothing);
      expect(find.text('Veditor Pro activated successfully.'), findsOneWidget);
    },
  );

  testWidgets('cancelled membership purchase dismisses the HUD', (
    WidgetTester tester,
  ) async {
    final Completer<void> purchase = Completer<void>();

    await tester.pumpWidget(
      _ScreenLauncher(
        child: MembershipSubscriptionScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          rules: const CommerceRules(),
          onLoadProducts: _loadStoreProducts,
          onSubscribe: (_) => purchase.future,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final Finder list = find.byKey(
      const PageStorageKey<String>('subscription-list'),
    );
    final Finder scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final Finder continueButton = find.byKey(
      const ValueKey<String>('subscribe-continue'),
    );
    await tester.scrollUntilVisible(
      continueButton,
      160,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('commerce-loading-hud')),
      findsOneWidget,
    );

    purchase.completeError(const HostPurchaseCanceledException());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('commerce-loading-hud')),
      findsNothing,
    );
    expect(find.text('Purchase cancelled.'), findsOneWidget);
    expect(find.byType(MembershipSubscriptionScreen), findsOneWidget);
  });

  testWidgets('debug membership purchase failure shows the underlying reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _ScreenLauncher(
        child: MembershipSubscriptionScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          rules: const CommerceRules(),
          onSubscribe: (_) async {
            throw StateError('StoreKit product test.year was not found');
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final Finder list = find.byKey(
      const PageStorageKey<String>('subscription-list'),
    );
    final Finder scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final Finder continueButton = find.byKey(
      const ValueKey<String>('subscribe-continue'),
    );
    await tester.scrollUntilVisible(
      continueButton,
      160,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('StoreKit product test.year was not found'),
      findsOneWidget,
    );
    expect(find.text('Checkout is not connected yet.'), findsNothing);
  });

  testWidgets('membership copy reflects custom commerce rules', (
    WidgetTester tester,
  ) async {
    const CommerceRules rules = CommerceRules(
      creationCost: 75,
      memberCreditsPerPeriod: 600,
      membershipCreditPeriod: Duration(days: 3),
    );

    await tester.pumpWidget(
      const _ScreenLauncher(
        child: MembershipSubscriptionScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          rules: rules,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('600 credits every 3 days and member access.'),
      findsOneWidget,
    );
    expect(find.text('600 credits every 3 days'), findsOneWidget);
    expect(find.text('Each creation uses 75 credits'), findsOneWidget);
  });

  testWidgets('credit purchase shows HUD and refreshes the visible balance', (
    WidgetTester tester,
  ) async {
    final Completer<int> purchase = Completer<int>();
    int? requestedCredits;

    await tester.pumpWidget(
      _ScreenLauncher(
        child: CreditPurchaseScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          balance: 24,
          onLoadProducts: _loadStoreProducts,
          onPurchase: (int credits) {
            requestedCredits = credits;
            return purchase.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(r'$1.99 USD'), findsWidgets);
    expect(find.text('Store price'), findsNothing);

    final Finder list = find.byKey(
      const PageStorageKey<String>('credit-purchase-list'),
    );
    final Finder scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final Finder continueButton = find.byKey(
      const ValueKey<String>('credits-continue'),
    );
    await tester.scrollUntilVisible(
      continueButton,
      160,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump();

    expect(requestedCredits, 300);
    expect(
      find.byKey(const ValueKey<String>('commerce-loading-hud')),
      findsOneWidget,
    );
    expect(find.text('Processing purchase…'), findsOneWidget);

    purchase.complete(324);
    await tester.pumpAndSettle();

    expect(find.byType(CreditPurchaseScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('commerce-loading-hud')),
      findsNothing,
    );
    await tester.drag(scrollable, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('324'), findsOneWidget);
  });

  testWidgets('debug credit purchase failure shows the underlying reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreditPurchaseScreen(
          catalog: testCatalog,
          appearance: testAppearance,
          balance: 100,
          onPurchase: (_) async {
            throw StateError('Billing response code: itemUnavailable');
          },
        ),
      ),
    );
    final Finder list = find.byKey(
      const PageStorageKey<String>('credit-purchase-list'),
    );
    final Finder scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final Finder continueButton = find.byKey(
      const ValueKey<String>('credits-continue'),
    );
    await tester.scrollUntilVisible(
      continueButton,
      160,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Billing response code: itemUnavailable'),
      findsOneWidget,
    );
    expect(find.text('Checkout is not connected yet.'), findsNothing);
  });
}

void _expectRequiredLegalActions(WidgetTester tester) {
  final TextButton privacy = tester.widget<TextButton>(
    find.byKey(const ValueKey<String>('commerce-privacy-policy')),
  );
  final TextButton terms = tester.widget<TextButton>(
    find.byKey(const ValueKey<String>('commerce-terms-of-use')),
  );
  expect(find.text('Privacy Policy'), findsOneWidget);
  expect(find.text('Terms of Use'), findsOneWidget);
  expect(privacy.onPressed, isNotNull);
  expect(terms.onPressed, isNotNull);
}

Future<Map<String, HostStoreProduct>> _loadStoreProducts(
  Set<String> productIds,
) async => <String, HostStoreProduct>{
  for (final String productId in productIds)
    productId: HostStoreProduct(
      productId: productId,
      localizedPrice: r'$1.99',
      currencyCode: 'USD',
    ),
};

final class _ScreenLauncher extends StatelessWidget {
  const _ScreenLauncher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: (_) => child)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}
