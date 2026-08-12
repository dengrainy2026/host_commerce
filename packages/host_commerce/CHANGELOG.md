## 0.2.0

- Added strict HTTPS purchase verification with identifier and grant checks.
- Persisted processed transaction IDs for idempotent consumable grants.
- Added `HostCreditGate` for serialized, success-only Native Tool charging.
- Made unconfigured purchase verification fail closed.

## 0.1.0

- Extracted the reusable membership, credits, purchase, restore, and commerce
  UI runtime from the reference Host application.
