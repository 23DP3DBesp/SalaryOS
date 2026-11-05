import Charts
import SalaryOSDomain
import SalaryOSTax
import SalaryOSPersistence
import Observation
import SwiftUI

private struct SalaryMonth: Identifiable {
    let month: Date
    let amount: Decimal
    var id: Date { month }
}

@MainActor
@Observable
private final class SalaryDashboardModel {
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository & SalaryRepository
    var categories: [SalaryOSDomain.Category] = []
    var postings: [LedgerPosting] = []
    var salaryRecords: [SalaryRecord] = []
    var currency: Currency?
    var errorMessage: String?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository & SalaryRepository) {
        self.repository = repository
    }

    func reload(taxYear: Int = 2026) {
        do {
            categories = try repository.categories(kind: .salary, includeArchived: true)
            let categoryIDs = Set(categories.map(\.id))
            let allPostings = try repository.postings(from: nil, through: nil)
            let reversedIDs = Set(allPostings.filter { $0.kind == .reversal }.compactMap(\.relatedPostingID))
            postings = allPostings.filter { posting in
                !reversedIDs.contains(posting.id) &&
                posting.kind == .income && posting.entries.contains {
                    categoryIDs.contains($0.accountID) && $0.accountKind == .income && $0.side == .credit
                }
            }.sorted { $0.occurredAt > $1.occurredAt }
            salaryRecords = try repository.salaryRecords(for: taxYear)
            let currencies = Set(postings.compactMap { $0.primaryAmount?.currency })
            currency = currencies.first(where: { $0.code == "EUR" }) ?? currencies.sorted { $0.code < $1.code }.first
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func monthlySeries(year: Int, calendar: Calendar) -> [SalaryMonth] {
        guard let currency else { return [] }
        return (1...12).compactMap { monthNumber in
            guard let date = calendar.date(from: DateComponents(year: year, month: monthNumber, day: 1)) else { return nil }
            let amount = postings.filter {
                calendar.component(.year, from: $0.occurredAt) == year
                    && calendar.component(.month, from: $0.occurredAt) == monthNumber
                    && $0.primaryAmount?.currency == currency
            }.reduce(Decimal.zero) { $0 + ($1.primaryAmount?.amount ?? .zero) }
            return SalaryMonth(month: date, amount: amount)
        }
    }
}

struct SalaryView: View {
    @Environment(\.locale) private var locale
    @State private var model: SalaryDashboardModel
    @State private var grossText = ""
    @AppStorage("salary.taxProfile.booklet") private var taxBookletApplied = true
    @AppStorage("salary.taxProfile.dependents") private var dependentCount = 0
    @AppStorage("salary.taxProfile.name") private var taxProfileName = "Main job"
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var isSalaryEntryPresented = false
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository & SalaryRepository

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository & SalaryRepository) {
        self.repository = repository
        _model = State(initialValue: SalaryDashboardModel(repository: repository))
    }

    private var result: MonthlySalaryResult? {
        guard let value = Decimal(string: grossText.replacingOccurrences(of: ",", with: ".")),
              let gross = try? Money(value, currency: Currency(code: "EUR"))
        else { return nil }
        return try? LatviaSalaryCalculator.calculate(MonthlySalaryInput(
            gross: gross, taxBookletApplied: taxBookletApplied, dependentCount: dependentCount
        ))
    }

    private var series: [SalaryMonth] { model.monthlySeries(year: selectedYear, calendar: .current) }
    private var yearTotal: Decimal { series.reduce(.zero) { $0 + $1.amount } }
    private var paidMonths: Int { series.filter { $0.amount > .zero }.count }
    private var average: Decimal { paidMonths == 0 ? .zero : yearTotal / Decimal(paidMonths) }
    private var currentMonthTotal: Decimal {
        let calendar = Calendar.current
        return model.postings.filter {
            guard let currency = model.currency, $0.primaryAmount?.currency == currency else { return false }
            return calendar.isDate($0.occurredAt, equalTo: .now, toGranularity: .month)
        }.reduce(.zero) { $0 + ($1.primaryAmount?.amount ?? .zero) }
    }
    private var recordedGross: Decimal { model.salaryRecords.reduce(.zero) { $0 + $1.gross.amount } }
    private var recordedWithholding: Decimal { model.salaryRecords.reduce(.zero) { $0 + $1.incomeTaxWithheld.amount } }
    private var annualTaxEstimate: AnnualTaxEstimate? {
        guard selectedYear == 2026, !model.salaryRecords.isEmpty,
              let currency = model.salaryRecords.first?.gross.currency,
              let taxableBase = try? Money(model.salaryRecords.reduce(.zero) { $0 + $1.taxableBase.amount }, currency: currency),
              let totalGross = try? Money(recordedGross, currency: currency) else { return nil }
        return try? LatviaAnnualTaxCalculator.estimate(taxableIncome: taxableBase, totalIncomeForAdditionalRate: totalGross, taxYear: selectedYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let errorMessage = model.errorMessage {
                    ContentUnavailableView("common.error-title", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    summaryCards
                    historyChart
                    annualReconciliation
                    recentSalary
                    calculator
                    Text("salary.disclaimer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("navigation.salary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isSalaryEntryPresented = true } label: {
                    Label("salary.record", systemImage: "plus")
                }
                .disabled(result == nil)
            }
        }
        .sheet(isPresented: $isSalaryEntryPresented, onDismiss: { model.reload(taxYear: selectedYear) }) {
            SalaryRecordEditor(repository: repository, result: result, taxBookletApplied: taxBookletApplied, dependentCount: dependentCount, profileName: taxProfileName)
        }
        .onAppear { model.reload(taxYear: selectedYear) }
        .onChange(of: selectedYear) { _, year in model.reload(taxYear: year) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("salary.page-title").font(.largeTitle.weight(.semibold))
                Text("salary.page-subtitle").foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button {
                selectedYear -= 1
            } label: {
                Label(String(selectedYear), systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            Button {
                selectedYear += 1
            } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
                .disabled(selectedYear >= Calendar.current.component(.year, from: .now))
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            metricCard(title: "salary.metric.this-month", amount: currentMonthTotal, symbol: "calendar")
            metricCard(title: "salary.metric.year-total", amount: yearTotal, symbol: "chart.bar")
            metricCard(title: "salary.metric.average", amount: average, symbol: "equal")
        }
    }

    private func metricCard(title: LocalizedStringKey, amount: Decimal, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(amount, format: .currency(code: model.currency?.code ?? "EUR"))
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("salary.history-title").font(.headline)
                    Text("salary.history-caption").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let currency = model.currency { Text(currency.code).font(.caption).foregroundStyle(.secondary) }
            }
            Chart(series) { item in
                BarMark(x: .value("Month", item.month, unit: .month), y: .value("Net salary", item.amount))
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 220)
            .overlay {
                if paidMonths == 0 {
                    ContentUnavailableView("salary.history-empty", systemImage: "chart.bar", description: Text("salary.history-empty-description"))
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var annualReconciliation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("salary.annual-reconciliation").font(.headline)
            if model.salaryRecords.isEmpty {
                Text("salary.annual-reconciliation-empty")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                reconciliationRow("salary.gross-total", amount: recordedGross)
                reconciliationRow("salary.withheld-total", amount: recordedWithholding)
                if let estimate = annualTaxEstimate {
                    reconciliationRow("salary.annual-tax-estimate", amount: estimate.totalIncomeTax.amount)
                    let difference = estimate.totalIncomeTax.amount - recordedWithholding
                    HStack {
                        Text(difference >= .zero ? "salary.estimated-underpayment" : "salary.estimated-overpayment")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(abs(difference), format: .currency(code: "EUR"))
                            .fontWeight(.semibold).monospacedDigit()
                            .foregroundStyle(difference > .zero ? .orange : .green)
                    }
                }
                Text("salary.annual-reconciliation-disclaimer")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func reconciliationRow(_ title: LocalizedStringKey, amount: Decimal) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(amount, format: .currency(code: "EUR")).monospacedDigit()
        }
        .font(.subheadline)
    }

    private var recentSalary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("salary.records-title").font(.headline)
            let records = model.postings.filter {
                Calendar.current.component(.year, from: $0.occurredAt) == selectedYear
                    && $0.primaryAmount?.currency == model.currency
            }
            if records.isEmpty {
                ContentUnavailableView("salary.records-empty", systemImage: "tray", description: Text("salary.records-empty-description"))
                    .frame(minHeight: 130)
            } else {
                ForEach(Array(records.prefix(8))) { posting in
                    let savedRecord = model.salaryRecords.first(where: { $0.id == posting.salaryRecordID })
                    HStack(spacing: 12) {
                        Image(systemName: "banknote")
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(posting.description).font(.subheadline.weight(.medium))
                            Text(posting.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                            if let savedRecord {
                                Text(String.localizedStringWithFormat(
                                    String(localized: "salary.payslip-summary"),
                                    formatted(savedRecord.gross), formatted(savedRecord.incomeTaxWithheld)
                                ))
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let amount = posting.primaryAmount {
                            Text(amount.amount, format: .currency(code: amount.currency.code))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    if posting.id != records.prefix(8).last?.id { Divider() }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var calculator: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("salary.calculator-title").font(.headline)
            Text("salary.calculator-description").font(.subheadline).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text("salary.profile-name")
                    TextField("salary.profile-name-placeholder", text: $taxProfileName)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                }
                GridRow {
                    Text("salary.gross")
                    TextField("salary.gross-placeholder", text: $grossText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }
                GridRow {
                    Text("salary.booklet")
                    Toggle("salary.booklet-short", isOn: $taxBookletApplied).labelsHidden()
                }
                GridRow {
                    Text("salary.dependents-label")
                    Stepper(value: $dependentCount, in: 0...10) {
                        Text("salary.dependents \(dependentCount)")
                    }
                    .disabled(!taxBookletApplied)
                }
            }
            if let result {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("salary.net").foregroundStyle(.secondary)
                    Spacer()
                    Text(result.net.amount, format: .currency(code: result.net.currency.code))
                        .font(.title2.weight(.semibold).monospacedDigit())
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        taxLine("salary.employee-contribution-short", result.employeeSocialContribution)
                        taxLine("salary.income-tax-short", result.incomeTaxWithheld)
                        taxLine("salary.employer-cost-short", result.employerCost)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        taxLine("salary.employee-contribution-short", result.employeeSocialContribution)
                        taxLine("salary.income-tax-short", result.incomeTaxWithheld)
                        taxLine("salary.employer-cost-short", result.employerCost)
                    }
                }
                Button { isSalaryEntryPresented = true } label: {
                    Label("salary.record-calculated", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func taxLine(_ title: LocalizedStringKey, _ amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(amount.amount, format: .currency(code: amount.currency.code))
                .font(.subheadline.monospacedDigit())
        }
    }

    private func formatted(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.code))
    }
}

private struct SalaryRecordEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & SalaryRepository
    let result: MonthlySalaryResult?
    let taxBookletApplied: Bool
    let dependentCount: Int
    let profileName: String
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [Account] = []
    @State private var categories: [SalaryOSDomain.Category] = []
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var occurredAt = Date.now
    @State private var descriptionText = ""
    @State private var gross = ""
    @State private var employeeSocial = ""
    @State private var taxableBase = ""
    @State private var allowance = ""
    @State private var incomeTax = ""
    @State private var employerSocial = ""
    @State private var errorMessage: String?

    private var takeHome: Decimal {
        (decimal(gross) ?? .zero) - (decimal(employeeSocial) ?? .zero) - (decimal(incomeTax) ?? .zero)
    }
    private var employerCost: Decimal {
        (decimal(gross) ?? .zero) + (decimal(employerSocial) ?? .zero)
    }
    private var canSave: Bool {
        guard let result,
              let grossValue = decimal(gross), let socialValue = decimal(employeeSocial),
              let baseValue = decimal(taxableBase), let allowanceValue = decimal(allowance),
              let taxValue = decimal(incomeTax), let employerSocialValue = decimal(employerSocial),
              let accountID, let categoryID else { return false }
        return result.gross.amount >= .zero && grossValue > .zero && socialValue >= .zero
            && baseValue >= .zero && allowanceValue >= .zero && taxValue >= .zero
            && employerSocialValue >= .zero && takeHome >= .zero
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && accounts.contains(where: { $0.id == accountID })
            && categories.contains(where: { $0.id == categoryID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("salary.payslip-details") {
                    amountField("salary.gross", text: $gross)
                    amountField("salary.employee-contribution-short", text: $employeeSocial)
                    amountField("salary.taxable-base", text: $taxableBase)
                    amountField("salary.allowance", text: $allowance)
                    amountField("salary.income-tax-short", text: $incomeTax)
                    amountField("salary.employer-contribution-short", text: $employerSocial)
                    LabeledContent("salary.net") { moneyText(takeHome).fontWeight(.semibold) }
                    LabeledContent("salary.employer-cost-short") { moneyText(employerCost) }
                }
                Section("salary.payment-details") {
                    Picker("transactions.field.account", selection: $accountID) {
                        Text("transactions.field.choose-account").tag(UUID?.none)
                        ForEach(accounts) { account in Text(account.name).tag(Optional(account.id)) }
                    }
                    Picker("transactions.field.category", selection: $categoryID) {
                        Text("transactions.field.choose-category").tag(UUID?.none)
                        ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
                    }
                    DatePicker("salary.payment-date", selection: $occurredAt, displayedComponents: .date)
                    TextField("transactions.field.description", text: $descriptionText)
                }
                Section {
                    LabeledContent("salary.profile-name", value: profileName)
                    LabeledContent("salary.booklet-short", value: String(localized: taxBookletApplied ? "common.yes" : "common.no"))
                    LabeledContent("salary.dependents-label", value: String(dependentCount))
                } header: {
                    Text("salary.tax-settings-used")
                } footer: {
                    Text("salary.recorded-breakdown-note")
                }
            }
            .navigationTitle("salary.record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(!canSave)
                }
            }
            .task { load() }
            .alert("common.error-title", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.done", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "common.unknown-error") }
        }
        .frame(minWidth: 380, minHeight: 570)
    }

    private func amountField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.00", text: text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
        }
    }

    private func moneyText(_ value: Decimal) -> some View {
        Text(value, format: .currency(code: "EUR")).monospacedDigit()
    }

    private func load() {
        do {
            accounts = try repository.accounts(includeArchived: false).filter { !$0.type.isLiability && $0.currency.code == "EUR" }
            categories = try repository.categories(kind: .salary, includeArchived: false)
            accountID = accounts.first?.id
            categoryID = categories.first(where: { $0.kind == .salary })?.id ?? categories.first?.id
            descriptionText = String(localized: "salary.monthly-payment")
            guard let result else { return }
            gross = number(result.gross.amount)
            employeeSocial = number(result.employeeSocialContribution.amount)
            taxableBase = number(result.taxableBase.amount)
            allowance = number(result.appliedAllowance.amount)
            incomeTax = number(result.incomeTaxWithheld.amount)
            employerSocial = number(result.employerSocialContribution.amount)
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            guard let result, let accountID, let categoryID,
                  let grossValue = decimal(gross), let socialValue = decimal(employeeSocial),
                  let baseValue = decimal(taxableBase), let allowanceValue = decimal(allowance),
                  let taxValue = decimal(incomeTax), let employerSocialValue = decimal(employerSocial) else { return }
            let currency = result.gross.currency
            let record = try SalaryRecord(
                taxYear: Calendar.current.component(.year, from: occurredAt), occurredAt: occurredAt,
                categoryID: categoryID, rulesID: result.rulesID,
                gross: Money(grossValue, currency: currency),
                employeeSocialContribution: Money(socialValue, currency: currency),
                taxableBase: Money(baseValue, currency: currency), appliedAllowance: Money(allowanceValue, currency: currency),
                incomeTaxWithheld: Money(taxValue, currency: currency), net: Money(takeHome, currency: currency),
                employerSocialContribution: Money(employerSocialValue, currency: currency), employerCost: Money(employerCost, currency: currency),
                taxBookletApplied: taxBookletApplied, dependentCount: dependentCount, profileName: profileName,
                description: descriptionText
            )
            _ = try repository.record(record, to: accountID)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func number(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
    private func decimal(_ value: String) -> Decimal? { Decimal(string: value.replacingOccurrences(of: ",", with: ".")) }
}
