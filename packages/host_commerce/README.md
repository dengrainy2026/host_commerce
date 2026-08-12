# host_commerce

Shared Native Host commerce runtime for Flutter tool applications.

It provides one source of truth for membership, periodic member credits,
permanent credits, idempotent consumable grants, redemption, purchase/restore,
credit-gated tool execution, and reusable paywall UI.

## Native Host purchase contract

- Inject one `StoreOperationCoordinator` into Native and H5 store operations.
- Keep every build connected to the real platform purchase plugin. Product IDs
  decide whether StoreKit/Play uses test or production catalog entries.
- Native Host Mode does not validate receipts/tokens with an API. By default,
  `HostPurchaseService` resolves only real `purchased`/`restored` stream updates
  through `NoReceiptHostPurchaseVerifier` and the allowlisted local catalog.
- Persist the entitlement or idempotent credit grant by store transaction ID
  before completing the platform transaction.
- Use a unique `SecureHostCommerceStore.stateKey` for every generated app.
- Run paid Native Tool work through `HostCreditGate`.

`HttpHostPurchaseVerifier` remains available only for a product that explicitly
opts into backend validation. Generated Host apps should not inject it under the
current portfolio contract. Pin this package by Git tag and commit.

## Optional HTTP verification response

The verifier expects `verified`, `productId`, `transactionId`, and `kind`.
Consumables also return `creditsGranted`; subscriptions return a future
`membershipExpiresAt` ISO-8601 timestamp.
