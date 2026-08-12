/// App-supplied rules for credits and membership allowances.
///
/// Keeping these values together lets each host app reuse the commerce package
/// with its own economy while preserving the original defaults.
final class CommerceRules {
  const CommerceRules({
    this.initialCredits = 100,
    this.creationCost = 100,
    this.memberCreditsPerPeriod = 1000,
    this.redemptionCredits = 2000,
    this.membershipCreditPeriod = const Duration(days: 7),
  }) : assert(initialCredits >= 0),
       assert(creationCost > 0),
       assert(memberCreditsPerPeriod >= 0),
       assert(redemptionCredits >= 0);

  /// Permanent credits granted when commerce state is first created.
  final int initialCredits;

  /// Default cost used by the host's creation gate and commerce UI.
  final int creationCost;

  /// Non-accumulating credits refreshed at each membership period boundary.
  final int memberCreditsPerPeriod;

  /// Permanent credits granted by the package's redemption flow.
  final int redemptionCredits;

  /// Length of the recurring member-credit allowance period.
  final Duration membershipCreditPeriod;
}
