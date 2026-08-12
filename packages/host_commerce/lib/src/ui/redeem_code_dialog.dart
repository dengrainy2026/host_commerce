import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commerce_appearance.dart';

/// Dialog that collects a redemption code and pops it back to the caller.
///
/// Pops with the entered code string, or null when dismissed.
final class RedeemCodeDialog extends StatefulWidget {
  const RedeemCodeDialog({required this.appearance, super.key});

  final CommerceAppearance appearance;

  @override
  State<RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<RedeemCodeDialog> {
  static const int _codeLength = 12;

  final TextEditingController _controller = TextEditingController();
  String _code = '';

  bool get _canRedeem => _code.length == _codeLength;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final CommerceIcons icons = widget.appearance.icons;
    return Dialog(
      key: const ValueKey<String>('host-redeem-code-dialog'),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.onSurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        icons.redeem,
                        color: colors.surface,
                        size: 21,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey<String>('host-redeem-code-close'),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainer,
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Redeem Code',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Enter your code to add credits to this device.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey<String>('host-redeem-code-input'),
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'ENTER CODE',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                  prefixIcon: Icon(icons.key, size: 19),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: colors.onSurface, width: 1.4),
                  ),
                ),
                onChanged: (String value) => setState(() => _code = value),
                onSubmitted: (_) {
                  if (_canRedeem) {
                    Navigator.of(context).pop(_code);
                  }
                },
              ),
              const SizedBox(height: 9),
              Row(
                children: <Widget>[
                  Icon(icons.about, color: colors.onSurfaceVariant, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Codes are 12 characters and case-sensitive.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('host-redeem-code-submit'),
                      onPressed: _canRedeem
                          ? () => Navigator.of(context).pop(_code)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: colors.onSurface,
                        foregroundColor: colors.surface,
                        disabledBackgroundColor: colors.surfaceContainerHighest,
                        disabledForegroundColor: colors.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Redeem',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
