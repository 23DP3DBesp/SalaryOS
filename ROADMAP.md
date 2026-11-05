# Roadmap

## Phase 0 — Repository and environment inspection

**Complete:** confirmed that the starting repository was empty and had no project settings, dependencies, entitlements, build targets, or tests. Recorded the installed toolchain and active Xcode selection limitation in [DEVELOPMENT.md](DEVELOPMENT.md).

## Phase 1 — Foundation

**Complete:** added shared SwiftUI source, iOS and macOS app targets, SwiftData composition root, adaptive initial navigation, native light/dark system appearance, Latvian/English/Russian string catalog, and a localized storage initialization error screen. Both targets build with Xcode 27.0.

## Phase 2 — Financial core

**Complete:** added ISO currency and Decimal money types; validated accounts/categories; immutable balanced ledger postings and factories for income, expense, transfer, and refund; SwiftData repositories with duplicate/reference/archive checks; atomic posting storage; signed account balance calculation; and domain plus in-memory persistence tests. See [DATABASE.md](DATABASE.md) for exact rules and limitations.

## Phase 3 — Main finance experience

Next: add account and transaction workflows using the repositories, then derive dashboard metrics from persisted data. Add localized forms, validation, search/filter behavior, and accessible empty states.

## Later phases

- Phase 4: verified, versioned Latvian salary tax engine.
- Phase 5: debts, loans, budgets, and savings.
- Phase 6: work time, recurring operations, calendar, and notifications.
- Phase 7: backup, import/export, and CloudKit sync.
- Phase 8: evaluated banking provider boundary and required backend work.
- Phase 9: end-to-end quality, privacy, accessibility, and release documentation.
