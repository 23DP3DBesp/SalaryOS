import Charts
import SalaryOSApplication
import Observation
import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

private enum DashboardWidget: String, CaseIterable, Identifiable {
    case overview, accounts, cashFlow, recent

    var id: String { rawValue }
    var localizedKey: LocalizedStringKey {
        switch self {
        case .overview: "dashboard.widget.overview"
        case .accounts: "dashboard.widget.accounts"
        case .cashFlow: "dashboard.widget.cashflow"
        case .recent: "dashboard.widget.recent"
        }
    }
}

private struct ReportMonth: Identifiable {
    let date: Date
    var income: Decimal = .zero
    var expenses: Decimal = .zero
    var id: Date { date }
    var incomeValue: Double { NSDecimalNumber(decimal: income).doubleValue }
    var expensesValue: Double { NSDecimalNumber(decimal: expenses).doubleValue }
}

private struct CategorySpend: Identifiable {
    let id: UUID
    let name: String
    var amount: Decimal
}

private enum ReportSection: String, CaseIterable, Identifiable {
    case header, metrics, cashflow, categories, daily, comparison, accounts, recent
    var id: String { rawValue }
}

private struct DailySpendPoint: Identifiable {
    let day: Int
    let amount: Double
    var id: Int { day }
}

private struct YearComparisonRow: Identifiable {
    let id: UUID
    let name: String
    let current: Decimal
    let previous: Decimal
}

private struct YearFlowMark: Identifiable {
    let id: String
    let month: Int
    let year: Int
    let kind: String
    let amount: Double
}

