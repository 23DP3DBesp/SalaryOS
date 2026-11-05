import SalaryOSDomain
import SwiftUI

struct LoansView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    @State private var loans: [(loan: Loan, schedule: LoanSchedule)] = []
    @State private var editorLoan: Loan?
    @State private var isEditorPresented = false
    @State private var extraPaymentLoan: Loan?
    @State private var rateChangeLoan: Loan?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loans.isEmpty {
                ContentUnavailableView("loan.empty.title", systemImage: "creditcard", description: Text("loan.empty.description"))
            } else {
                List {
                    ForEach(loans, id: \.loan.id) { item in
                        loanSection(item.loan, schedule: item.schedule)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("navigation.loans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("loan.add", systemImage: "plus") { editorLoan = nil; isEditorPresented = true }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: reload) {
            LoanEditor(repository: repository, existingLoan: editorLoan)
        }
        .sheet(item: $extraPaymentLoan, onDismiss: reload) { loan in
            LoanExtraPaymentEditor(repository: repository, loan: loan)
        }
        .sheet(item: $rateChangeLoan, onDismiss: reload) { loan in
            LoanRateEditor(repository: repository, loan: loan)
        }
        .task { reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder
    private func loanSection(_ loan: Loan, schedule: LoanSchedule) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loan.name).font(.headline)
                        Text(loan.lender).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(money(loan.principal)).font(.headline)
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                    summaryRow("loan.interest-rate", value: "\(loan.annualInterestRate.formatted(.number.precision(.fractionLength(2))))%")
                    summaryRow("loan.rate-type", value: loan.rateType.localizedName)
                    summaryRow("loan.monthly-payment", value: money(schedule.installments.first?.regularPayment ?? .zero(in: loan.principal.currency)))
                    summaryRow("loan.total-interest", value: money(schedule.totalInterest))
                    summaryRow("loan.total-cost", value: money(schedule.estimatedTotalCost))
                    if let payoffDate = schedule.payoffDate { summaryRow("loan.payoff-date", value: payoffDate.formatted(date: .abbreviated, time: .omitted)) }
                }
                Text("loan.estimate-disclaimer")
                    .font(.caption).foregroundStyle(.secondary)
                Text("loan.ledger-disclaimer")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("loan.extra-payment", systemImage: "plus.circle") { extraPaymentLoan = loan }
                    if loan.rateType == .variable {
                        Button("loan.change-rate", systemImage: "percent") { rateChangeLoan = loan }
                    }
                }
                .font(.subheadline)

                DisclosureGroup("loan.schedule") {
                    ForEach(schedule.installments) { installment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(installment.dueDate.formatted(date: .abbreviated, time: .omitted)) · \(installment.appliedRate.formatted(.number.precision(.fractionLength(2))))%")
                                    .font(.subheadline)
                                Spacer()
                                Text(money(installment.regularPayment)).font(.subheadline.weight(.medium))
                            }
                            HStack {
                                Text("\(String(localized: "loan.principal-paid")): \(money(installment.principalPaid))")
                                Spacer()
                                Text("\(String(localized: "loan.interest")): \(money(installment.interest))")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if installment.extraPrincipalPaid.amount > .zero {
                                Text("\(String(localized: "loan.extra-principal")): \(money(installment.extraPrincipalPaid))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.vertical, 5)
        }
        .contextMenu {
            Button("loan.edit", systemImage: "pencil") { editorLoan = loan; isEditorPresented = true }
            Button("loan.archive", systemImage: "archivebox") { archive(loan) }
        }
    }

    private func summaryRow(_ key: LocalizedStringKey, value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func money(_ value: Money) -> String { value.amount.formatted(.currency(code: value.currency.code)) }

    private func reload() {
        do {
            loans = try repository.loans(includeArchived: false).map { ($0, try repository.schedule(for: $0.id, calendar: .current)) }
                .sorted { $0.loan.startDate > $1.loan.startDate }
        } catch { errorMessage = error.localizedDescription }
    }

    private func archive(_ loan: Loan) {
        do { var value = loan; value.setArchived(true); try repository.save(value); reload() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct LoanEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    let existingLoan: Loan?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var lender = ""
    @State private var principal = ""
    @State private var currencyCode = "EUR"
    @State private var annualRate = ""
    @State private var rateType: LoanRateType = .fixed
    @State private var durationMonths = "240"
    @State private var startDate = Date.now
    @State private var fees = "0"
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("loan.name", text: $name)
                TextField("loan.lender", text: $lender)
                HStack {
                    TextField("loan.principal", text: $principal)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    TextField("loan.currency", text: $currencyCode).frame(maxWidth: 70).disabled(existingLoan != nil)
                }
                .disabled(existingLoan != nil)
                HStack {
                    TextField("loan.interest-rate", text: $annualRate)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    Text("%")
                    Picker("loan.rate-type", selection: $rateType) {
                        ForEach(LoanRateType.allCases, id: \.self) { item in Text(item.localizationKey).tag(item) }
                    }
                }
                .disabled(existingLoan != nil)
                TextField("loan.duration-months", text: $durationMonths)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                .disabled(existingLoan != nil)
                DatePicker("loan.start-date", selection: $startDate, displayedComponents: .date)
                    .disabled(existingLoan != nil)
                TextField("loan.fees", text: $fees)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                .disabled(existingLoan != nil)
                TextField("loan.notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle("loan.add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(name.isEmpty || lender.isEmpty || Decimal(string: principal) == nil || Decimal(string: annualRate) == nil)
                }
            }
            .task { load() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 380, minHeight: 540)
    }

    private func load() {
        guard let existingLoan else { return }
        name = existingLoan.name
        lender = existingLoan.lender
        principal = NSDecimalNumber(decimal: existingLoan.principal.amount).stringValue
        currencyCode = existingLoan.principal.currency.code
        annualRate = NSDecimalNumber(decimal: existingLoan.annualInterestRate).stringValue
        rateType = existingLoan.rateType
        durationMonths = String(existingLoan.durationMonths)
        startDate = existingLoan.startDate
        fees = NSDecimalNumber(decimal: existingLoan.fees.amount).stringValue
        notes = existingLoan.notes ?? ""
    }

    private func save() {
        do {
            if var existingLoan {
                try existingLoan.update(name: name, lender: lender, notes: notes)
                try repository.save(existingLoan)
            } else {
                guard let principalValue = decimal(principal), let rate = decimal(annualRate),
                      let duration = Int(durationMonths), let feeValue = decimal(fees) else { throw LoanError.invalidSchedule }
                let currency = try Currency(code: currencyCode.uppercased())
                let loan = try Loan(
                    name: name, lender: lender, principal: Money(principalValue, currency: currency),
                    annualInterestRate: rate, rateType: rateType, durationMonths: duration,
                    startDate: startDate, fees: Money(feeValue, currency: currency), notes: notes
                )
                try repository.save(loan)
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func decimal(_ input: String) -> Decimal? { Decimal(string: input.replacingOccurrences(of: ",", with: ".")) }
}

private struct LoanExtraPaymentEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    let loan: Loan
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var paidAt = Date.now
    @State private var note = ""
    @State private var accounts: [Account] = []
    @State private var accountID: UUID?
    @State private var errorMessage: String?

    private var compatibleAccounts: [Account] {
        accounts.filter { !$0.type.isLiability && $0.currency == loan.principal.currency }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("loan.extra-payment-amount", text: $amount)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Picker("loan.payment-account", selection: $accountID) {
                    Text("transactions.field.choose-account").tag(UUID?.none)
                    ForEach(compatibleAccounts) { account in Text(account.name).tag(Optional(account.id)) }
                }
                DatePicker("loan.payment-date", selection: $paidAt, displayedComponents: .date)
                TextField("loan.payment-note", text: $note)
            }
            .navigationTitle("loan.extra-payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(Decimal(string: amount) == nil || accountID == nil)
                }
            }
            .task { loadAccounts() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 330)
    }

    private func loadAccounts() {
        do {
            accounts = try repository.accounts(includeArchived: false)
            accountID = compatibleAccounts.first?.id
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            guard let value = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { throw LoanError.nonPositiveExtraPayment }
            guard let accountID else { return }
            let payment = try LoanExtraPayment(loanID: loan.id, principalReduction: Money(value, currency: loan.principal.currency), paidAt: paidAt, loan: loan, note: note)
            _ = try repository.record(payment, from: accountID)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct LoanRateEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    let loan: Loan
    @Environment(\.dismiss) private var dismiss
    @State private var rate = ""
    @State private var effectiveDate = Date.now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("loan.new-rate", text: $rate)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                DatePicker("loan.effective-date", selection: $effectiveDate, displayedComponents: .date)
            }
            .navigationTitle("loan.change-rate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save", action: save).disabled(Decimal(string: rate) == nil) }
            }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 340, minHeight: 240)
    }

    private func save() {
        do {
            guard let value = Decimal(string: rate.replacingOccurrences(of: ",", with: ".")) else { throw LoanError.invalidInterestRate }
            let change = try LoanRateChange(loanID: loan.id, annualInterestRate: value, effectiveDate: effectiveDate, loan: loan)
            try repository.record(change)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension LoanRateType {
    var localizationKey: LocalizedStringKey {
        switch self { case .fixed: "loan.rate.fixed"; case .variable: "loan.rate.variable" }
    }
    var localizedName: String {
        switch self { case .fixed: String(localized: "loan.rate.fixed"); case .variable: String(localized: "loan.rate.variable") }
    }
}
