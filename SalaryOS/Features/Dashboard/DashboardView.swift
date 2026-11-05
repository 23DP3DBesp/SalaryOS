import SwiftUI

struct DashboardView: View {
    var body: some View {
        ContentUnavailableView {
            Label("dashboard.empty.title", systemImage: "chart.bar.xaxis")
        } description: {
            Text("dashboard.empty.description")
        }
        .navigationTitle("navigation.dashboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
