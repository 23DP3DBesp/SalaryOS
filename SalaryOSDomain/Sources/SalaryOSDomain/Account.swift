import Foundation

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case current, savings, cash, creditCard, investment, loan, other

    public var isLiability: Bool {
        self == .creditCard || self == .loan
    }
}

public enum AccountError: Error, Equatable {
    case emptyName
    case openingBalanceCurrencyMismatch
    case liabilityOpeningBalanceMustNotBePositive
    case assetOpeningBalanceMustNotBeNegative
}

public struct Account: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public let type: AccountType
    public let currency: Currency
    public let openingBalance: Money
    public var institution: String?
    public var details: String?
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool


    public mutating func rename(to name: String) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw AccountError.emptyName }
        self.name = cleanedName
        updatedAt = .now
    }

    public mutating func updateDetails(institution: String?, details: String?) {
        self.institution = institution
        self.details = details
        updatedAt = .now
    }

    public mutating func setArchived(_ isArchived: Bool) {
        self.isArchived = isArchived
        updatedAt = .now
    }

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: Currency,
        openingBalance: Money? = nil,
        institution: String? = nil,
        details: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false
    ) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw AccountError.emptyName }
        let balance = try openingBalance ?? Money(.zero, currency: currency)
        guard balance.currency == currency else { throw AccountError.openingBalanceCurrencyMismatch }
        if type.isLiability, balance.amount > .zero {
            throw AccountError.liabilityOpeningBalanceMustNotBePositive
        }
        if !type.isLiability, balance.amount < .zero {
            throw AccountError.assetOpeningBalanceMustNotBeNegative
        }
        self.id = id
        self.name = cleanedName
        self.type = type
        self.currency = currency
        self.openingBalance = balance
        self.institution = institution
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }
}


extension Account {
    private enum CodingKeys: String, CodingKey {
        case id, name, type, currency, openingBalance, institution, details, createdAt, updatedAt, isArchived
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: container.decode(String.self, forKey: .name),
            type: container.decode(AccountType.self, forKey: .type),
            currency: container.decode(Currency.self, forKey: .currency),
            openingBalance: container.decode(Money.self, forKey: .openingBalance),
            institution: container.decodeIfPresent(String.self, forKey: .institution),
            details: container.decodeIfPresent(String.self, forKey: .details),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            updatedAt: container.decode(Date.self, forKey: .updatedAt),
            isArchived: container.decode(Bool.self, forKey: .isArchived)
        )
    }
}