@MainActor
@Observable
private final class DashboardViewModel {
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository
    var accounts: [Account] = []
    var balances: [UUID: Money] = [:]
    var summaries: [DashboardCurrencySummary] = []
    var recentPostings: [LedgerPosting] = []
    var categories: [UUID: SalaryOSDomain.Category] = [:]
    var postings: [LedgerPosting] = []
    var errorMessage: String?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            let snapshot = try LoadDashboardSnapshot(accountRepository: repository, ledgerRepository: repository).execute()
            accounts = snapshot.accounts.map(\.account)
            balances = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.account.id, $0.balance) })
            summaries = snapshot.currencies
            recentPostings = snapshot.recentPostings
            postings = try repository.postings(from: nil, through: nil)
            categories = Dictionary(uniqueKeysWithValues: try repository.categories(kind: nil, includeArchived: true).map { ($0.id, $0) })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func months(year: Int, currency: Currency, calendar: Calendar) -> [ReportMonth] {
        let dates = (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
        var rows = Dictionary(uniqueKeysWithValues: dates.map { ($0, ReportMonth(date: $0)) })
        for posting in postings {
            guard posting.entries.first?.money.currency == currency,
                  let month = calendar.dateInterval(of: .month, for: posting.occurredAt)?.start,
                  var row = rows[month] else { continue }
            switch posting.kind {
            case .income:
                row.income += posting.entries.filter { $0.accountKind == .income && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
            case .expense:
                row.expenses += posting.entries.filter { $0.accountKind == .expense && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
            case .refund:
                row.expenses -= posting.entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
            case .reversal:
                guard let original = postings.first(where: { $0.id == posting.relatedPostingID }) else { continue }
                if original.kind == .income {
                    row.income -= posting.entries.filter { $0.accountKind == .income && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
                } else if original.kind == .expense {
                    row.expenses -= posting.entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
                } else if original.kind == .adjustment {
                    row.expenses -= posting.entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
                }
            case .adjustment:
                row.expenses += posting.entries.filter { $0.accountKind == .expense && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
            case .transfer: break
            }
            rows[month] = row
        }
        return dates.compactMap { rows[$0] }
    }

    func categorySpending(year: Int, currency: Currency, calendar: Calendar) -> [CategorySpend] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        var totals: [UUID: Decimal] = [:]
        for posting in postings where posting.occurredAt >= start && posting.occurredAt < end && posting.entries.first?.money.currency == currency {
            switch posting.kind {
            case .expense:
                for entry in posting.entries where entry.accountKind == .expense && entry.side == .debit { totals[entry.accountID, default: .zero] += entry.money.amount }
            case .refund:
                for entry in posting.entries where entry.accountKind == .expense && entry.side == .credit { totals[entry.accountID, default: .zero] -= entry.money.amount }
            case .reversal:
                guard let original = postings.first(where: { $0.id == posting.relatedPostingID }) else { continue }
                if original.kind == .expense {
                    for entry in posting.entries where entry.accountKind == .expense && entry.side == .credit { totals[entry.accountID, default: .zero] -= entry.money.amount }
                } else if original.kind == .adjustment {
                    for entry in posting.entries where entry.accountKind == .expense && entry.side == .credit { totals[entry.accountID, default: .zero] -= entry.money.amount }
                } else if original.kind == .refund {
                    for entry in posting.entries where entry.accountKind == .expense && entry.side == .debit { totals[entry.accountID, default: .zero] += entry.money.amount }
                }
            case .adjustment:
                for entry in posting.entries where entry.accountKind == .expense && entry.side == .debit { totals[entry.accountID, default: .zero] += entry.money.amount }
            case .income, .transfer: break
            }
        }
        return totals.compactMap { id, amount in
            guard amount > .zero else { return nil }
            return CategorySpend(id: id, name: categories[id]?.name ?? String(localized: "transaction.uncategorized"), amount: amount)
        }.sorted { $0.amount > $1.amount }
    }

    func comparisonRows(year: Int, currency: Currency, kind: CategoryKind, calendar: Calendar) -> [YearComparisonRow] {
        let current = categoryTotals(year: year, currency: currency, kind: kind, calendar: calendar)
        let previous = categoryTotals(year: year - 1, currency: currency, kind: kind, calendar: calendar)
        return Set(current.keys).union(previous.keys).map { id in
            YearComparisonRow(
                id: id,
                name: categories[id]?.name ?? String(localized: "dashboard.report.uncategorized"),
                current: current[id] ?? .zero,
                previous: previous[id] ?? .zero
            )
        }
        .filter { $0.current != .zero || $0.previous != .zero }
        .sorted { abs($0.current) > abs($1.current) }
    }

    private func categoryTotals(year: Int, currency: Currency, kind: CategoryKind, calendar: Calendar) -> [UUID: Decimal] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [:] }
        var totals: [UUID: Decimal] = [:]
        for posting in postings where posting.occurredAt >= start && posting.occurredAt < end && posting.entries.first?.money.currency == currency {
            let ledgerKind: LedgerAccountKind = kind == .expense ? .expense : .income
            let normalSide: EntrySide = kind == .expense ? .debit : .credit
            let reverseSide: EntrySide = kind == .expense ? .credit : .debit
            var sign: Decimal = 1
            switch posting.kind {
            case .expense where kind == .expense, .income where kind != .expense,
                 .adjustment where kind == .expense: break
            case .refund where kind == .expense: sign = -1
            case .reversal:
                guard let original = postings.first(where: { $0.id == posting.relatedPostingID }) else { continue }
                if original.kind == .refund && kind == .expense { sign = 1 }
                else if (original.kind == .expense && kind == .expense)
                    || (original.kind == .adjustment && kind == .expense)
                    || (original.kind == .income && kind != .expense) { sign = -1 }
                else { continue }
            default: continue
            }
            let side = sign < 0 ? reverseSide : normalSide
            for entry in posting.entries where entry.accountKind == ledgerKind && entry.side == side {
                totals[entry.accountID, default: .zero] += entry.money.amount * sign
            }
        }
        return totals
    }
}

struct DashboardView: View {
    @State private var model: DashboardViewModel
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedCurrencyCode: String?
    @AppStorage("dashboard.reportOrder") private var sectionOrderRaw = "header,metrics,cashflow,categories,daily,comparison,accounts,recent"
    @AppStorage("dashboard.reportHidden") private var hiddenSectionsRaw = ""
    @State private var isConfigurationPresented = false
    let onAddAccount: () -> Void
    let onOpenAccounts: () -> Void
    let onAddTransaction: () -> Void

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository, onAddAccount: @escaping () -> Void, onOpenAccounts: @escaping () -> Void, onAddTransaction: @escaping () -> Void) {
        _model = State(initialValue: DashboardViewModel(repository: repository))
        self.onAddAccount = onAddAccount
        self.onOpenAccounts = onOpenAccounts
        self.onAddTransaction = onAddTransaction
    }

    private var selectedSummary: DashboardCurrencySummary? {
        model.summaries.first(where: { $0.currency.code == (selectedCurrencyCode ?? model.summaries.first?.currency.code) }) ?? model.summaries.first
    }
    private var reportMonths: [ReportMonth] {
        guard let currency = selectedSummary?.currency else { return [] }
        return model.months(year: selectedYear, currency: currency, calendar: .current)
    }
    private var totalIncome: Decimal { reportMonths.reduce(.zero) { $0 + $1.income } }
    private var totalExpenses: Decimal { reportMonths.reduce(.zero) { $0 + $1.expenses } }
    private var previousMonths: [ReportMonth] {
        guard let currency = selectedSummary?.currency else { return [] }
        return model.months(year: selectedYear - 1, currency: currency, calendar: .current)
    }
    private var previousIncome: Decimal { previousMonths.reduce(.zero) { $0 + $1.income } }
    private var previousExpenses: Decimal { previousMonths.reduce(.zero) { $0 + $1.expenses } }
    private var categorySpending: [CategorySpend] {
        guard let currency = selectedSummary?.currency else { return [] }
        return model.categorySpending(year: selectedYear, currency: currency, calendar: .current)
    }
    private var reportSectionOrder: [ReportSection] {
        var sections = sectionOrderRaw.split(separator: ",").compactMap { ReportSection(rawValue: String($0)) }
        for section in ReportSection.allCases where !sections.contains(section) { sections.append(section) }
        return sections
    }
    private var hiddenSections: Set<ReportSection> {
        Set(hiddenSectionsRaw.split(separator: ",").compactMap { ReportSection(rawValue: String($0)) })
    }

    var body: some View {
        Group {
            if model.accounts.isEmpty && model.recentPostings.isEmpty {
                ContentUnavailableView {
                    Label("dashboard.empty.title", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("dashboard.empty.description")
                } actions: {
                    HStack {
                        Button("accounts.add", action: onAddAccount).buttonStyle(.borderedProminent)
                        Button("transactions.add", action: onAddTransaction).buttonStyle(.bordered)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(visibleReportSections) { section in reportSection(section) }
                    }
                    .padding(20)
                    .frame(maxWidth: 1280, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.secondary.opacity(0.06))
                .refreshable { model.reload() }
            }
        }
        .navigationTitle("navigation.dashboard")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { isConfigurationPresented = true } label: { Label("dashboard.customize", systemImage: "slider.horizontal.3") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddTransaction) { Label("transactions.add", systemImage: "plus") }
            }
        }
        .alert("common.error-title", isPresented: errorPresented) {
            Button("common.done", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "common.unknown-error") }
        .sheet(isPresented: $isConfigurationPresented) {
            ReportSectionEditorView(order: reportSectionOrder, hidden: hiddenSections) { order, hidden in
                sectionOrderRaw = order.map(\.rawValue).joined(separator: ",")
                hiddenSectionsRaw = ReportSection.allCases.filter { hidden.contains($0) }.map(\.rawValue).joined(separator: ",")
            }
        }
        .onAppear(perform: model.reload)
    }

    private var visibleReportSections: [ReportSection] {
        reportSectionOrder.filter { !hiddenSections.contains($0) }
    }

    @ViewBuilder private func reportSection(_ section: ReportSection) -> some View {
        switch section {
        case .header: reportHeader
        case .metrics: metricCards
        case .cashflow: reportControls; cashflowCard
        case .categories: categoryCard
        case .daily: dailyCard
        case .accounts:
            chartCard(title: "dashboard.report.accounts", symbol: "building.columns") {
                accountRows
                Button("common.view-all", action: onOpenAccounts).font(.caption)
            }
        case .comparison: comparisonTables
        case .recent: recentTransactions
        }
    }

    private var reportHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.report.eyebrow").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Text("dashboard.report.title").font(.largeTitle.bold())
                Text(String(selectedYear)).font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Label("dashboard.report.updated", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 10).background(.thinMaterial, in: Capsule())
        }
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.06)))
    }

    private var reportControls: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("dashboard.report.title").font(.title2.bold())
            Spacer()
            currencyPicker
            yearStepper
        }
    }

    private var cashflowCard: some View {
        chartCard(title: "dashboard.report.cashflow", symbol: "chart.bar.xaxis") {
            cashflowChart
        }
    }

    private var comparisonTables: some View {
        VStack(alignment: .leading, spacing: 14) {
            comparisonTable(title: "dashboard.report.income-summary", kind: .income)
            comparisonTable(title: "dashboard.report.spending-summary", kind: .expense)
        }
    }

    private func comparisonTable(title: LocalizedStringKey, kind: CategoryKind) -> some View {
        let rows = selectedSummary.map { model.comparisonRows(year: selectedYear, currency: $0.currency, kind: kind, calendar: .current) } ?? []
        return chartCard(title: title, symbol: kind == .expense ? "arrow.up.right" : "arrow.down.left") {
            HStack {
                Text("dashboard.report.total").fontWeight(.semibold)
                Spacer()
                Text(String(selectedYear - 1)).foregroundStyle(.secondary)
                Text(String(selectedYear)).foregroundStyle(.secondary)
            }
            .font(.caption.monospacedDigit())
            HStack {
                Text("dashboard.report.total").fontWeight(.semibold)
                Spacer()
                Text((kind == .expense ? previousExpenses : previousIncome).formatted(.currency(code: selectedSummary?.currency.code ?? "EUR")))
                Text((kind == .expense ? totalExpenses : totalIncome).formatted(.currency(code: selectedSummary?.currency.code ?? "EUR")))
            }
            .font(.caption.monospacedDigit())
            Divider()
            ForEach(rows.prefix(8)) { row in
                HStack(spacing: 8) {
                    Circle().fill(kind == .expense ? categoryColor(row.id) : .green.opacity(0.72)).frame(width: 9, height: 9)
                    Text(row.name).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.previous.formatted(.currency(code: selectedSummary?.currency.code ?? "EUR")))
                    Text(row.current.formatted(.currency(code: selectedSummary?.currency.code ?? "EUR"))).fontWeight(.medium)
                }
                .font(.caption.monospacedDigit())
            }
        }
    }

    private var cashflowChart: some View {
        Chart(yearFlowMarks) { mark in
            BarMark(x: .value("Month", mark.month), y: .value("Amount", mark.amount))
                .foregroundStyle(by: .value("Type", mark.kind))
                .position(by: .value("Year", String(mark.year)))
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .chartForegroundStyleScale([
            String(localized: "dashboard.chart.income"): Color.green,
            String(localized: "dashboard.chart.expenses"): Color.red.opacity(0.6)
        ])
        .chartXAxis {
            AxisMarks(values: Array(1...12)) { value in
                AxisValueLabel {
                    if let month = value.as(Int.self), let date = Calendar.current.date(from: DateComponents(year: selectedYear, month: month, day: 1)) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                    }
                }
            }
        }
        .frame(height: 230)
    }

    private var yearFlowMarks: [YearFlowMark] {
        let years = [(selectedYear - 1, previousMonths), (selectedYear, reportMonths)]
        return years.flatMap { year, months in
            months.flatMap { month in
                let index = Calendar.current.component(.month, from: month.date)
                return [
                    YearFlowMark(id: "\(year)-\(index)-income", month: index, year: year, kind: String(localized: "dashboard.chart.income"), amount: month.incomeValue),
                    YearFlowMark(id: "\(year)-\(index)-expense", month: index, year: year, kind: String(localized: "dashboard.chart.expenses"), amount: -month.expensesValue)
                ]
            }
        }
    }

    private var categoryCard: some View {
        chartCard(title: "dashboard.report.categories", symbol: "chart.pie") {
            if categorySpending.isEmpty {
                ContentUnavailableView("dashboard.no-chart-data", systemImage: "chart.pie", description: Text("dashboard.no-data"))
                    .frame(height: 190)
            } else {
                categoryBreakdown
            }
        }
    }

    private var dailyCard: some View {
        chartCard(title: "dashboard.report.daily", symbol: "chart.xyaxis.line") {
            dailySpendingChart
        }
    }

    @ViewBuilder private var accountRows: some View {
        if model.accounts.isEmpty {
            Text("dashboard.no-data").foregroundStyle(.secondary)
        } else {
            ForEach(model.accounts) { account in
                accountRow(account)
                if account.id != model.accounts.last?.id { Divider() }
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack {
            Label(account.name, systemImage: account.type.isLiability ? "creditcard" : "building.columns")
            Spacer()
            if let amount = model.balances[account.id] {
                Text(accountAmount(amount)).monospacedDigit()
            }
        }
    }

    private var metricCards: some View {
        let columns = [GridItem(.adaptive(minimum: 190), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            metricCard(title: "dashboard.chart.income", value: totalIncome, symbol: "arrow.down.left", tint: .green)
            metricCard(title: "dashboard.chart.expenses", value: totalExpenses, symbol: "arrow.up.right", tint: .red)
            metricCard(title: "dashboard.report.net", value: totalIncome - totalExpenses, symbol: "plus.forwardslash.minus", tint: totalIncome >= totalExpenses ? .green : .orange)
        }
    }

    private func metricCard(title: LocalizedStringKey, value: Decimal, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 42, height: 42).background(tint.opacity(0.12), in: Circle())
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: selectedSummary?.currency.code ?? "EUR")))
                .font(.title2.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.06)))
    }

    private func chartCard<Content: View>(title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.06)))
    }

    private var currencyPicker: some View {
        Group {
            if model.summaries.count > 1 {
                Picker("Currency", selection: Binding(get: { selectedSummary?.currency.code ?? "EUR" }, set: { selectedCurrencyCode = $0 })) {
                    ForEach(model.summaries) { summary in Text(summary.currency.code).tag(summary.currency.code) }
                }.pickerStyle(.menu)
            }
        }
    }

    private var yearStepper: some View {
        HStack(spacing: 10) {
            Button { selectedYear -= 1 } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            Text(String(selectedYear)).font(.subheadline.monospacedDigit())
            Button { selectedYear += 1 } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 7).background(.background, in: Capsule())
    }

    private var dailySpending: [DailySpendPoint] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: .now), let currency = selectedSummary?.currency else { return [] }
        let days = Calendar.current.range(of: .day, in: .month, for: .now) ?? 1..<2
        return days.map { day in
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: interval.start) ?? interval.start
            let amount = model.postings.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: date) && $0.entries.first?.money.currency == currency }.reduce(Decimal.zero) { total, posting in
                switch posting.kind {
                case .expense: return total + posting.entries.filter { $0.accountKind == .expense && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
                case .refund: return total - posting.entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
                case .adjustment: return total + posting.entries.filter { $0.accountKind == .expense && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
                case .reversal:
                    guard let original = model.postings.first(where: { $0.id == posting.relatedPostingID }), original.kind == .adjustment else { return total }
                    return total - posting.entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
                default: return total
                }
            }
            return DailySpendPoint(day: day, amount: NSDecimalNumber(decimal: amount).doubleValue)
        }
    }

    private var recentTransactions: some View {
        chartCard(title: "dashboard.section.recent", symbol: "clock.arrow.circlepath") {
            if model.recentPostings.isEmpty { Text("dashboard.no-recent-transactions").foregroundStyle(.secondary) }
            else {
                ForEach(model.recentPostings) { posting in
                    HStack {
                        Label(posting.description, systemImage: posting.kind.symbol).lineLimit(1)
                        Spacer()
                        if let amount = posting.primaryAmount {
                            Text(amount.amount.formatted(.currency(code: amount.currency.code))).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func categoryColor(_ id: UUID) -> Color {
        guard let index = categorySpending.firstIndex(where: { $0.id == id }) else { return .gray }
        let palette: [Color] = [.orange, .blue, .purple, .green, .pink, .teal]
        return palette[index % palette.count]
    }

    private var categoryBreakdown: some View {
        HStack(spacing: 12) {
            categoryDonut
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(categorySpending.prefix(6))) { item in
                    categoryRow(item)
                }
            }
        }
    }

    private var categoryDonut: some View {
        Chart(Array(categorySpending.prefix(6))) { item in
            SectorMark(
                angle: .value("Amount", NSDecimalNumber(decimal: item.amount).doubleValue),
                innerRadius: .ratio(0.58),
                angularInset: 2
            )
            .foregroundStyle(categoryColor(item.id))
        }
        .chartLegend(.hidden)
        .frame(width: 150, height: 180)
    }

    private var dailySpendingChart: some View {
        Chart(dailySpending) { point in
            AreaMark(x: .value("Day", point.day), y: .value("Amount", point.amount))
                .foregroundStyle(Color.teal.opacity(0.12).gradient)
            LineMark(x: .value("Day", point.day), y: .value("Amount", point.amount))
                .foregroundStyle(Color.teal)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
        }
        .chartLegend(.hidden)
        .frame(height: 190)
    }

    private func categoryRow(_ item: CategorySpend) -> some View {
        HStack(spacing: 6) {
            Circle().fill(categoryColor(item.id)).frame(width: 8, height: 8)
            Text(item.name).lineLimit(1)
            Spacer(minLength: 3)
            Text(categoryAmount(item.amount)).monospacedDigit()
        }
        .font(.caption)
    }

    private func categoryAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: selectedSummary?.currency.code ?? "EUR"))
    }

    private func accountAmount(_ amount: Money) -> String {
        amount.amount.formatted(.currency(code: amount.currency.code))
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

private struct DashboardWidgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var order: [DashboardWidget]
    @State private var hidden: Set<DashboardWidget>
    let onSave: ([DashboardWidget], Set<DashboardWidget>) -> Void

    init(order: [DashboardWidget], hidden: Set<DashboardWidget>, onSave: @escaping ([DashboardWidget], Set<DashboardWidget>) -> Void) {
        _order = State(initialValue: order)
        _hidden = State(initialValue: hidden)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(order, id: \.self) { widget in
                    Toggle(widget.localizedKey, isOn: Binding(
                        get: { !hidden.contains(widget) },
                        set: { isVisible in
                            if isVisible { hidden.remove(widget) } else { hidden.insert(widget) }
                        }
                    ))
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("dashboard.customize-title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        onSave(order, hidden)
                        dismiss()
                    }
                }
            }
            .dashboardReorderMode()
        }
        .frame(minWidth: 320, minHeight: 300)
    }
}

