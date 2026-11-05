import SwiftUI
import SwiftData

@main
struct SalaryOSApp: App {
    private let startupResult: Result<AppContainer, Error>

    init() {
        do {
            startupResult = .success(try AppContainer())
        } catch {
            startupResult = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startupResult {
            case .success(let appContainer):
                AppRouter(repository: appContainer.financeRepository)
                    .modelContainer(appContainer.modelContainer)
            case .failure(let error):
                StorageFailureView(message: error.localizedDescription)
            }
        }
        #if os(macOS)
        .commands {
            SidebarCommands()
        }
        #endif
    }
}

private struct StorageFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("startup.storage-error.title", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("startup.storage-error.description")
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
    }
}
