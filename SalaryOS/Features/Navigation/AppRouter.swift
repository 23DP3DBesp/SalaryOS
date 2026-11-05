import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard
    case accounts
    case transactions
    case salary

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "navigation.dashboard"
        case .accounts: "navigation.accounts"
        case .transactions: "navigation.transactions"
        case .salary: "navigation.salary"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .accounts: "building.columns"
        case .transactions: "list.bullet.rectangle"
        case .salary: "eurosign.circle"
        }
    }
}

struct AppRouter: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository
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
