# Financial data model and invariants

## Current persisted records

- **Account:** stable UUID, name, account type, ISO 4217 currency, signed opening balance, optional institution/details, timestamps, and archive state.
- **Category:** stable UUID, name, income/salary/expense kind (salary categories post to income ledger accounts), optional same-kind parent, archive state, and timestamps.
- **Ledger posting:** stable UUID, operation kind, occurrence and creation timestamps, description/notes, optional related posting, and the complete encoded entry list.
- **Budget:** stable UUID, name, expense category, positive limit, ISO currency, calendar period (week/month/year), timestamps, and archive state. Budgets are stored separately from ledger entries and never alter balances.
- **Personal debt:** stable UUID, description, counterparty, direction (payable/receivable), immutable principal/currency, optional due date and notes, timestamps, and archive state.
- **Debt payment:** immutable UUID, debt reference, positive amount in the debt currency, payment date, optional note, and creation timestamp. Partial payments remain individually available as history.
- **Savings goal:** stable UUID, name, immutable currency, target, optional target date/account, notes, timestamps, and archive state.
- **Savings contribution:** immutable UUID, goal reference, positive amount in the goal currency, contribution date, optional note, and creation timestamp.
- **Loan:** lender, immutable principal/currency, fixed or variable rate type, initial annual rate, term, start date, fees, notes, and archive state.
- **Loan rate change:** immutable annual rate and effective date for variable-rate loans.
- **Loan extra repayment:** immutable principal reduction, payment date, and note. Extra repayments are applied at the monthly period boundary in the estimate.
- **Work entry:** employer, description, start/end instants, unpaid break, hourly rate/currency, notes, and timestamps. Overlapping entries are rejected.
- **Scheduled operation:** income/expense template, amount/currency, account/category, recurrence frequency, anchor date, optional end date, notes, and archive state. Posted ledger records carry a stable occurrence ID to prevent duplicate generation.

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

Savings progress is derived from all saved contributions and the configured target. The displayed progress bar caps at 100%, while the saved total retains any amount above the target. An optional linked account is validated for existence and matching currency; contributions remain goal allocations and do not change the account ledger balance. This keeps the distinction between earmarking funds and moving funds explicit.

Loan schedules are estimates generated with Decimal arithmetic. Variable-rate changes are stored with effective dates; the calculator recalculates the monthly installment while retaining the original payoff term. Extra principal repayments are stored separately and applied at their calendar-month boundary. Fees are included in estimated total cost but are not folded into the principal. Loan estimates and recorded repayments do not update account balances or the transaction ledger; actual bank payments must be recorded separately until loan-ledger integration is implemented. Bank-specific day-count rules, payment holidays, rate floors, and contract fees are not modeled.

Work-time summaries group shifts by employer and currency for the month in which each shift starts. Unpaid breaks are deducted from elapsed seconds; hours and gross estimates use Decimal. Gross estimates exclude tax withholding, overtime premiums, night work and holiday rates, and are not payroll results. Salary income must still be recorded separately in the ledger.

Scheduled operations generate calendar occurrences from a stable first-date anchor. Monthly recurrence preserves the anchor day (clamping to the last valid day of shorter months); yearly recurrence handles leap-day anchors by clamping in non-leap years. Occurrences are previewed and posted only after an explicit user action. Their stable IDs are stored on ledger postings, so retrying a post cannot duplicate it even when the actual transaction date differs from the scheduled date. Editing amount/name leaves prior postings immutable; changing the recurrence definition is not supported in-place in this first version.

Calendar reminders are opt-in local notifications at 9:00 AM on the scheduled date. The app refreshes the next 48 unposted reminders when the calendar opens or a schedule changes; authorization is controlled by the operating system. Reminders are device-local and are not synced between devices.

## Persistence limitations

The current SwiftData schema has no CloudKit configuration and has not been migration-tested against a released database. Repository tests use an in-memory container; disk persistence, schema migration, sync, backup/restore, and conflict resolution remain later milestones. Corrupt or invalid serialized values are rejected by domain decoding and mapping instead of being trusted.
