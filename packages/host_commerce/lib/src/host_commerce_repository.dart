import 'dart:async';

import 'package:flutter/foundation.dart';

import 'commerce_rules.dart';
import 'host_commerce_state.dart';
import 'host_commerce_store.dart';

typedef HostCommerceClock = DateTime Function();

/// Owns the membership/credits entitlement state.
///
/// Handles the periodic member allowance rollover, membership expiry, credit
/// consumption, and code redemption. Writes are funneled through a
/// [HostCommerceStore]; a [HostCommerceClock] makes time-dependent behavior
/// deterministic in tests.
final class HostCommerceRepository extends ChangeNotifier {
  HostCommerceRepository(
    this._store, {
    this.rules = const CommerceRules(),
    HostCommerceClock? clock,
    this.scheduleBoundaryTimers = true,
  }) : _clock = clock ?? DateTime.now {
    if (rules.membershipCreditPeriod <= Duration.zero) {
      throw ArgumentError.value(
        rules.membershipCreditPeriod,
        'rules.membershipCreditPeriod',
        'Must be positive.',
      );
    }
  }

  static const String testRedemptionCode = 'TESTTESTTEST';

  final HostCommerceStore _store;
  final CommerceRules rules;
  final HostCommerceClock _clock;
  final bool scheduleBoundaryTimers;
  HostCommerceState _state = const HostCommerceState();
  bool _initialized = false;
  Timer? _boundaryTimer;

