import Foundation

public enum CategoryKind: String, Codable, CaseIterable, Sendable {
    case income, salary, expense

    public var ledgerKind: LedgerAccountKind {
        self == .expense ? .expense : .income
    }
}

public enum CategoryError: Error, Equatable {
    case emptyName
}

public struct Category: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public let kind: CategoryKind
    public private(set) var parentID: UUID?
    public private(set) var isArchived: Bool
    public let createdAt: Date
    public private(set) var updatedAt: Date


    public mutating func rename(to name: String) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw CategoryError.emptyName }
        self.name = cleanedName
        updatedAt = .now
    }

    public mutating func move(under parentID: UUID?) {
        self.parentID = parentID
        updatedAt = .now
    }

    public mutating func setArchived(_ isArchived: Bool) {
        self.isArchived = isArchived
        updatedAt = .now
    }

    public init(
        id: UUID = UUID(), name: String, kind: CategoryKind,
        parentID: UUID? = nil, isArchived: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now
    ) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw CategoryError.emptyName }
        self.id = id
        self.name = cleanedName
        self.kind = kind
        self.parentID = parentID
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


extension Category {
    private enum CodingKeys: String, CodingKey { case id, name, kind, parentID, isArchived, createdAt, updatedAt }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: container.decode(String.self, forKey: .name),
            kind: container.decode(CategoryKind.self, forKey: .kind),
            parentID: container.decodeIfPresent(UUID.self, forKey: .parentID),
            isArchived: container.decode(Bool.self, forKey: .isArchived),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            updatedAt: container.decode(Date.self, forKey: .updatedAt)
        )
    }
}
