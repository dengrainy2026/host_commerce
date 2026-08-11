/// The persisted membership/credits entitlement state.
final class HostCommerceState {
  const HostCommerceState({
    this.isMember = false,
    this.permanentCredits = 100,
    this.membershipCredits = 0,
    this.membershipExpiresAt,
    this.membershipCreditPeriodStartedAt,
    this.hasRedeemedCode = false,
  }) : assert(permanentCredits >= 0),
       assert(membershipCredits >= 0);

  final bool isMember;

  /// Credits granted to a new user, bought, or redeemed by code.
  final int permanentCredits;

  /// The current non-accumulating weekly member allowance.
  final int membershipCredits;

  final DateTime? membershipExpiresAt;
  final DateTime? membershipCreditPeriodStartedAt;

  /// Once set, startup always selects the native host until commerce data is
  /// explicitly cleared from the settings screen.
  final bool hasRedeemedCode;

  int get creditBalance => permanentCredits + membershipCredits;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': 3,
    'is_member': isMember,
    'permanent_credits': permanentCredits,
    'membership_credits': membershipCredits,
    'membership_expires_at': membershipExpiresAt?.millisecondsSinceEpoch,
    'membership_credit_period_started_at':
        membershipCreditPeriodStartedAt?.millisecondsSinceEpoch,
    'has_redeemed_code': hasRedeemedCode,
  };

  static HostCommerceState fromJson(Map<String, Object?> json) {
    if (!json.containsKey('permanent_credits')) {
      return _fromLegacyJson(json);
    }
    final Object? isMember = json['is_member'];
    final Object? permanentCredits = json['permanent_credits'];
    final Object? membershipCredits = json['membership_credits'];
    final Object? hasRedeemedCode = json['has_redeemed_code'];
    if (isMember is! bool ||
        permanentCredits is! int ||
        permanentCredits < 0 ||
        membershipCredits is! int ||
        membershipCredits < 0 ||
        hasRedeemedCode != null && hasRedeemedCode is! bool) {
      throw const FormatException('Invalid host commerce state.');
    }
    return HostCommerceState(
      isMember: isMember,
      permanentCredits: permanentCredits,
      membershipCredits: membershipCredits,
      membershipExpiresAt: _dateTimeFromJson(json['membership_expires_at']),
      membershipCreditPeriodStartedAt: _dateTimeFromJson(
        json['membership_credit_period_started_at'],
      ),
      hasRedeemedCode: hasRedeemedCode as bool? ?? false,
    );
  }

  static HostCommerceState _fromLegacyJson(Map<String, Object?> json) {
    final Object? isMember = json['is_member'];
    final Object? creditBalance = json['credit_balance'];
    if (isMember is! bool || creditBalance is! int || creditBalance < 0) {
      throw const FormatException('Invalid legacy host commerce state.');
    }
    return HostCommerceState(isMember: isMember, permanentCredits: creditBalance);
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! int) {
      throw const FormatException('Invalid host commerce timestamp.');
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
}
