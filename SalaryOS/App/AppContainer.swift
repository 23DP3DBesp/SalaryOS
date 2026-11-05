import SalaryOSDomain
import SalaryOSPersistence
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let financeRepository: any AccountRepository & CategoryRepository & LedgerRepository

    init() throws {
        let persistenceStack = try FinancePersistenceStack()
        modelContainer = persistenceStack.modelContainer
        financeRepository = persistenceStack.repository
    }
}
