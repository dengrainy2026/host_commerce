import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commerce_appearance.dart';
import '../commerce_catalog.dart';
import '../host_purchase_service.dart';
import '../host_store_product.dart';
import 'commerce_failure_feedback.dart';
import 'commerce_legal_footer.dart';
import 'commerce_loading_hud.dart';

final class CreditPurchaseScreen extends StatefulWidget {
  const CreditPurchaseScreen({
    required this.catalog,
    required this.appearance,
    required this.balance,
    this.onLoadProducts,
    this.onPurchase,
    super.key,
  }) : assert(balance >= 0);

  final HostProductCatalog catalog;
  final CommerceAppearance appearance;
  final int balance;
  final HostProductLoader? onLoadProducts;
  final Future<int> Function(int)? onPurchase;

  @override
  State<CreditPurchaseScreen> createState() => _CreditPurchaseScreenState();
}

class _CreditPurchaseScreenState extends State<CreditPurchaseScreen> {
  late final List<int> _packages = widget.catalog.availableCreditPackages;
  late int _selectedCredits = _packages.first;
  late int _balance;
  bool _isProcessing = false;
  bool _isLoadingProducts = false;
  Map<String, HostStoreProduct> _products = const <String, HostStoreProduct>{};

  @override
  void initState() {
    super.initState();
    _balance = widget.balance;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final HostProductLoader? loader = widget.onLoadProducts;
    if (loader == null) {
      return;
    }
    setState(() => _isLoadingProducts = true);
    try {
      final Set<String> productIds = <String>{
        for (final HostCreditProduct product in widget.catalog.creditProducts)
          product.productId,
      };
      final Map<String, HostStoreProduct> products = await loader(productIds);
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } on Object catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingProducts = false);
      showCommerceFailure(
        context,
        operation: 'Product loading',
        error: error,
        stackTrace: stackTrace,
      );
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
  void didUpdateWidget(CreditPurchaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _balance = widget.balance;
    }
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
                  'Buy Credits',
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
                    final double sideInset = _sideInset(constraints.maxWidth);
                    return ListView(
                      key: const PageStorageKey<String>('credit-purchase-list'),
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        sideInset,
                        18,
                        sideInset,
                        28,
                      ),
                      children: <Widget>[
                        _BalanceCard(
                          balance: _balance,
                          icons: widget.appearance.icons,
                        ),
                        const SizedBox(height: 26),
                        const _PageLabel(label: 'SELECT A PACK'),
                        const SizedBox(height: 10),
                        for (final int credits in _packages) ...<Widget>[
                          _CreditPackCard(
                            credits: credits,
                            price:
                                _products[widget.catalog.productIdForCredits(
                                      credits,
                                    )]
                                    ?.displayPrice,
                            isLoadingPrice: _isLoadingProducts,
                            selected: credits == _selectedCredits,
                            onTap: () =>
                                setState(() => _selectedCredits = credits),
                            icons: widget.appearance.icons,
                          ),
                          if (credits != _packages.last)
                            const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          key: const ValueKey<String>('credits-continue'),
                          onPressed: _isProcessing ? null : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'Continue with $_selectedCredits credits',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'The store shows the final price before purchase.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: CommerceLegalFooter(appearance: widget.appearance),
                ),
              ),
            ),
            if (_isProcessing)
              const CommerceLoadingHud(message: 'Processing purchase…'),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final Future<int> Function(int)? callback = widget.onPurchase;
    if (callback == null || _isProcessing) {
      if (callback == null) {
        showCommerceFailure(
          context,
          operation: 'Purchase',
          error: StateError('The purchase callback is not configured.'),
        );
      }
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final int updatedBalance = await callback(_selectedCredits);
      if (!mounted) {
        return;
      }
      if (updatedBalance < 0) {
        throw StateError('The updated credit balance is invalid.');
      }
      setState(() {
        _balance = updatedBalance;
        _isProcessing = false;
      });
      return;
    } on HostPurchaseCanceledException {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showPurchaseCancelled();
      return;
    } on Object catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      showCommerceFailure(
        context,
        operation: 'Purchase',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.icons});

  final int balance;
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
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icons.credits, color: colors.surface, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CURRENT BALANCE',
                    style: TextStyle(
                      color: colors.surface.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        color: colors.surface,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '$balance',
              style: TextStyle(
                color: colors.surface,
                fontSize: 36,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'credits available',
              style: TextStyle(
                color: colors.surface.withValues(alpha: 0.72),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  const _CreditPackCard({
    required this.credits,
    required this.price,
    required this.isLoadingPrice,
    required this.selected,
    required this.onTap,
    required this.icons,
  });

  final int credits;
  final String? price;
  final bool isLoadingPrice;
  final bool selected;
  final VoidCallback onTap;
  final CommerceIcons icons;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        icons.credits,
                        color: colors.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      '$credits credits',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    price ?? (isLoadingPrice ? 'Loading…' : 'Unavailable'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: selected ? colors.onSurface : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? colors.onSurface
                            : colors.outlineVariant,
                      ),
                    ),
                    child: selected
                        ? Icon(icons.check, color: colors.surface, size: 15)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.label});

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

double _sideInset(double width) {
  final double base = width < 360 ? 16 : 24;
  final double centered = (width - 560) / 2;
  return base > centered ? base : centered;
}