  HostCommerceState get state => _state;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final HostCommerceState stored = await _store.read(
      fallback: _newUserState(),
    );
    _state = _normalize(stored, _now());
    _initialized = true;
    if (!_sameState(stored, _state)) {
      await _store.write(_state);
    }
    _scheduleNextBoundary();
    notifyListeners();
  }

  Future<void> refresh() async {
    final HostCommerceState normalized = _normalize(_state, _now());
    if (_sameState(normalized, _state)) {
      _scheduleNextBoundary();
      return;
    }
    await _persist(normalized);
  }

  Future<void> recordMembershipPurchase({
    Duration membershipDuration = const Duration(days: 7),
  }) async {
    if (membershipDuration <= Duration.zero) {
      throw ArgumentError.value(
        membershipDuration,
        'membershipDuration',
        'Must be positive.',
      );
    }
    await refresh();
    final DateTime now = _now();
    final DateTime candidateExpiration = now.add(membershipDuration);
    final DateTime expiration =
        _state.isMember &&
            _state.membershipExpiresAt != null &&
            _state.membershipExpiresAt!.isAfter(candidateExpiration)
        ? _state.membershipExpiresAt!
        : candidateExpiration;
    await _persist(
      HostCommerceState(
        isMember: true,
        permanentCredits: _state.permanentCredits,
        membershipCredits: rules.memberCreditsPerPeriod,
        membershipExpiresAt: expiration,
        membershipCreditPeriodStartedAt: now,
        hasRedeemedCode: _state.hasRedeemedCode,
        processedPurchaseIds: _state.processedPurchaseIds,
      ),
    );
  }

  Future<void> recordCreditPurchase(int credits) async {
    if (credits <= 0) {
      throw ArgumentError.value(credits, 'credits', 'Must be positive.');
    }
    await refresh();
    if (!_state.isMember) {
      throw StateError('Only active members can buy credits.');
    }
    await _persist(
      _copyState(_state, permanentCredits: _state.permanentCredits + credits),
    );
  }

  /// Applies a backend-verified subscription exactly once per transaction.
  Future<bool> recordVerifiedMembershipPurchase({
    required String transactionId,
    required DateTime membershipExpiresAt,
  }) async {
    final String normalizedId = transactionId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        transactionId,
        'transactionId',
        'Must not be empty.',
      );
    }
    await refresh();
    if (_state.processedPurchaseIds.contains(normalizedId)) {
      return false;
    }
    final DateTime expiration = membershipExpiresAt.toUtc();
    final DateTime now = _now();
    if (!expiration.isAfter(now)) {
      throw StateError('Verified membership entitlement is not active.');
    }
    await _persist(
      HostCommerceState(
        isMember: true,
        permanentCredits: _state.permanentCredits,
        membershipCredits: rules.memberCreditsPerPeriod,
        membershipExpiresAt: expiration,
        membershipCreditPeriodStartedAt: now,
        hasRedeemedCode: _state.hasRedeemedCode,
        processedPurchaseIds: <String>{
          ..._state.processedPurchaseIds,
          normalizedId,
        },
      ),
    );
    return true;
  }

  /// Applies a backend-verified consumable exactly once per transaction.
  Future<bool> recordVerifiedCreditPurchase({
    required String transactionId,
    required int credits,
  }) async {
    final String normalizedId = transactionId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        transactionId,
        'transactionId',
        'Must not be empty.',
      );
    }
    if (credits <= 0) {
      throw ArgumentError.value(credits, 'credits', 'Must be positive.');
    }
    await refresh();
    if (!_state.isMember) {
      throw StateError('Only active members can buy credits.');
    }
    if (_state.processedPurchaseIds.contains(normalizedId)) {
      return false;
    }
    await _persist(
      _copyState(
        _state,
        permanentCredits: _state.permanentCredits + credits,
        processedPurchaseIds: <String>{
          ..._state.processedPurchaseIds,
          normalizedId,
        },
      ),
    );
    return true;
  }

  Future<bool> redeemCode(String code) async {
    if (code.trim() != testRedemptionCode) {
      return false;
    }
    await refresh();
    await _persist(
      _copyState(
        _state,
        permanentCredits: _state.permanentCredits + rules.redemptionCredits,
        hasRedeemedCode: true,
      ),
    );
    return true;
  }

  Future<bool> consumeCredits(int credits) async {
    if (credits <= 0) {
      throw ArgumentError.value(credits, 'credits', 'Must be positive.');
    }
    await refresh();
    if (_state.creditBalance < credits) {
      return false;
    }
    final int memberCreditsUsed = credits < _state.membershipCredits
        ? credits
        : _state.membershipCredits;
    final int permanentCreditsUsed = credits - memberCreditsUsed;
    await _persist(
      _copyState(
        _state,
        membershipCredits: _state.membershipCredits - memberCreditsUsed,
        permanentCredits: _state.permanentCredits - permanentCreditsUsed,
      ),
    );
    return true;
  }

  Future<void> clear() async {
    await _store.clear();
    _state = _newUserState();
    _scheduleNextBoundary();
    notifyListeners();
  }

  HostCommerceState _normalize(HostCommerceState state, DateTime now) {
    if (!state.isMember) {
      return HostCommerceState(
        permanentCredits: state.permanentCredits,
        hasRedeemedCode: state.hasRedeemedCode,
        processedPurchaseIds: state.processedPurchaseIds,
      );
    }

    DateTime? expiration = state.membershipExpiresAt?.toUtc();
    DateTime? periodStarted = state.membershipCreditPeriodStartedAt?.toUtc();
    int membershipCredits = state.membershipCredits;

    // Migrate the previous host-only membership flag into one local period.
    if (expiration == null || periodStarted == null) {
      expiration = now.add(rules.membershipCreditPeriod);
      periodStarted = now;
      membershipCredits = rules.memberCreditsPerPeriod;
    }
    if (!expiration.isAfter(now)) {
      return HostCommerceState(
        permanentCredits: state.permanentCredits,
        hasRedeemedCode: state.hasRedeemedCode,
        processedPurchaseIds: state.processedPurchaseIds,
      );
    }
    if (periodStarted.isAfter(now)) {
      periodStarted = now;
      membershipCredits = rules.memberCreditsPerPeriod;
    }
    final int elapsedPeriods =
        now.difference(periodStarted).inMilliseconds ~/
        rules.membershipCreditPeriod.inMilliseconds;
    if (elapsedPeriods > 0) {
      periodStarted = periodStarted.add(
        Duration(
          milliseconds:
              rules.membershipCreditPeriod.inMilliseconds * elapsedPeriods,
        ),
      );
      membershipCredits = rules.memberCreditsPerPeriod;
    }
    return HostCommerceState(
      isMember: true,
      permanentCredits: state.permanentCredits,
      membershipCredits: membershipCredits,
      membershipExpiresAt: expiration,
      membershipCreditPeriodStartedAt: periodStarted,
      hasRedeemedCode: state.hasRedeemedCode,
      processedPurchaseIds: state.processedPurchaseIds,
    );
  }

  Future<void> _persist(HostCommerceState nextState) async {
    await _store.write(nextState);
    _state = nextState;
    _scheduleNextBoundary();
    notifyListeners();
  }

  void _scheduleNextBoundary() {
    _boundaryTimer?.cancel();
    if (!scheduleBoundaryTimers || !_state.isMember) {
      return;
    }
    final DateTime? expiration = _state.membershipExpiresAt;
    final DateTime? periodStarted = _state.membershipCreditPeriodStartedAt;
    if (expiration == null || periodStarted == null) {
      return;
    }
    final DateTime nextCreditBoundary = periodStarted.add(
      rules.membershipCreditPeriod,
    );
    final DateTime nextBoundary = expiration.isBefore(nextCreditBoundary)
        ? expiration
        : nextCreditBoundary;
    final Duration delay = nextBoundary.difference(_now());
    _boundaryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(refresh());
    });
  }

  DateTime _now() => _clock().toUtc();

  HostCommerceState _newUserState() =>
      HostCommerceState(permanentCredits: rules.initialCredits);

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }
}

HostCommerceState _copyState(
  HostCommerceState state, {
  int? permanentCredits,
  int? membershipCredits,
  bool? hasRedeemedCode,
  Set<String>? processedPurchaseIds,
}) => HostCommerceState(
  isMember: state.isMember,
  permanentCredits: permanentCredits ?? state.permanentCredits,
  membershipCredits: membershipCredits ?? state.membershipCredits,
  membershipExpiresAt: state.membershipExpiresAt,
  membershipCreditPeriodStartedAt: state.membershipCreditPeriodStartedAt,
  hasRedeemedCode: hasRedeemedCode ?? state.hasRedeemedCode,
  processedPurchaseIds: processedPurchaseIds ?? state.processedPurchaseIds,
);

bool _sameState(HostCommerceState first, HostCommerceState second) =>
    first.isMember == second.isMember &&
    first.permanentCredits == second.permanentCredits &&
    first.membershipCredits == second.membershipCredits &&
    first.membershipExpiresAt == second.membershipExpiresAt &&
    first.membershipCreditPeriodStartedAt ==
        second.membershipCreditPeriodStartedAt &&
    first.hasRedeemedCode == second.hasRedeemedCode &&
    setEquals(first.processedPurchaseIds, second.processedPurchaseIds);
