import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer

    init() throws {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
    }
}
