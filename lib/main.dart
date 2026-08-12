import 'package:flutter/material.dart';
import 'package:host_commerce/host_commerce.dart';

import 'app_config.dart';
import 'home_screen.dart';

/// Thin template shell: wires the commerce stack and shows [HomeScreen].
///
/// There is no startup role split and no H5 bridge — this app is host-only.
/// A new app replaces the placeholder tool on [HomeScreen] with its own tools.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeHostCommerceStoreKit();

  final HostProductCatalog catalog = kAppConfig.currentCatalog;
  final HostCommerceRepository commerceRepository = HostCommerceRepository(
    SecureHostCommerceStore(),
    rules: kAppConfig.commerceRules,
  );
  await commerceRepository.initialize();
  final HostPurchaseService purchaseService = HostPurchaseService(
    commerceRepository,
    catalog: catalog,
    verifier: _buildPurchaseVerifier(),
  )..initialize();

  runApp(
    VeditorCommerceApp(
      config: kAppConfig,
      commerceRepository: commerceRepository,
      purchaseService: purchaseService,
      catalog: catalog,
    ),
  );
}

HostPurchaseVerifier _buildPurchaseVerifier() {
  const String verificationUrl = String.fromEnvironment(
    'NATIVE_PURCHASE_VERIFICATION_URL',
  );
  final Uri? endpoint = Uri.tryParse(verificationUrl);
  if (endpoint == null || endpoint.scheme != 'https' || endpoint.host.isEmpty) {
    return const RejectingHostPurchaseVerifier();
  }
  return HttpHostPurchaseVerifier(endpoint);
}

final class VeditorCommerceApp extends StatelessWidget {
  const VeditorCommerceApp({
    required this.config,
    required this.commerceRepository,
    required this.purchaseService,
    required this.catalog,
    super.key,
  });

  final AppConfig config;
  final HostCommerceRepository commerceRepository;
  final HostPurchaseService purchaseService;
  final HostProductCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appearance.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: config.themeSeedColor),
        useMaterial3: true,
      ),
      home: HomeScreen(
        commerceRepository: commerceRepository,
        purchaseService: purchaseService,
        appearance: config.appearance,
        catalog: catalog,
        tool: config.tool,
      ),
    );
  }
}
