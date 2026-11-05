# Financial data model and invariants

## Current persisted records

- **Account:** stable UUID, name, account type, ISO 4217 currency, signed opening balance, optional institution/details, timestamps, and archive state.
- **Category:** stable UUID, name, income/salary/expense kind (salary categories post to income ledger accounts), optional same-kind parent, archive state, and timestamps.
- **Ledger posting:** stable UUID, operation kind, occurrence and creation timestamps, description/notes, optional related posting, and the complete encoded entry list.
- **Budget:** stable UUID, name, expense category, positive limit, ISO currency, calendar period (week/month/year), timestamps, and archive state. Budgets are stored separately from ledger entries and never alter balances.
- **Personal debt:** stable UUID, description, counterparty, direction (payable/receivable), immutable principal/currency, optional due date and notes, timestamps, and archive state.
- **Debt payment:** immutable UUID, debt reference, positive amount in the debt currency, payment date, optional note, and creation timestamp. Partial payments remain individually available as history.

Each posting and its entries are stored in one SwiftData record and saved together. Account/category/posting ID uniqueness checks happen in the repository; no CloudKit uniqueness constraint is used. Corrections preserve the original posting, append an exact side-swapped reversal, then append the corrected posting in one save. A failed correction adds neither record.

## Money and balances

Money uses `Decimal`, rounds at the ISO currency's minor-unit precision, and rejects arithmetic across different currencies. Account balances use a signed owner-perspective convention: assets have positive balances, liabilities have negative balances. Opening balance, account type, and currency are immutable for an account ID; corrections to opening state must use an auditable ledger operation rather than editing the baseline.

A debit increases the signed balance; a credit decreases it. That gives expected results for both assets (income debits, expenses/transfer-out credits) and liabilities (charges credit into a more negative balance; repayments debit toward zero).

## Ledger rules

- Every posted operation has at least two positive entries and total debits equal total credits.
- Income and salary: debit an asset account, credit a matching income or salary category. Salary is tracked as its own category kind while remaining ordinary ledger income for balances and reporting.
- Expense: debit an expense category, credit an asset or liability account.
- Transfer: debit one personal account and credit another. It does not affect income or expense totals.
- Refund: debit an asset or liability account and credit the original expense category. The repository requires a persisted original expense and prevents cumulative refunds from exceeding the original amount by category.
- Reversal: an exact side-swapped posting linked to its original. It can be applied once. An expense with an existing refund cannot be reversed.
- Correction: appends a reversal and a replacement posting atomically; neither the original nor its prior entries are edited or deleted.
- Adjustment: available as a balanced low-level posting; a dedicated UI correction workflow for arbitrary adjustments is future work.
- A posting currently contains a single currency. Cross-currency transfers are rejected until explicit FX clearing entries, exchange-rate snapshots, and rounding rules are implemented.

Archived accounts/categories remain available to historical postings but cannot receive new postings. Category kind and account accounting definition cannot change under an existing ID.

Budgets can only reference expense categories. Their progress is calculated from persisted expense/refund postings in the selected calendar interval; refunds reduce spending. A budget's category, period, and currency are immutable after creation. The current budget UI creates weekly, monthly, and yearly category budgets; account-specific/custom-period limits and projections are not implemented yet.

Personal debt outstanding is derived from the immutable principal minus its persisted payment records. The repository rejects duplicate payment IDs, missing debts, cross-currency payments, and payments exceeding the outstanding amount. Debt payment history is currently a separate tracking record; it is not yet posted to the financial ledger or linked to a selected account, so users must also record the corresponding cash movement as a transaction.

## Persistence limitations

The current SwiftData schema has no CloudKit configuration and has not been migration-tested against a released database. Repository tests use an in-memory container; disk persistence, schema migration, sync, backup/restore, and conflict resolution remain later milestones. Corrupt or invalid serialized values are rejected by domain decoding and mapping instead of being trusted.
