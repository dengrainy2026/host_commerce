import 'package:flutter/material.dart';

import '../commerce_appearance.dart';

/// Tappable credits balance card shown at the top of the settings screen.
///
/// Tapping it is expected to open the credit store (members) or the paywall
/// (free users); the host app supplies the [onTap] navigation.
final class CreditsStatusCard extends StatelessWidget {
  const CreditsStatusCard({
    required this.isMember,
    required this.balance,
    required this.onTap,
    required this.appearance,
    super.key,
  });

  final bool isMember;
  final int balance;
  final VoidCallback onTap;
  final CommerceAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final CommerceIcons icons = appearance.icons;
    return Semantics(
      button: true,
      label: isMember
          ? '$balance credits. Open credit store.'
          : '$balance credits. View membership plans.',
      child: Material(
        key: const ValueKey<String>('settings-credits-card'),
        color: colors.onSurface,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icons.credits, color: colors.surface, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CREDITS',
                        style: TextStyle(
                          color: colors.surface.withValues(alpha: 0.72),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.85,
                        ),
                      ),
                    ),
                    _StatusPill(label: isMember ? 'PRO' : 'FREE'),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  '$balance',
                  style: TextStyle(
                    color: colors.surface,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isMember
                            ? 'Get more credits'
                            : 'Unlock ${appearance.appProName}',
                        style: TextStyle(
                          color: colors.surface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(icons.forward, color: colors.surface, size: 19),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: colors.surface.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: colors.surface,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
