# Architecture

The iOS and macOS targets share SwiftUI presentation code. The financial domain, application use cases, and SwiftData adapter are local Swift Package targets.

```text
SwiftUI app targets
        │
        ├── AppContainer (composition root)
        │      └── FinancePersistenceStack
        │             └── SwiftData repositories
        ├── Feature view models
        │      └── SalaryOSApplication use cases
        └── SalaryOSDomain entities, rules, and repository interfaces
```

Views render state and collect input. View models coordinate presentation state, while `LoadDashboardSnapshot` derives persisted balances and cash flow for the dashboard. Ledger factories and repositories enforce financial invariants; SwiftUI views do not query SwiftData directly or calculate transaction balances.

The app uses no external dependencies, network services, banking credentials, or CloudKit capabilities yet.
