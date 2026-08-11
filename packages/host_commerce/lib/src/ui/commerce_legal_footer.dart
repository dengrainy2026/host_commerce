import 'package:flutter/material.dart';

import '../commerce_appearance.dart';
import 'legal_webview_screen.dart';

/// Legal links footer shown on the commerce screens.
///
/// URLs come from [CommerceAppearance]; each link is hidden when its URL is
/// null, and the whole footer collapses to nothing when both are null.
final class CommerceLegalFooter extends StatelessWidget {
  const CommerceLegalFooter({required this.appearance, super.key});

  final CommerceAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final String? privacyUrl = appearance.privacyPolicyUrl;
    final String? termsUrl = appearance.termsOfUseUrl;
    final List<Widget> children = <Widget>[
      if (privacyUrl != null)
        TextButton(
          key: const ValueKey<String>('commerce-privacy-policy'),
          onPressed: () => _openLegalPage(
            context,
            title: 'Privacy Policy',
            url: privacyUrl,
          ),
          child: const Text('Privacy Policy'),
        ),
      if (privacyUrl != null && termsUrl != null)
        Text(
          '·',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      if (termsUrl != null)
        TextButton(
          key: const ValueKey<String>('commerce-terms-of-use'),
          onPressed: () => _openLegalPage(
            context,
            title: 'Terms of Use',
            url: termsUrl,
          ),
          child: const Text('Terms of Use'),
        ),
    ];
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: children,
    );
  }

  void _openLegalPage(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LegalWebViewScreen(
          title: title,
          url: url,
          systemUiStyle: appearance.systemUiStyle,
        ),
      ),
    );
  }
}
