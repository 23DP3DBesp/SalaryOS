# Roadmap

## Phase 0 — Repository and environment inspection

**Complete:** confirmed that the starting repository was empty and had no project settings, dependencies, entitlements, build targets, or tests. Recorded the installed toolchain and active Xcode selection limitation in [DEVELOPMENT.md](DEVELOPMENT.md).

## Phase 1 — Foundation

**Complete:** added shared SwiftUI source, iOS and macOS app targets, SwiftData composition root, adaptive navigation, native system appearance, Latvian/English/Russian string catalog, and a localized storage initialization error screen. Both targets build with Xcode 27.0.

## Phase 2 — Financial core

**Complete:** added ISO currency and Decimal money types; validated accounts/categories; balanced ledger postings; income, expense, transfer, refund, reversal, and correction operations; SwiftData repositories with duplicate/reference/archive checks; atomic posting storage; signed account balances; and domain/persistence tests. See [DATABASE.md](DATABASE.md) for rules and limits.

## Phase 3 — Main finance experience

**Complete:** added account creation, editing, archival and search; transaction creation, detail, search, type filters, duplication, reversal and correction; custom income/expense categories; compact iPhone tabs with a grouped “More” screen; and a grouped macOS finance sidebar with live account balances. The configurable dashboard now includes annual monthly cash-flow charts, prior-year comparison, category spending, account balances, and recent transactions. All displayed financial figures come from persisted data and localize in Latvian, English and Russian.

## Phase 4 — Salary and Latvian tax engine

**In progress:** verified the 2026 Latvian standard employee rates against VID/FM; added the versioned `SalaryOSTax` module, a monthly gross-to-net and employer-cost calculator, an annual progressive PIT estimate, and the first salary screen. See [TAX_ENGINE.md](TAX_ENGINE.md) for rule sources and calculation boundaries. The salary experience now records actual variable monthly payments in a dedicated salary category and shows monthly history, year total, and average. Salary profiles, stored gross/tax breakdowns, other employment classes, and variable-pay annual reconciliation remain future work.

## Later phases

- Phase 5 (complete): category budgets are persisted and show current-period spending and remaining amount from real ledger data; weekly/monthly/yearly periods supported. Personal debt tracking supports payable/receivable obligations, due dates, notes, partial repayments, and payment history. In-app repayments post linked balanced transfers with reversal support. Savings goals support targets, optional dates/accounts, immutable contributions, progress, and monthly targets; contributions post transfers with reversal-aware progress. Loan tracking supports fixed/variable rates, versioned rates, fees, amortization estimates, and extra-principal repayment recalculation; extra and regular installment payments post linked ledger entries, retain payment dates/history in the schedule, and are removed from the active schedule when reversed.
- Phase 6 (in progress): work-time entries support employer, shift interval, unpaid break, hourly rate, overlap validation, and monthly hours/gross estimates. Financial calendar previews weekly/monthly/yearly income and expense occurrences, supports explicit idempotent ledger posting, offers opt-in local reminders for the next 48 unposted events, and lets users change the schedule from its next upcoming occurrence while preserving posted history. Device sync for reminders remains.
- Phase 7: backup, import/export, and CloudKit sync.
- Phase 8: evaluated banking provider boundary and required backend work.
- Phase 9: end-to-end quality, privacy, accessibility, and release documentation.

## Next planned work

1. Finish the remaining Phase 4 and Phase 6 follow-ups documented above.
2. Continue with Phase 7 backup/import/export and sync, then Phase 8 provider integration and Phase 9 release readiness.
