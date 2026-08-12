import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Icon tokens used by the shared paywall and commerce settings UI.
///
/// Defaults to Material icons so the package has no icon-font dependency;
/// the host app overrides them with its own brand icons.
final class CommerceIcons {
  const CommerceIcons({
    this.sparkle = Icons.auto_awesome,
    this.credits = Icons.paid_outlined,
    this.add = Icons.add_circle_outline,
    this.premium = Icons.workspace_premium_outlined,
    this.check = Icons.check,
    this.redeem = Icons.redeem_outlined,
    this.close = Icons.close,
    this.key = Icons.key_outlined,
    this.about = Icons.info_outline,
    this.forward = Icons.chevron_right,
  });

  final IconData sparkle;
  final IconData credits;
  final IconData add;
  final IconData premium;
  final IconData check;
  final IconData redeem;
  final IconData close;
  final IconData key;
  final IconData about;
  final IconData forward;
}

/// Branding supplied by the host app for the shared commerce UI.
final class CommerceAppearance {
  const CommerceAppearance({
    required this.appDisplayName,
    required this.privacyPolicyUrl,
    required this.termsOfUseUrl,
    this.icons = const CommerceIcons(),
    this.systemUiStyle = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  });

  final String appDisplayName;

  /// HTTPS privacy-policy URL shown on every commerce screen.
  final String privacyPolicyUrl;

  /// HTTPS terms-of-use URL shown on every commerce screen.
  final String termsOfUseUrl;

  final CommerceIcons icons;
  final SystemUiOverlayStyle systemUiStyle;

  String get appProName => '$appDisplayName Pro';
}
