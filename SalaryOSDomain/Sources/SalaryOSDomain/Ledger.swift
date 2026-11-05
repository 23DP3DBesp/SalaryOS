import Foundation

public enum LedgerAccountKind: String, Codable, Sendable {
    case asset, liability, income, expense
}

public enum EntrySide: String, Codable, Sendable {
    case debit, credit
}

public enum TransactionKind: String, Codable, CaseIterable, Sendable {
    case income, expense, transfer, refund, adjustment, reversal
}

public enum LedgerError: Error, Equatable {
    case tooFewEntries
    case nonPositiveEntry
    case unbalanced(currency: String)
    case multipleCurrenciesUnsupported
    case invalidAccountKinds(TransactionKind)
    case emptyDescription
    case refundRequiresOriginalExpense
    case reversalRequiresOriginalPosting
    case unsupportedReversal
}

public struct LedgerEntry: Hashable, Codable, Sendable {
    public let accountID: UUID
    public let accountKind: LedgerAccountKind
    public let side: EntrySide
    public let money: Money

    public init(accountID: UUID, accountKind: LedgerAccountKind, side: EntrySide, money: Money) throws {
        guard money.amount > .zero else { throw LedgerError.nonPositiveEntry }
        self.accountID = accountID
        self.accountKind = accountKind
        self.side = side
        self.money = money
    }
}

