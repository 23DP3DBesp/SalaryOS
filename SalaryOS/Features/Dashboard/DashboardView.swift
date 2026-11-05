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

@MainActor
@Observable
private final class DashboardViewModel {
    private let loadSnapshot: LoadDashboardSnapshot
    var accounts: [Account] = []
    var balances: [UUID: Money] = [:]
    var summaries: [DashboardCurrencySummary] = []
    var recentPostings: [LedgerPosting] = []
    var errorMessage: String?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository) {
        loadSnapshot = LoadDashboardSnapshot(accountRepository: repository, ledgerRepository: repository)
    }

    func reload() {
        do {
            let snapshot = try loadSnapshot.execute()
            accounts = snapshot.accounts.map(\.account)
            balances = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.account.id, $0.balance) })
            summaries = snapshot.currencies
            recentPostings = snapshot.recentPostings
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DashboardView: View {
    @State private var model: DashboardViewModel
    @AppStorage("dashboard.widgetOrder") private var widgetOrderRaw = "overview,accounts,cashFlow,recent"
    @AppStorage("dashboard.hiddenWidgets") private var hiddenWidgetsRaw = ""
    @State private var isConfigurationPresented = false
    let onAddAccount: () -> Void
    let onOpenAccounts: () -> Void
    let onAddTransaction: () -> Void

    init(
        repository: any AccountRepository & CategoryRepository & LedgerRepository,
        onAddAccount: @escaping () -> Void,
        onOpenAccounts: @escaping () -> Void,
        onAddTransaction: @escaping () -> Void
    ) {
        _model = State(initialValue: DashboardViewModel(repository: repository))
        self.onAddAccount = onAddAccount
        self.onOpenAccounts = onOpenAccounts
        self.onAddTransaction = onAddTransaction
    }

    private var widgetOrder: [DashboardWidget] {
        var widgets = widgetOrderRaw.split(separator: ",").compactMap { DashboardWidget(rawValue: String($0)) }
        for widget in DashboardWidget.allCases where !widgets.contains(widget) { widgets.append(widget) }
        return widgets
    }

    private var hiddenWidgets: Set<DashboardWidget> {
        Set(hiddenWidgetsRaw.split(separator: ",").compactMap { DashboardWidget(rawValue: String($0)) })
    }

    private var visibleWidgets: [DashboardWidget] {
        widgetOrder.filter { !hiddenWidgets.contains($0) }
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
                        Button("accounts.add") { onAddAccount() }
                            .buttonStyle(.borderedProminent)
                        Button("transactions.add") { onAddTransaction() }
                            .buttonStyle(.bordered)
                    }
                }
            } else if visibleWidgets.isEmpty {
                ContentUnavailableView {
                    Label("dashboard.no-widgets.title", systemImage: "square.grid.2x2")
                } description: {
                    Text("dashboard.no-widgets.description")
                } actions: {
                    Button("dashboard.customize") { isConfigurationPresented = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(visibleWidgets) { widget in
                        widgetSection(widget)
                    }
                }
                .financeListStyle()
                .refreshable { model.reload() }
            }
        }
        .navigationTitle("navigation.dashboard")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { isConfigurationPresented = true } label: {
                    Label("dashboard.customize", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddTransaction) {
                    Label("transactions.add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isConfigurationPresented) {
            DashboardWidgetEditorView(order: widgetOrder, hidden: hiddenWidgets) { order, hidden in
                widgetOrderRaw = order.map(\.rawValue).joined(separator: ",")
                hiddenWidgetsRaw = DashboardWidget.allCases.filter { hidden.contains($0) }.map(\.rawValue).joined(separator: ",")
            }
        }
        .alert("common.error-title", isPresented: errorPresented) {
            Button("common.done", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "common.unknown-error")
        }
        .onAppear(perform: model.reload)
    }

    @ViewBuilder
    private func widgetSection(_ widget: DashboardWidget) -> some View {
        switch widget {
        case .overview:
            Section("dashboard.section.overview") {
                if model.summaries.isEmpty {
                    Text("dashboard.no-data").foregroundStyle(.secondary)
                }
                ForEach(model.summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        if summary.hasBalance {
                            LabeledContent("dashboard.total-balance") {
                                Text(summary.balance.formatted(.currency(code: summary.currency.code)))
                                    .font(.headline.monospacedDigit())
                            }
                        }
                        if summary.hasCashflow {
                            LabeledContent("dashboard.income-this-month") {
                                Text(summary.incomeThisMonth.formatted(.currency(code: summary.currency.code)))
                                    .monospacedDigit().foregroundStyle(.green)
                            }
                            LabeledContent("dashboard.expenses-this-month") {
                                Text(summary.expensesThisMonth.formatted(.currency(code: summary.currency.code)))
                                    .monospacedDigit().foregroundStyle(summary.expensesThisMonth > .zero ? .red : .primary)
                            }
                        } else {
                            Text("dashboard.no-cashflow")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        case .accounts:
            Section {
                ForEach(model.accounts) { account in
                    HStack {
                        Label(account.name, systemImage: account.type.isLiability ? "creditcard" : "building.columns")
                        Spacer()
                        if let balance = model.balances[account.id] {
                            Text(balance.amount.formatted(.currency(code: balance.currency.code)))
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("dashboard.section.accounts")
                    Spacer()
                    Button("common.view-all", action: onOpenAccounts).font(.caption)
                }
            }
        case .cashFlow:
            Section("dashboard.section.cashflow") {
                let histories = model.summaries.filter { $0.history.contains { $0.income != .zero || $0.expenses != .zero } }
                if histories.isEmpty {
                    Text("dashboard.no-chart-data").foregroundStyle(.secondary)
                }
                ForEach(histories) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.currency.code).font(.headline)
                        Chart(summary.history) { month in
                            BarMark(
                                x: .value(String(localized: "dashboard.chart.month"), month.month, unit: .month),
                                y: .value(String(localized: "dashboard.chart.income"), month.income)
                            )
                            .foregroundStyle(.green)
                            .position(by: .value(String(localized: "dashboard.chart.series"), String(localized: "transaction-kind.income")))
                            BarMark(
                                x: .value(String(localized: "dashboard.chart.month"), month.month, unit: .month),
                                y: .value(String(localized: "dashboard.chart.expenses"), month.expenses)
                            )
                            .foregroundStyle(.red)
                            .position(by: .value(String(localized: "dashboard.chart.series"), String(localized: "transaction-kind.expense")))
                        }
                        .chartLegend(.hidden)
                        .frame(height: 170)
                        HStack(spacing: 16) {
                            Label("transaction-kind.income", systemImage: "circle.fill").foregroundStyle(.green)
                            Label("transaction-kind.expense", systemImage: "circle.fill").foregroundStyle(.red)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        case .recent:
            Section("dashboard.section.recent") {
                if model.recentPostings.isEmpty {
                    Text("dashboard.no-recent-transactions").foregroundStyle(.secondary)
                } else {
                    ForEach(model.recentPostings) { posting in
                        HStack {
                            Label(posting.description, systemImage: posting.kind.symbol).lineLimit(1)
                            Spacer()
                            if let amount = posting.primaryAmount {
                                Text(amount.amount.formatted(.currency(code: amount.currency.code)))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
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
