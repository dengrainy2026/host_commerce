import 'dart:async';

import 'package:flutter/material.dart';
import 'package:host_commerce/host_commerce.dart';

import 'settings_screen.dart';

/// Host-only home screen.
///
/// Demonstrates the credit gate: the placeholder tool consumes 100 credits
/// per run and routes to the paywall (free users) or credit store (members)
/// when the balance runs out. A new app replaces the placeholder tool with its
/// own tools and keeps this gate around each creation.
final class HomeScreen extends StatefulWidget {
  const HomeScreen({
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.commerceRepository.addListener(_onCommerceChanged);
  }

  @override
  void dispose() {
    widget.commerceRepository.removeListener(_onCommerceChanged);
    super.dispose();
  }

  void _onCommerceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runTool() async {
    // 在这里接入你的工具:每次生成前调用积分扣费门。
    final HostCommerceRepository repository = widget.commerceRepository;
    await repository.refresh();
    if (!mounted) {
      return;
    }
    final HostCommerceState state = repository.state;
    if (state.creditBalance < HostCommerceRepository.creationCost) {
      await _openCommerceEntry();
      return;
    }
    final bool consumed = await repository.consumeCredits(
      HostCommerceRepository.creationCost,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            consumed
                ? 'Tool ran — ${HostCommerceRepository.creationCost} credits used.'
                : 'Not enough credits.',
          ),
        ),
      );
  }

  Future<void> _openCommerceEntry() async {
    final HostCommerceRepository repository = widget.commerceRepository;
    await repository.refresh();
    if (!mounted) {
      return;
    }
    final HostCommerceState state = repository.state;
    if (state.isMember) {
      await _pushCreditsScreen();
    } else {
      await _pushSubscriptionScreen();
    }
  }

  Future<void> _pushCreditsScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CreditPurchaseScreen(
          catalog: widget.catalog,
          appearance: widget.appearance,
          balance: widget.commerceRepository.state.creditBalance,
          onLoadProducts: widget.purchaseService.loadProducts,
          onPurchase: _purchaseCredits,
        ),
      ),
    );
  }

  Future<void> _pushSubscriptionScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MembershipSubscriptionScreen(
          catalog: widget.catalog,
          appearance: widget.appearance,
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

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SettingsScreen(
          commerceRepository: widget.commerceRepository,
          purchaseService: widget.purchaseService,
          appearance: widget.appearance,
          catalog: widget.catalog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final HostCommerceState state = widget.commerceRepository.state;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          widget.appearance.appDisplayName,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('home-settings'),
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: Icon(Icons.settings_outlined, color: colors.onSurface),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const PageStorageKey<String>('home-list'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: <Widget>[
            _BalanceCard(
              isMember: state.isMember,
              balance: state.creditBalance,
              appearance: widget.appearance,
              onTap: () => unawaited(_openCommerceEntry()),
            ),
            const SizedBox(height: 24),
            Text(
              'YOUR TOOL',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.75,
              ),
            ),
            const SizedBox(height: 10),
            _ToolCard(
              icon: Icons.auto_fix_high,
              title: 'Sample tool',
              subtitle: 'Each creation uses '
                  '${HostCommerceRepository.creationCost} credits.',
              onTap: () => unawaited(_runTool()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.isMember,
    required this.balance,
    required this.appearance,
    required this.onTap,
  });

  final bool isMember;
  final int balance;
  final CommerceAppearance appearance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isMember
          ? '$balance credits. Open credit store.'
          : '$balance credits. View membership plans.',
      child: Material(
        key: const ValueKey<String>('home-credits-card'),
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(20),
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
                    Icon(
                      appearance.icons.credits,
                      color: colors.surface,
                      size: 18,
                    ),
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
                    Icon(appearance.icons.forward, color: colors.surface, size: 19),
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

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey<String>('run-tool'),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox.square(
                    dimension: 42,
                    child: Icon(icon, color: colors.onSurface, size: 20),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
