import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commerce_appearance.dart';
import '../commerce_catalog.dart';
import '../host_purchase_service.dart';
import '../host_store_product.dart';
import 'commerce_legal_footer.dart';
import 'commerce_loading_hud.dart';

final class MembershipSubscriptionScreen extends StatefulWidget {
  const MembershipSubscriptionScreen({
    required this.catalog,
    required this.appearance,
    this.onLoadProducts,
    this.onSubscribe,
    this.onRestorePurchases,
    super.key,
  });

  final HostProductCatalog catalog;
  final CommerceAppearance appearance;
  final HostProductLoader? onLoadProducts;
  final Future<void> Function(MembershipPlan)? onSubscribe;
  final Future<void> Function()? onRestorePurchases;

  @override
  State<MembershipSubscriptionScreen> createState() =>
      _MembershipSubscriptionScreenState();
}

class _MembershipSubscriptionScreenState
    extends State<MembershipSubscriptionScreen> {
  MembershipPlan _selectedPlan = MembershipPlan.annual;
  bool _isProcessing = false;
  bool _isLoadingProducts = false;
  Map<String, HostStoreProduct> _products = const <String, HostStoreProduct>{};
  String _processingMessage = 'Processing purchase…';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final HostProductLoader? loader = widget.onLoadProducts;
    if (loader == null) {
      return;
    }
    setState(() => _isLoadingProducts = true);
    try {
      final Map<String, HostStoreProduct> products = await loader(
        widget.catalog.allSubscriptionIds,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingProducts = false);
    }
  }

  void _showPurchaseCancelled() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Purchase cancelled.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.appearance.systemUiStyle,
      child: PopScope<void>(
        canPop: !_isProcessing,
        child: Stack(
          children: <Widget>[
            Scaffold(
              backgroundColor: colors.surface,
              appBar: AppBar(
                backgroundColor: colors.surface,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                title: Text(
                  widget.appearance.appProName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double sideInset = _commerceSideInset(
                      constraints.maxWidth,
                    );
                    return ListView(
                      key: const PageStorageKey<String>('subscription-list'),
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        sideInset,
                        18,
                        sideInset,
                        28,
                      ),
                      children: <Widget>[
                        _SubscriptionHero(icons: widget.appearance.icons),
                        const SizedBox(height: 26),
                        const _CommerceLabel(label: 'MEMBER BENEFITS'),
                        const SizedBox(height: 10),
                        _BenefitsCard(icons: widget.appearance.icons),
                        const SizedBox(height: 26),
                        const _CommerceLabel(label: 'CHOOSE A PLAN'),
                        const SizedBox(height: 10),
                        for (final MembershipPlan plan
                            in MembershipPlan.values) ...<Widget>[
                          _PlanCard(
                            icons: widget.appearance.icons,
                            plan: plan,
                            price: _priceFor(plan),
                            isLoadingPrice: _isLoadingProducts,
                            selected: plan == _selectedPlan,
                            onTap: () => setState(() => _selectedPlan = plan),
                          ),
                          if (plan != MembershipPlan.values.last)
                            const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          key: const ValueKey<String>('subscribe-continue'),
                          onPressed: _isProcessing ? null : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isProcessing ? null : _restore,
                          child: const Text('Restore'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Price and renewal terms are shown before checkout.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CommerceLegalFooter(appearance: widget.appearance),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_isProcessing) CommerceLoadingHud(message: _processingMessage),
          ],
        ),
      ),
    );
  }

  String? _priceFor(MembershipPlan plan) {
    final String productId = widget.catalog.subscriptionIdFor(plan);
    return _products[productId]?.displayPrice;
  }

  Future<void> _continue() async {
    final Future<void> Function(MembershipPlan)? callback = widget.onSubscribe;
    if (callback == null || _isProcessing) {
      _showCheckoutUnavailable();
      return;
    }
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Processing purchase…';
    });
    try {
      await callback(_selectedPlan);
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${widget.appearance.appProName} activated successfully.',
            ),
          ),
        );
    } on HostPurchaseCanceledException {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showPurchaseCancelled();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showCheckoutUnavailable();
    }
  }

  Future<void> _restore() async {
    final Future<void> Function()? callback = widget.onRestorePurchases;
    if (callback == null || _isProcessing) {
      _showCheckoutUnavailable();
      return;
    }
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Restoring purchases…';
    });
    try {
      await callback();
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Purchases restored successfully.'),
          ),
        );
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showCheckoutUnavailable();
    }
  }

  void _showCheckoutUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Checkout is not connected yet.'),
        ),
      );
  }
}

class _SubscriptionHero extends StatelessWidget {
  const _SubscriptionHero({required this.icons});

  final CommerceIcons icons;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icons.sparkle, color: colors.surface, size: 22),
            const SizedBox(height: 26),
            Text(
              'Create more with Pro.',
              style: TextStyle(
                color: colors.surface,
                fontSize: 25,
                height: 1.12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1,000 credits every week and member access.',
              style: TextStyle(
                color: colors.surface.withValues(alpha: 0.72),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({required this.icons});

  final CommerceIcons icons;

  @override
  Widget build(BuildContext context) {
    return _CommerceCard(
      children: <Widget>[
        _BenefitRow(icons: icons, icon: icons.credits, label: '1,000 credits every week'),
        const _CommerceDivider(),
        _BenefitRow(icons: icons, icon: icons.add, label: 'Buy extra credits'),
        const _CommerceDivider(),
        _BenefitRow(
          icons: icons,
          icon: icons.premium,
          label: 'Each creation uses 100 credits',
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icons,
    required this.icon,
    required this.label,
  });

  final CommerceIcons icons;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(icon, color: colors.onSurface, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(icons.check, color: colors.onSurface, size: 19),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.icons,
    required this.plan,
    required this.price,
    required this.isLoadingPrice,
    required this.selected,
    required this.onTap,
  });

  final CommerceIcons icons;
  final MembershipPlan plan;
  final String? price;
  final bool isLoadingPrice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = plan == MembershipPlan.annual ? 'Annual' : 'Weekly';
    final String caption = plan == MembershipPlan.annual
        ? 'Best value · billed yearly'
        : 'Flexible · billed weekly';
    final BorderRadius radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? colors.surfaceContainerLow
              : colors.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.onSurface : colors.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
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
                          caption,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    price ?? (isLoadingPrice ? 'Loading…' : 'Unavailable'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SelectionMark(icons: icons, selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.icons, required this.selected});

  final CommerceIcons icons;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        color: selected ? colors.onSurface : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.onSurface : colors.outlineVariant,
        ),
      ),
      child: selected ? Icon(icons.check, color: colors.surface, size: 15) : null,
    );
  }
}

class _CommerceCard extends StatelessWidget {
  const _CommerceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _CommerceDivider extends StatelessWidget {
  const _CommerceDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 50,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _CommerceLabel extends StatelessWidget {
  const _CommerceLabel({required this.label});

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

double _commerceSideInset(double width) {
  final double base = width < 360 ? 16 : 24;
  final double centered = (width - 560) / 2;
  return base > centered ? base : centered;
}
