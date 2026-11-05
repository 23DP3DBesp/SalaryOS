import SalaryOSDomain
import SalaryOSPersistence
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let financeRepository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository

    init() throws {
        let persistenceStack = try FinancePersistenceStack()
        modelContainer = persistenceStack.modelContainer
        financeRepository = persistenceStack.repository
        if try financeRepository.categories(kind: .salary, includeArchived: false).isEmpty {
            try financeRepository.save(Category(name: "Salary", kind: .salary))
        }
    }
}
