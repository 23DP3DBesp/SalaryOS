import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard
    case accounts
    case transactions
    case salary
    case budgets
    case debts
    case savings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "navigation.dashboard"
        case .accounts: "navigation.accounts"
        case .transactions: "navigation.transactions"
        case .salary: "navigation.salary"
        case .budgets: "navigation.budgets"
        case .debts: "navigation.debts"
        case .savings: "navigation.savings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .accounts: "building.columns"
        case .transactions: "list.bullet.rectangle"
        case .salary: "eurosign.circle"
        case .budgets: "chart.bar.xaxis"
        case .debts: "person.text.rectangle"
        case .savings: "target"
        }
    }
}

struct AppRouter: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository
    @State private var selectedRoute: AppRoute = .dashboard
    @State private var isAccountEditorPresented = false
    @State private var isTransactionEditorPresented = false

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
        }
        #else
        NavigationSplitView {
            List(AppRoute.allCases, selection: $selectedRoute) { route in
                Label(route.title, systemImage: route.symbol)
                    .tag(route)
            }
            .listStyle(.sidebar)
            .navigationTitle(AppConfiguration.displayName)
        } detail: {
            switch selectedRoute {
            case .dashboard:
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
            }
        }
        #endif
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
