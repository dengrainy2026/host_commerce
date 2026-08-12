import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:host_commerce/host_commerce.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Minimal settings screen reusing the package's commerce components:
/// [CreditsStatusCard], [RedeemCodeDialog], and [CommerceLegalFooter].
///
/// Render/interaction settings that are tool-specific stay out of the shared
/// package; a new app adds its own settings sections here.
final class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.commerceRepository,
    required this.purchaseService,
    required this.appearance,
    required this.catalog,
    super.key,
  });

  final HostCommerceRepository commerceRepository;
  final HostPurchaseService purchaseService;
  final CommerceAppearance appearance;
  final HostProductCatalog catalog;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo?> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = _loadPackageInfo();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.commerceRepository,
          builder: (BuildContext context, Widget? child) {
            final HostCommerceState state = widget.commerceRepository.state;
            return ListView(
              key: const PageStorageKey<String>('settings-list'),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
              children: <Widget>[
                CreditsStatusCard(
                  isMember: state.isMember,
                  balance: state.creditBalance,
                  appearance: widget.appearance,
                  onTap: () => unawaited(_openCommerceEntry()),
                ),
                const SizedBox(height: 26),
                const _SectionLabel(label: 'REDEMPTION'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: <Widget>[
                    _NavigationTile(
                      icon: widget.appearance.icons.redeem,
                      title: 'Redeem Code',
                      onTap: () => unawaited(_showRedeemCodeDialog()),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionLabel(label: 'ABOUT'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: <Widget>[
                    _NavigationTile(
                      icon: widget.appearance.icons.about,
                      title: 'Legal',
                      onTap: null,
                      trailing: const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                CommerceLegalFooter(appearance: widget.appearance),
                if (kDebugMode) ...<Widget>[
                  const SizedBox(height: 26),
                  const _SectionLabel(label: 'DEVELOPMENT'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: <Widget>[
                      _NavigationTile(
                        icon: Icons.delete_outline,
                        title: 'Clear Membership & Credits',
                        onTap: () => unawaited(_confirmClearCommerceData()),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                FutureBuilder<PackageInfo?>(
                  future: _packageInfo,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<PackageInfo?> snapshot,
                  ) {
                    final PackageInfo? info = snapshot.data;
                    return Center(
                      child: Text(
                        'Version ${info == null ? '—' : '${info.version}(${info.buildNumber})'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
  }

  Future<void> _openCommerceEntry() async {
    await widget.commerceRepository.refresh();
    if (!mounted) {
      return;
    }
    final HostCommerceState state = widget.commerceRepository.state;
    if (state.isMember) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => CreditPurchaseScreen(
            catalog: widget.catalog,
            appearance: widget.appearance,
            balance: state.creditBalance,
            onLoadProducts: widget.purchaseService.loadProducts,
            onPurchase: _purchaseCredits,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MembershipSubscriptionScreen(
          catalog: widget.catalog,
          appearance: widget.appearance,
          rules: widget.commerceRepository.rules,
          onLoadProducts: widget.purchaseService.loadProducts,
          onSubscribe: _purchaseSubscription,
          onRestorePurchases: widget.purchaseService.restorePurchases,
        ),
      ),
    );
  }

  Future<void> _purchaseSubscription(MembershipPlan plan) async {
    await widget.purchaseService.purchaseSubscription(
      widget.catalog.subscriptionIdFor(plan),
    );
  }

  Future<int> _purchaseCredits(int credits) async {
    await widget.purchaseService.purchaseCredits(
      widget.catalog.productIdForCredits(credits),
    );
    return widget.purchaseService.commerceState.creditBalance;
  }

  Future<void> _showRedeemCodeDialog() async {
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          RedeemCodeDialog(appearance: widget.appearance),
    );
    if (code == null || !mounted) {
      return;
    }
    final bool redeemed = await widget.commerceRepository.redeemCode(code);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            redeemed
                ? '${widget.commerceRepository.rules.redemptionCredits} credits were added.'
                : 'The redemption code is invalid.',
          ),
        ),
      );
  }

  Future<void> _confirmClearCommerceData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clear membership & credits?'),
        content: const Text(
          'This permanently deletes the membership status and credit balance '
          'on this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.commerceRepository.clear();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Membership and credits were cleared.'),
        ),
      );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: colors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.75,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, color: colors.onSurface, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
