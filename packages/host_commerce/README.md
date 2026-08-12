# host_commerce

Shared Native Host commerce runtime for Flutter tool applications.

It provides one source of truth for membership, periodic member credits,
permanent credits, verified consumable grants, redemption, purchase/restore,
credit-gated tool execution, and reusable paywall UI.

## Production contract

- Inject one `StoreOperationCoordinator` into Native and H5 store operations.
- Use `HttpHostPurchaseVerifier` with an HTTPS business endpoint.
- Grant only a response bound to the requested product and transaction IDs.
- Persist the verified entitlement or idempotent credit grant before completing
  the platform transaction.
- Use a unique `SecureHostCommerceStore.stateKey` for every generated app.
- Run paid Native Tool work through `HostCreditGate`.

When verification is absent, `RejectingHostPurchaseVerifier` fails closed.
Generated applications should pin this package by Git tag and commit.

## Verification response

The verifier expects `verified`, `productId`, `transactionId`, and `kind`.
Consumables also return `creditsGranted`; subscriptions return a future
`membershipExpiresAt` ISO-8601 timestamp.
