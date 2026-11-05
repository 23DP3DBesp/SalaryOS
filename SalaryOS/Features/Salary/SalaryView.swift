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
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository
    var categories: [SalaryOSDomain.Category] = []
    var postings: [LedgerPosting] = []
    var currency: Currency?
    var errorMessage: String?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            categories = try repository.categories(kind: .salary, includeArchived: true)
            let categoryIDs = Set(categories.map(\.id))
            postings = try repository.postings(from: nil, through: nil).filter { posting in
                posting.kind == .income && posting.entries.contains {
                    categoryIDs.contains($0.accountID) && $0.accountKind == .income && $0.side == .credit
                }
            }.sorted { $0.occurredAt > $1.occurredAt }
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
    @State private var taxBookletApplied = true
    @State private var dependentCount = 0
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var isSalaryEntryPresented = false
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository) {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let errorMessage = model.errorMessage {
                    ContentUnavailableView("common.error-title", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    summaryCards
                    historyChart
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
            }
        }
        .sheet(isPresented: $isSalaryEntryPresented, onDismiss: model.reload) {
            TransactionEditorView(repository: repository, salaryOnly: true, presetAmount: result?.net.amount)
        }
        .onAppear(perform: model.reload)
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
                    HStack(spacing: 12) {
                        Image(systemName: "banknote")
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(posting.description).font(.subheadline.weight(.medium))
                            Text(posting.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
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
}
