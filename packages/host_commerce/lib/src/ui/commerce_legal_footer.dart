import 'package:flutter/material.dart';

import '../commerce_appearance.dart';
import 'legal_webview_screen.dart';

/// Legal links footer shown on the commerce screens.
///
/// Both URLs are mandatory in [CommerceAppearance], so a purchase page can
/// never silently omit either legal action.
final class CommerceLegalFooter extends StatelessWidget {
  const CommerceLegalFooter({required this.appearance, super.key});

  final CommerceAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final String privacyUrl = _requireHttpsUrl(
      appearance.privacyPolicyUrl,
      label: 'privacy policy',
    );
    final String termsUrl = _requireHttpsUrl(
      appearance.termsOfUseUrl,
      label: 'terms of use',
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: <Widget>[
        TextButton(
          key: const ValueKey<String>('commerce-privacy-policy'),
          onPressed: () =>
              _openLegalPage(context, title: 'Privacy Policy', url: privacyUrl),
          child: const Text('Privacy Policy'),
        ),
        Text(
          '·',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          key: const ValueKey<String>('commerce-terms-of-use'),
          onPressed: () =>
              _openLegalPage(context, title: 'Terms of Use', url: termsUrl),
          child: const Text('Terms of Use'),
        ),
      ],
    );
  }

  String _requireHttpsUrl(String value, {required String label}) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(value, label, 'must be a non-empty HTTPS URL');
    }
    return value;
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
