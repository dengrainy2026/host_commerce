/// Reusable commerce contract layer for Flutter apps.
///
/// Provides membership/credits state ([HostCommerceRepository]), in-app
/// purchase and restore ([HostPurchaseService]), and the paywall screens
/// ([MembershipSubscriptionScreen], [CreditPurchaseScreen]).
///
/// The host app supplies its branding and product catalog through
/// [CommerceAppearance] and [HostProductCatalog]; every store/analytics
/// dependency is injected so the package stays testable.
library;

export 'src/commerce_appearance.dart';
export 'src/commerce_catalog.dart';
export 'src/host_commerce_repository.dart';
export 'src/host_commerce_state.dart';
export 'src/host_commerce_store.dart';
export 'src/host_in_app_purchase_client.dart';
export 'src/host_purchase_service.dart';
export 'src/host_store_product.dart';
export 'src/permanent_host_mode.dart';
export 'src/store_operation_coordinator.dart';
export 'src/ui/commerce_legal_footer.dart';
export 'src/ui/commerce_loading_hud.dart';
export 'src/ui/credit_purchase_screen.dart';
export 'src/ui/credits_status_card.dart';
export 'src/ui/legal_webview_screen.dart';
export 'src/ui/membership_subscription_screen.dart';
export 'src/ui/redeem_code_dialog.dart';
