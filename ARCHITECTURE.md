# Architecture

The iOS and macOS application targets share SwiftUI presentation code. Financial rules live in the `SalaryOSDomain` local Swift package; SwiftData records and repository adapters live in the sibling `SalaryOSPersistence` package target.

```text
SwiftUI app targets
        │
        ├── AppContainer (composition root)
        │      └── FinancePersistenceStack
        │             └── SwiftData repositories
        │                    └── Domain models and rules
        └── Feature views (presentation only)
```

The UI does not issue SwiftData queries or calculate balances. Application services/use cases will be added as workflows grow; the current ledger factory constructs valid immutable postings, and repositories persist them.

No external dependencies, network calls, banking credentials, or CloudKit capabilities are part of the current foundation.
