import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';

void main() {
  test(
    'new users receive 100 credits and one creation consumes them',
    () async {
      final HostCommerceRepository repository = HostCommerceRepository(
        MemoryHostCommerceStore(),
        scheduleBoundaryTimers: false,
      );
      await repository.initialize();

      expect(repository.state.creditBalance, 100);
      expect(
        await repository.consumeCredits(repository.rules.creationCost),
        isTrue,
      );
      expect(repository.state.creditBalance, 0);
      expect(
        await repository.consumeCredits(repository.rules.creationCost),
        isFalse,
      );
    },
  );

  test('custom rules drive the complete local credit economy', () async {
    DateTime now = DateTime.utc(2026, 1, 1);
    const CommerceRules rules = CommerceRules(
      initialCredits: 250,
      creationCost: 75,
      memberCreditsPerPeriod: 600,
      redemptionCredits: 40,
      membershipCreditPeriod: Duration(days: 3),
    );
    final HostCommerceRepository repository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      rules: rules,
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();

    expect(repository.state.creditBalance, 250);
    expect(await repository.consumeCredits(rules.creationCost), isTrue);
    expect(repository.state.creditBalance, 175);

    await repository.recordMembershipPurchase(
      membershipDuration: const Duration(days: 30),
    );
    expect(repository.state.membershipCredits, 600);

    await repository.consumeCredits(100);
    now = now.add(rules.membershipCreditPeriod);
    await repository.refresh();
    expect(repository.state.membershipCredits, 600);

    expect(await repository.redeemCode('TESTTESTTEST'), isTrue);
    expect(repository.state.permanentCredits, 215);

    await repository.clear();
    expect(repository.state.creditBalance, 250);
  });

  test('member weekly credits reset to 1000 without accumulating', () async {
    DateTime now = DateTime.utc(2026, 1, 1);
    final HostCommerceRepository repository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();
    await repository.recordMembershipPurchase(
      membershipDuration: const Duration(days: 30),
    );

    expect(repository.state.isMember, isTrue);
    expect(repository.state.membershipCredits, 1000);
    expect(repository.state.creditBalance, 1100);

    await repository.consumeCredits(300);
    expect(repository.state.membershipCredits, 700);
    expect(repository.state.permanentCredits, 100);

    now = now.add(const Duration(days: 7));
    await repository.refresh();
    expect(repository.state.membershipCredits, 1000);
    expect(repository.state.creditBalance, 1100);

    now = DateTime.utc(2026, 2, 1);
    await repository.refresh();
    expect(repository.state.isMember, isFalse);
    expect(repository.state.membershipCredits, 0);
    expect(repository.state.creditBalance, 100);
  });

  test('bought credits persist separately from the weekly allowance', () async {
    DateTime now = DateTime.utc(2026, 1, 1);
    final HostCommerceRepository repository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();
    await repository.recordMembershipPurchase(
      membershipDuration: const Duration(days: 365),
    );
    await repository.recordCreditPurchase(500);
    await repository.consumeCredits(100);

    expect(repository.state.permanentCredits, 600);
    expect(repository.state.membershipCredits, 900);

    now = now.add(const Duration(days: 7));
    await repository.refresh();
    expect(repository.state.permanentCredits, 600);
    expect(repository.state.membershipCredits, 1000);
    expect(repository.state.creditBalance, 1600);
  });

  test('only active members can buy host credits', () async {
    final HostCommerceRepository repository = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();

    await expectLater(
      repository.recordCreditPurchase(300),
      throwsA(isA<StateError>()),
    );
    expect(repository.state.creditBalance, 100);
  });

  test('verified credit purchases are idempotent by transaction ID', () async {
    final DateTime now = DateTime.utc(2026, 1, 1);
    final MemoryHostCommerceStore store = MemoryHostCommerceStore(
      HostCommerceState(
        isMember: true,
        membershipExpiresAt: now.add(const Duration(days: 30)),
        membershipCreditPeriodStartedAt: now,
      ),
    );
    final HostCommerceRepository repository = HostCommerceRepository(
      store,
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();

    expect(
      await repository.recordVerifiedCreditPurchase(
        transactionId: 'transaction-1',
        credits: 1000,
      ),
      isTrue,
    );
    expect(
      await repository.recordVerifiedCreditPurchase(
        transactionId: 'transaction-1',
        credits: 1000,
      ),
      isFalse,
    );
    expect(repository.state.permanentCredits, 1100);
    expect(repository.state.processedPurchaseIds, <String>{'transaction-1'});

    final HostCommerceRepository restored = HostCommerceRepository(
      store,
      clock: () => now,
      scheduleBoundaryTimers: false,
    );
    await restored.initialize();
    expect(restored.state.processedPurchaseIds, <String>{'transaction-1'});
  });

  test(
    'the fixed uppercase redemption code adds 2000 permanent credits',
    () async {
      final MemoryHostCommerceStore store = MemoryHostCommerceStore();
      final HostCommerceRepository repository = HostCommerceRepository(
        store,
        scheduleBoundaryTimers: false,
      );
      await repository.initialize();

      expect(await repository.redeemCode('testtesttest'), isFalse);
      expect(repository.state.creditBalance, 100);
      expect(repository.state.hasRedeemedCode, isFalse);
      expect(await repository.redeemCode('TESTTESTTEST'), isTrue);
      expect(repository.state.permanentCredits, 2100);
      expect(repository.state.creditBalance, 2100);
      expect(repository.state.hasRedeemedCode, isTrue);
      expect(await store.isPermanentHostModeEnabled(), isTrue);
    },
  );

  test('clear deletes persisted state and restores new-user credits', () async {
    final MemoryHostCommerceStore store = MemoryHostCommerceStore();
    final HostCommerceRepository repository = HostCommerceRepository(
      store,
      scheduleBoundaryTimers: false,
    );
    await repository.initialize();
    await repository.redeemCode('TESTTESTTEST');

    expect(await store.isPermanentHostModeEnabled(), isTrue);

    await repository.clear();

    expect(repository.state.isMember, isFalse);
    expect(repository.state.creditBalance, 100);
    expect(repository.state.hasRedeemedCode, isFalse);
    expect(await store.isPermanentHostModeEnabled(), isFalse);

    final HostCommerceRepository restored = HostCommerceRepository(
      store,
      scheduleBoundaryTimers: false,
    );
    await restored.initialize();
    expect(restored.state.isMember, isFalse);
    expect(restored.state.creditBalance, 100);
    expect(restored.state.hasRedeemedCode, isFalse);
  });
}
