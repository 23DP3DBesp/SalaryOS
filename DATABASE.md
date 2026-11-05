# Financial data model and invariants

## Current persisted records

- **Account:** stable UUID, name, account type, ISO 4217 currency, signed opening balance, optional institution/details, timestamps, and archive state.
- **Category:** stable UUID, name, income/expense kind, optional same-kind parent, archive state, and timestamps.
- **Ledger posting:** stable UUID, operation kind, occurrence and creation timestamps, description/notes, optional related posting, and the complete encoded entry list.

Each posting and its entries are stored in one SwiftData record and saved together. The account/category/posting ID uniqueness checks happen in the repository; no CloudKit uniqueness constraint is used. Corrections do not mutate posted entries. Reversal and adjustment workflows will be added in a later milestone.

## Money and balances

Money uses `Decimal`, rounds at the ISO currency's minor-unit precision, and rejects arithmetic across different currencies. Account balances use a signed owner-perspective convention: assets have positive balances, liabilities have negative balances. Opening balance, account type, and currency are immutable for an account ID; corrections to opening state must use an auditable ledger operation rather than editing the baseline.

A debit increases the signed balance; a credit decreases it. That gives expected results for both assets (income debits, expenses/transfer-out credits) and liabilities (charges credit into a more negative balance; repayments debit toward zero).

## Ledger rules

- Every posted operation has at least two positive entries and total debits equal total credits.
- Income: debit an asset account, credit an income category.
- Expense: debit an expense category, credit an asset or liability account.
- Transfer: debit one personal account and credit another. It does not affect income or expense totals.
- Refund: debit an asset or liability account and credit the original expense category. The repository requires a persisted original expense and prevents cumulative refunds from exceeding the original amount by category.
- Adjustment: available as a balanced low-level posting; dedicated correction workflows and audit metadata are future work.
- A posting currently contains a single currency. Cross-currency transfers are rejected until explicit FX clearing entries, exchange-rate snapshots, and rounding rules are implemented.

Archived accounts/categories remain available to historical postings but cannot receive new postings. Category kind and account accounting definition cannot change under an existing ID.

## Persistence limitations

The current SwiftData schema has no CloudKit configuration and has not been migration-tested against a released database. Repository tests use an in-memory container; disk persistence, schema migration, sync, backup/restore, and conflict resolution remain later milestones. Corrupt or invalid serialized values are rejected by domain decoding and mapping instead of being trusted.