private struct ReportSectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var order: [ReportSection]
    @State private var hidden: Set<ReportSection>
    let onSave: ([ReportSection], Set<ReportSection>) -> Void

    init(order: [ReportSection], hidden: Set<ReportSection>, onSave: @escaping ([ReportSection], Set<ReportSection>) -> Void) {
        _order = State(initialValue: order)
        _hidden = State(initialValue: hidden)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { section in
                    Toggle(section.title, isOn: Binding(
                        get: { !hidden.contains(section) },
                        set: { isVisible in
                            if isVisible { hidden.remove(section) } else { hidden.insert(section) }
                        }
                    ))
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("dashboard.customize-title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { onSave(order, hidden); dismiss() }
                }
            }
            .dashboardReorderMode()
        }
        .frame(minWidth: 320, minHeight: 300)
    }
}

private extension ReportSection {
    var title: LocalizedStringKey {
        switch self {
        case .header: "dashboard.report.header"
        case .metrics: "dashboard.widget.overview"
        case .cashflow: "dashboard.report.cashflow"
        case .categories: "dashboard.report.categories"
        case .daily: "dashboard.report.daily"
        case .accounts: "dashboard.report.accounts"
        case .comparison: "dashboard.report.comparison"
        case .recent: "dashboard.widget.recent"
        }
    }
}

extension View {
    @ViewBuilder func financeListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }
}


private extension View {
    @ViewBuilder func dashboardReorderMode() -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }
}
