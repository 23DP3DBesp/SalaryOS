# Roadmap

## Phase 0 — Repository and environment inspection

**Complete:** confirmed that the starting repository was empty and had no project settings, dependencies, entitlements, build targets, or tests. Recorded the installed toolchain and active Xcode selection limitation in [DEVELOPMENT.md](DEVELOPMENT.md).

## Phase 1 — Foundation

**Complete:** added shared SwiftUI source, iOS and macOS app targets, SwiftData composition root, adaptive navigation, native system appearance, Latvian/English/Russian string catalog, and a localized storage initialization error screen. Both targets build with Xcode 27.0.

## Phase 2 — Financial core

**Complete:** added ISO currency and Decimal money types; validated accounts/categories; balanced ledger postings; income, expense, transfer, refund, reversal, and correction operations; SwiftData repositories with duplicate/reference/archive checks; atomic posting storage; signed account balances; and domain/persistence tests. See [DATABASE.md](DATABASE.md) for rules and limits.

## Phase 3 — Main finance experience

**Complete:** added account creation, editing, archival and search; transaction creation, detail, search, type filters, duplication, reversal and correction; custom income/expense categories; iPhone tabs and a macOS sidebar; a configurable dashboard with reorderable/hideable widgets, six-month per-currency charts, balances, monthly cash flow and recent transactions. All displayed financial figures come from persisted data and localize in Latvian, English and Russian.

## Phase 4 — Salary and Latvian tax engine

**In progress:** verified the 2026 Latvian standard employee rates against VID/FM; added the versioned `SalaryOSTax` module, a monthly gross-to-net and employer-cost calculator, an annual progressive PIT estimate, and the first salary screen. See [TAX_ENGINE.md](TAX_ENGINE.md) for rule sources and calculation boundaries. Salary profiles, other employment classes, variable-pay annual reconciliation, and history remain future work.

## Later phases

- Phase 5: debts, loans, budgets, and savings.
- Phase 6: work time, recurring operations, calendar, and notifications.
- Phase 7: backup, import/export, and CloudKit sync.
- Phase 8: evaluated banking provider boundary and required backend work.
- Phase 9: end-to-end quality, privacy, accessibility, and release documentation.
