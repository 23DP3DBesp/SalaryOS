import Foundation

public enum RepositoryError: Error, Equatable {
    case duplicateIdentifier(UUID)
    case accountNotFound(UUID)
    case categoryNotFound(UUID)
    case accountDefinitionConflict(UUID)
    case categoryDefinitionConflict(UUID)
    case invalidLedgerReference(UUID)
    case archivedAccount(UUID)
    case archivedCategory(UUID)
    case invalidRefundReference(UUID)
    case refundExceedsOriginal(UUID)
}

@MainActor
public protocol AccountRepository: AnyObject {
    func save(_ account: Account) throws
    func account(id: UUID) throws -> Account?
    func accounts(includeArchived: Bool) throws -> [Account]
}

@MainActor
public protocol CategoryRepository: AnyObject {
    func save(_ category: Category) throws
    func category(id: UUID) throws -> Category?
    func categories(kind: CategoryKind?, includeArchived: Bool) throws -> [Category]
}

@MainActor
public protocol LedgerRepository: AnyObject {
    func post(_ posting: LedgerPosting) throws
    func posting(id: UUID) throws -> LedgerPosting?
    func postings(from start: Date?, through end: Date?) throws -> [LedgerPosting]
    func balance(for account: Account) throws -> Money
}
