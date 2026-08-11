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

  final HostCommerceRepository commerceRepository = HostCommerceRepository(
    SecureHostCommerceStore(),
  );
  await commerceRepository.initialize();
  final HostPurchaseService purchaseService = HostPurchaseService(
    commerceRepository,
    catalog: buildCatalog(),
  )..initialize();

  runApp(
    VeditorCommerceApp(
      commerceRepository: commerceRepository,
      purchaseService: purchaseService,
      appearance: buildAppearance(),
      catalog: buildCatalog(),
    ),
  );
}

final class VeditorCommerceApp extends StatelessWidget {
  const VeditorCommerceApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appearance.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: HomeScreen(
        commerceRepository: commerceRepository,
        purchaseService: purchaseService,
        appearance: appearance,
        catalog: catalog,
      ),
    );
  }
}
