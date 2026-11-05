import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "navigation.dashboard"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        }
    }
}

struct AppRouter: View {
    @State private var selectedRoute: AppRoute? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(AppRoute.allCases, selection: $selectedRoute) { route in
                Label(route.title, systemImage: route.symbol)
                    .tag(route as AppRoute?)
            }
            .listStyle(.sidebar)
            .navigationTitle(AppConfiguration.displayName)
        } detail: {
            switch selectedRoute ?? .dashboard {
            case .dashboard:
                DashboardView()
            }
        }
    }
}