/// An immutable, balanced double-entry posting. Cross-currency postings are rejected
/// until explicit exchange-rate and FX-clearing entries are implemented.
public struct LedgerPosting: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let kind: TransactionKind
    public let occurredAt: Date
    public let description: String
    public let notes: String?
    public let relatedPostingID: UUID?
    public let scheduledOccurrenceID: String?
    public let entries: [LedgerEntry]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: TransactionKind,
        occurredAt: Date = .now,
        description: String,
        notes: String? = nil,
        relatedPostingID: UUID? = nil,
        scheduledOccurrenceID: String? = nil,
        entries: [LedgerEntry],
        createdAt: Date = .now
    ) throws {
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedDescription.isEmpty else { throw LedgerError.emptyDescription }
        guard entries.count >= 2 else { throw LedgerError.tooFewEntries }
        if kind == .refund, relatedPostingID == nil { throw LedgerError.refundRequiresOriginalExpense }
        if kind == .reversal, relatedPostingID == nil { throw LedgerError.reversalRequiresOriginalPosting }
        let currencies = Set(entries.map { $0.money.currency })
        guard currencies.count == 1 else { throw LedgerError.multipleCurrenciesUnsupported }
        let debitTotal = entries.filter { $0.side == .debit }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let creditTotal = entries.filter { $0.side == .credit }.reduce(Decimal.zero) { $0 + $1.money.amount }
        guard debitTotal == creditTotal else {
            throw LedgerError.unbalanced(currency: currencies.first?.code ?? "")
        }
        guard Self.hasValidShape(kind: kind, entries: entries) else {
            throw LedgerError.invalidAccountKinds(kind)
        }
        self.id = id
        self.kind = kind
        self.occurredAt = occurredAt
        self.description = cleanedDescription
        self.notes = notes
        self.relatedPostingID = relatedPostingID
        self.scheduledOccurrenceID = scheduledOccurrenceID
        self.entries = entries
        self.createdAt = createdAt
    }

    /// Returns the operation's absolute display amount in its single posting currency.
    public var primaryAmount: Money? {
        guard let currency = entries.first?.money.currency else { return nil }
        let amount: Decimal
        switch kind {
        case .income:
            amount = entries.filter { $0.accountKind == .asset && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
        case .expense:
            amount = entries.filter { $0.accountKind == .expense && $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
        case .transfer:
            amount = entries.filter { $0.side == .debit && ($0.accountKind == .asset || $0.accountKind == .liability) }.reduce(.zero) { $0 + $1.money.amount }
        case .refund:
            amount = entries.filter { $0.accountKind == .expense && $0.side == .credit }.reduce(.zero) { $0 + $1.money.amount }
        case .adjustment:
            amount = entries.filter { $0.side == .debit }.reduce(.zero) { $0 + $1.money.amount }
        case .reversal:
            amount = entries.filter { $0.accountKind == .income || $0.accountKind == .expense }.reduce(.zero) { $0 + $1.money.amount }
        }
        return try? Money(amount, currency: currency)
    }

    private static func hasValidShape(kind: TransactionKind, entries: [LedgerEntry]) -> Bool {
        let debitKinds = entries.filter { $0.side == .debit }.map(\.accountKind)
        let creditKinds = entries.filter { $0.side == .credit }.map(\.accountKind)
        switch kind {
        case .income:
            return debitKinds.allSatisfy { $0 == .asset } && creditKinds.allSatisfy { $0 == .income }
        case .expense:
            return debitKinds.allSatisfy { $0 == .expense } && creditKinds.allSatisfy { $0 == .asset || $0 == .liability }
        case .transfer:
            return debitKinds.allSatisfy { $0 == .asset || $0 == .liability }
                && creditKinds.allSatisfy { $0 == .asset || $0 == .liability }
                && Set(entries.map(\.accountID)).count >= 2
        case .refund:
            return debitKinds.allSatisfy { $0 == .asset || $0 == .liability }
                && creditKinds.allSatisfy { $0 == .expense }
        case .adjustment, .reversal:
            return true
        }
    }
}

public enum LedgerFactory {
    public static func income(
        amount: Money, to account: Account, categoryID: UUID, description: String, notes: String? = nil, occurredAt: Date = .now
    ) throws -> LedgerPosting {
        try validate(amount: amount, account: account)
        guard !account.type.isLiability else { throw LedgerError.invalidAccountKinds(.income) }
        return try LedgerPosting(
            kind: .income, occurredAt: occurredAt, description: description, notes: notes,
            entries: [
                LedgerEntry(accountID: account.id, accountKind: account.type.isLiability ? .liability : .asset, side: .debit, money: amount),
                LedgerEntry(accountID: categoryID, accountKind: .income, side: .credit, money: amount)
            ]
        )
    }

    public static func expense(
        amount: Money, from account: Account, categoryID: UUID, description: String, notes: String? = nil, occurredAt: Date = .now
    ) throws -> LedgerPosting {
        try validate(amount: amount, account: account)
        return try LedgerPosting(
            kind: .expense, occurredAt: occurredAt, description: description, notes: notes,
            entries: [
                LedgerEntry(accountID: categoryID, accountKind: .expense, side: .debit, money: amount),
                LedgerEntry(accountID: account.id, accountKind: account.type.isLiability ? .liability : .asset, side: .credit, money: amount)
            ]
        )
    }

    public static func transfer(
        amount: Money, from source: Account, to destination: Account, description: String, notes: String? = nil, occurredAt: Date = .now
    ) throws -> LedgerPosting {
        try validate(amount: amount, account: source)
        try validate(amount: amount, account: destination)
        guard source.id != destination.id else { throw LedgerError.invalidAccountKinds(.transfer) }
        return try LedgerPosting(
            kind: .transfer, occurredAt: occurredAt, description: description, notes: notes,
            entries: [
                LedgerEntry(accountID: destination.id, accountKind: destination.type.isLiability ? .liability : .asset, side: .debit, money: amount),
                LedgerEntry(accountID: source.id, accountKind: source.type.isLiability ? .liability : .asset, side: .credit, money: amount)
            ]
        )
    }

    public static func refund(
        amount: Money, to account: Account, expenseCategoryID: UUID, originalPostingID: UUID,
        description: String, notes: String? = nil, occurredAt: Date = .now
    ) throws -> LedgerPosting {
        try validate(amount: amount, account: account)
        return try LedgerPosting(
            kind: .refund, occurredAt: occurredAt, description: description, notes: notes,
            relatedPostingID: originalPostingID,
            entries: [
                LedgerEntry(accountID: account.id, accountKind: account.type.isLiability ? .liability : .asset, side: .debit, money: amount),
                LedgerEntry(accountID: expenseCategoryID, accountKind: .expense, side: .credit, money: amount)
            ]
        )
    }

    public static func reversal(
        of original: LedgerPosting, description: String, notes: String? = nil, occurredAt: Date = .now
    ) throws -> LedgerPosting {
        guard original.kind != .refund, original.kind != .reversal else {
            throw LedgerError.unsupportedReversal
        }
        let reversedEntries = try original.entries.map { entry in
            try LedgerEntry(
                accountID: entry.accountID,
                accountKind: entry.accountKind,
                side: entry.side == .debit ? .credit : .debit,
                money: entry.money
            )
        }
        return try LedgerPosting(
            kind: .reversal, occurredAt: occurredAt, description: description,
            notes: notes, relatedPostingID: original.id, entries: reversedEntries
        )
    }

    private static func validate(amount: Money, account: Account) throws {
        _ = try amount.requiringPositive()
        guard amount.currency == account.currency else {
            throw MoneyError.currencyMismatch(expected: account.currency.code, actual: amount.currency.code)
        }
    }
}


extension LedgerEntry {
    private enum CodingKeys: String, CodingKey { case accountID, accountKind, side, money }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            accountID: container.decode(UUID.self, forKey: .accountID),
            accountKind: container.decode(LedgerAccountKind.self, forKey: .accountKind),
            side: container.decode(EntrySide.self, forKey: .side),
            money: container.decode(Money.self, forKey: .money)
        )
    }
}

extension LedgerPosting {
    private enum CodingKeys: String, CodingKey {
        case id, kind, occurredAt, description, notes, relatedPostingID, scheduledOccurrenceID, entries, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            kind: container.decode(TransactionKind.self, forKey: .kind),
            occurredAt: container.decode(Date.self, forKey: .occurredAt),
            description: container.decode(String.self, forKey: .description),
            notes: container.decodeIfPresent(String.self, forKey: .notes),
            relatedPostingID: container.decodeIfPresent(UUID.self, forKey: .relatedPostingID),
            scheduledOccurrenceID: container.decodeIfPresent(String.self, forKey: .scheduledOccurrenceID),
            entries: container.decode([LedgerEntry].self, forKey: .entries),
            createdAt: container.decode(Date.self, forKey: .createdAt)
        )
    }
}
