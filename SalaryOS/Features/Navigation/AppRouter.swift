import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard
    case incomeExpenses
    case accounts
    case transactions
    case salary
    case budgets
    case debts
    case savings
    case loans
    case workTime
    case calendar

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "navigation.dashboard"
        case .incomeExpenses: "dashboard.report.title"
        case .accounts: "navigation.accounts"
        case .transactions: "navigation.transactions"
        case .salary: "navigation.salary"
        case .budgets: "navigation.budgets"
        case .debts: "navigation.debts"
        case .savings: "navigation.savings"
        case .loans: "navigation.loans"
        case .workTime: "navigation.work-time"
        case .calendar: "navigation.calendar"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .incomeExpenses: "chart.bar.xaxis"
        case .accounts: "building.columns"
        case .transactions: "list.bullet.rectangle"
        case .salary: "eurosign.circle"
        case .budgets: "chart.bar.xaxis"
        case .debts: "person.text.rectangle"
        case .savings: "target"
        case .loans: "creditcard"
        case .workTime: "clock"
        case .calendar: "calendar"
        }
    }
}

private enum AppTab: Hashable {
    case dashboard, accounts, transactions, more
}

struct AppRouter: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository & SalaryRepository & WorkTimeRepository & ScheduledOperationRepository
    @State private var selectedRoute: AppRoute = .dashboard
    @State private var selectedTab: AppTab = .dashboard
    @State private var isAccountEditorPresented = false
    @State private var isTransactionEditorPresented = false
    @State private var sidebarAccounts: [Account] = []
    @State private var sidebarBalances: [UUID: Money] = [:]

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                dashboard
            }
            .tabItem { Label(AppRoute.dashboard.title, systemImage: AppRoute.dashboard.symbol) }
            .tag(AppTab.dashboard)

            NavigationStack {
                AccountsView(repository: repository, isEditorPresented: $isAccountEditorPresented)
            }
            .tabItem { Label(AppRoute.accounts.title, systemImage: AppRoute.accounts.symbol) }
            .tag(AppTab.accounts)

            NavigationStack {
                TransactionsView(repository: repository, isEditorPresented: $isTransactionEditorPresented)
            }
            .tabItem { Label(AppRoute.transactions.title, systemImage: AppRoute.transactions.symbol) }
            .tag(AppTab.transactions)

            NavigationStack {
                MoreNavigationView { route in AnyView(routeContent(route)) }
            }
            .tabItem { Label("navigation.more", systemImage: "ellipsis.circle") }
            .tag(AppTab.more)
        }
        #else
        NavigationSplitView {
            List(selection: $selectedRoute) {
                Section("sidebar.overview") {
                    routeRow(.dashboard)
                }
                Section {
                    ForEach(sidebarAccounts) { account in
                        HStack(spacing: 8) {
                            Image(systemName: account.type.isLiability ? "creditcard" : "building.columns")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).lineLimit(1)
                                Text(account.type.sidebarTitle).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            if let balance = sidebarBalances[account.id] {
                                Text(balance.amount.formatted(.currency(code: balance.currency.code)))
                                    .font(.caption.monospacedDigit()).lineLimit(1)
                            }
                        }
                        .tag(AppRoute.accounts)
                    }
                } header: {
                    HStack {
                        Text("sidebar.accounts")
                        Spacer()
                        Button {
                            selectedRoute = .accounts
                            isAccountEditorPresented = true
                        } label: {
                            Image(systemName: "plus").font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .help("accounts.add")
                    }
                }
                Section("sidebar.activity") {
                    routeRow(.transactions)
                }
                Section("sidebar.planning") {
                    routeRow(.salary)
                    routeRow(.budgets)
                    routeRow(.debts)
                    routeRow(.savings)
                    routeRow(.loans)
                }
                Section("sidebar.reports") {
                    routeRow(.incomeExpenses)
                    routeRow(.workTime)
                    routeRow(.calendar)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(AppConfiguration.displayName)
            .onAppear(perform: reloadSidebarAccounts)
        } detail: {
            switch selectedRoute {
            case .dashboard:
                dashboard
            case .incomeExpenses:
                dashboard
            case .accounts:
                AccountsView(repository: repository, isEditorPresented: $isAccountEditorPresented)
            case .transactions:
                TransactionsView(repository: repository, isEditorPresented: $isTransactionEditorPresented)
            case .salary:
                SalaryView(repository: repository)
            case .budgets:
                BudgetsView(repository: repository)
            case .debts:
                DebtsView(repository: repository)
            case .savings:
                SavingsGoalsView(repository: repository)
            case .loans:
                LoansView(repository: repository)
            case .workTime:
                WorkTimeView(repository: repository)
            case .calendar:
                CalendarView(repository: repository)
            }
        }
        #endif
    }

    private func routeRow(_ route: AppRoute) -> some View {
        Label(route.title, systemImage: route.symbol)
            .tag(route)
    }

    private func reloadSidebarAccounts() {
        guard let accounts = try? repository.accounts(includeArchived: false) else { return }
        sidebarAccounts = accounts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        sidebarBalances = Dictionary(uniqueKeysWithValues: sidebarAccounts.compactMap { account in
            guard let balance = try? repository.balance(for: account) else { return nil }
            return (account.id, balance)
        })
    }

    @ViewBuilder private func routeContent(_ route: AppRoute) -> some View {
        switch route {
        case .dashboard, .incomeExpenses: dashboard
        case .accounts: AccountsView(repository: repository, isEditorPresented: $isAccountEditorPresented)
        case .transactions: TransactionsView(repository: repository, isEditorPresented: $isTransactionEditorPresented)
        case .salary: SalaryView(repository: repository)
        case .budgets: BudgetsView(repository: repository)
        case .debts: DebtsView(repository: repository)
        case .savings: SavingsGoalsView(repository: repository)
        case .loans: LoansView(repository: repository)
        case .workTime: WorkTimeView(repository: repository)
        case .calendar: CalendarView(repository: repository)
        }
    }

    private var dashboard: some View {
        DashboardView(
            repository: repository,
            onAddAccount: {
                selectedRoute = .accounts
                selectedTab = .accounts
                isAccountEditorPresented = true
            },
            onOpenAccounts: {
                selectedRoute = .accounts
                selectedTab = .accounts
            },
            onAddTransaction: {
                selectedRoute = .transactions
                selectedTab = .transactions
                isTransactionEditorPresented = true
            }
        )
    }
}

private struct MoreNavigationView: View {
    let destination: (AppRoute) -> AnyView

    var body: some View {
        List {
            Section("sidebar.planning") {
                routeLink(.salary)
                routeLink(.budgets)
                routeLink(.debts)
                routeLink(.savings)
                routeLink(.loans)
            }
            Section("sidebar.reports") {
                routeLink(.incomeExpenses)
                routeLink(.workTime)
                routeLink(.calendar)
            }
        }
        .navigationTitle("navigation.more")
        .navigationDestination(for: AppRoute.self, destination: destination)
    }

    private func routeLink(_ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            Label(route.title, systemImage: route.symbol)
        }
    }
}

private extension AccountType {
    var sidebarTitle: LocalizedStringKey {
        switch self {
        case .current: "account-type.current"
        case .savings: "account-type.savings"
        case .cash: "account-type.cash"
        case .creditCard: "account-type.credit-card"
        case .investment: "account-type.investment"
        case .loan: "account-type.loan"
        case .other: "account-type.other"
        }
    }
}
