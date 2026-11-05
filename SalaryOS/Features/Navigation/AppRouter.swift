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

struct AppRouter: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository & WorkTimeRepository & ScheduledOperationRepository
    @State private var selectedRoute: AppRoute = .dashboard
    @State private var isAccountEditorPresented = false
    @State private var isTransactionEditorPresented = false
    @State private var sidebarAccounts: [Account] = []
    @State private var sidebarBalances: [UUID: Money] = [:]

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedRoute) {
            NavigationStack {
                dashboard
            }
            .tabItem { Label(AppRoute.dashboard.title, systemImage: AppRoute.dashboard.symbol) }
            .tag(AppRoute.dashboard)

            NavigationStack {
                AccountsView(repository: repository, isEditorPresented: $isAccountEditorPresented)
            }
            .tabItem { Label(AppRoute.accounts.title, systemImage: AppRoute.accounts.symbol) }
            .tag(AppRoute.accounts)

            NavigationStack {
                TransactionsView(repository: repository, isEditorPresented: $isTransactionEditorPresented)
            }
            .tabItem { Label(AppRoute.transactions.title, systemImage: AppRoute.transactions.symbol) }
            .tag(AppRoute.transactions)

            NavigationStack { SalaryView(repository: repository) }
                .tabItem { Label(AppRoute.salary.title, systemImage: AppRoute.salary.symbol) }
                .tag(AppRoute.salary)

            NavigationStack { BudgetsView(repository: repository) }
                .tabItem { Label(AppRoute.budgets.title, systemImage: AppRoute.budgets.symbol) }
                .tag(AppRoute.budgets)

            NavigationStack { DebtsView(repository: repository) }
                .tabItem { Label(AppRoute.debts.title, systemImage: AppRoute.debts.symbol) }
                .tag(AppRoute.debts)

            NavigationStack { SavingsGoalsView(repository: repository) }
                .tabItem { Label(AppRoute.savings.title, systemImage: AppRoute.savings.symbol) }
                .tag(AppRoute.savings)

            NavigationStack { LoansView(repository: repository) }
                .tabItem { Label(AppRoute.loans.title, systemImage: AppRoute.loans.symbol) }
                .tag(AppRoute.loans)

            NavigationStack { WorkTimeView(repository: repository) }
                .tabItem { Label(AppRoute.workTime.title, systemImage: AppRoute.workTime.symbol) }
                .tag(AppRoute.workTime)

            NavigationStack { CalendarView(repository: repository) }
                .tabItem { Label(AppRoute.calendar.title, systemImage: AppRoute.calendar.symbol) }
                .tag(AppRoute.calendar)
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

    private var dashboard: some View {
        DashboardView(
            repository: repository,
            onAddAccount: {
                selectedRoute = .accounts
                isAccountEditorPresented = true
            },
            onOpenAccounts: {
                selectedRoute = .accounts
            },
            onAddTransaction: {
                selectedRoute = .transactions
                isTransactionEditorPresented = true
            }
        )
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
