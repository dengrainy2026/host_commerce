# veditor_commerce

Thin template app that reuses the **`host_commerce`** package for local
in-app purchase / subscription and the credits model, extracted from Veditor.

The shell is host-only: no H5 bridge, no startup role split. A new app replaces
the placeholder tool on `HomeScreen` with its own tools and keeps the credit
gate (`HomeScreen._runTool`) around each creation.

## Layout

- `lib/app_config.dart` — the single runtime customization entry. **Edit the
  `kAppConfig` object for a new app**: branding, legal URLs, theme color, home
  tool presentation, credit/membership rules, and StoreKit / Play product IDs.
- `lib/main.dart` — wires `HostCommerceRepository` + `HostPurchaseService` and
  initializes StoreKit recovery before wiring the commerce services and running
  the app.
- `lib/home_screen.dart` — placeholder tool with the credit gate demo.
- `lib/settings_screen.dart` — minimal settings reusing the package's
  `CreditsStatusCard`, `RedeemCodeDialog`, and `CommerceLegalFooter`.
- `packages/host_commerce/` — the reusable commerce contract layer.

## Runtime configuration

All runtime customization is collected in the `kAppConfig` object in
`lib/app_config.dart`. When creating a new tool app, edit this object to change:

- App display name, privacy-policy URL, and terms-of-use URL.
- Material theme seed color.
- Home-screen section label, tool name, and tool icon.
- Initial credits, creation cost, recurring member credits and period, and
  redemption credits.
- Android, iOS release, and iOS development product IDs and credit packages.

```dart
const AppConfig kAppConfig = AppConfig(
  appearance: CommerceAppearance(
    appDisplayName: 'My Tool',
    privacyPolicyUrl: 'https://example.com/privacy',
    termsOfUseUrl: 'https://example.com/terms',
  ),
  themeSeedColor: Colors.indigo,
  tool: HomeToolConfig(
    sectionLabel: 'CREATE',
    title: 'My tool',
    icon: Icons.auto_awesome,
  ),
  commerceRules: CommerceRules(
    initialCredits: 100,
    creationCost: 100,
    memberCreditsPerPeriod: 1000,
    redemptionCredits: 2000,
    membershipCreditPeriod: Duration(days: 7),
  ),
  androidCatalog: HostProductCatalog(...),
  iosReleaseCatalog: HostProductCatalog(...),
  iosDevelopmentCatalog: HostProductCatalog(...),
);
```

Some release settings cannot be controlled by the Dart configuration and must
remain in their platform-specific locations:

- Bundle ID and Android application ID.
- App version and build number in `pubspec.yaml`.
- Native iOS and Android display names.
- Store signing, certificates, and release credentials.

Production purchases require an HTTPS verifier configured with
`--dart-define=NATIVE_PURCHASE_VERIFICATION_URL=https://...`. The package
rejects purchases when no verifier is configured, persists verified
transaction IDs before completing store transactions, and ignores duplicate
redelivery grants.

Run Native Tool work through `HostCreditGate`. It serializes concurrent tool
requests, charges only successful operations, and returns
`HostCreditGateStatus.insufficientCredits` without running the tool when the
balance is too low.

## Verification

```sh
cd packages/host_commerce && flutter pub get && flutter analyze && flutter test
cd ../.. && flutter pub get && flutter analyze && flutter test
```

## New app checklist

1. Rename the app (`flutter create . --project-name <app>` / edit `pubspec.yaml`).
2. Replace the values in `kAppConfig` in `lib/app_config.dart`.
3. Replace the placeholder execution in `HomeScreen._runTool` with your tool.
4. Set your bundle id / application id and store credentials for each platform.
