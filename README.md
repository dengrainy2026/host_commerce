# veditor_commerce

Thin template app that reuses the **`host_commerce`** package for local
in-app purchase / subscription and the credits model, extracted from Veditor.

The shell is host-only: no H5 bridge, no startup role split. A new app replaces
the placeholder tool on `HomeScreen` with its own tools and keeps the credit
gate (`HomeScreen._runTool`) around each creation.

## Layout

- `lib/app_config.dart` — template branding and the product catalog resolved
  per platform/release mode. **Edit this for a new app**: set your app name,
  legal URLs, and your StoreKit / Play Console product IDs.
- `lib/main.dart` — wires `HostCommerceRepository` + `HostPurchaseService` and
  runs the app.
- `lib/home_screen.dart` — placeholder tool with the credit gate demo.
- `lib/settings_screen.dart` — minimal settings reusing the package's
  `CreditsStatusCard`, `RedeemCodeDialog`, and `CommerceLegalFooter`.
- `packages/host_commerce/` — the reusable commerce contract layer.

## Verification

```sh
cd packages/host_commerce && flutter pub get && flutter analyze && flutter test
cd ../.. && flutter pub get && flutter analyze && flutter test
```

## New app checklist

1. Rename the app (`flutter create . --project-name <app>` / edit `pubspec.yaml`).
2. Replace branding + product IDs in `lib/app_config.dart`.
3. Replace the placeholder tool on `HomeScreen` with your tool.
4. Set your bundle id / application id and store credentials for each platform.
