import Foundation

public enum DebtDirection: String, Codable, CaseIterable, Sendable {
    case payable
    case receivable
}

public enum DebtStatus: String, Codable, Sendable {
    case open
    case settled
    case archived
}

public enum DebtError: Error, Equatable {
    case emptyName
    case emptyCounterparty
    case nonPositivePrincipal
    case nonPositivePayment
    case paymentExceedsOutstanding
    case settledDebt
}

public struct Debt: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var counterparty: String
    public let direction: DebtDirection
    public let principal: Money
    public private(set) var createdAt: Date
    public private(set) var dueDate: Date?
    public private(set) var notes: String?
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool

    public init(
        id: UUID = UUID(), name: String, counterparty: String, direction: DebtDirection,
        principal: Money, createdAt: Date = .now, dueDate: Date? = nil,
        notes: String? = nil, updatedAt: Date = .now, isArchived: Bool = false
    ) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let counterparty = counterparty.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw DebtError.emptyName }
        guard !counterparty.isEmpty else { throw DebtError.emptyCounterparty }
        guard principal.amount > .zero else { throw DebtError.nonPositivePrincipal }
        self.id = id
        self.name = name
        self.counterparty = counterparty
        self.direction = direction
        self.principal = principal
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public mutating func updateDetails(name: String, counterparty: String, dueDate: Date?, notes: String?) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let counterparty = counterparty.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw DebtError.emptyName }
        guard !counterparty.isEmpty else { throw DebtError.emptyCounterparty }
        self.name = name
        self.counterparty = counterparty
        self.dueDate = dueDate
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updatedAt = .now
    }

    public mutating func setArchived(_ value: Bool) {
        isArchived = value
        updatedAt = .now
    }
}

public struct DebtPayment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let debtID: UUID
    public let amount: Money
    public let paidAt: Date
    public let note: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), debtID: UUID, amount: Money, paidAt: Date = .now, note: String? = nil, createdAt: Date = .now) throws {
        guard amount.amount > .zero else { throw DebtError.nonPositivePayment }
        self.id = id
        self.debtID = debtID
        self.amount = amount
        self.paidAt = paidAt
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
    }
}

public struct DebtSummary: Equatable, Sendable {
    public let debt: Debt
    public let payments: [DebtPayment]
    public let paid: Money
    public let outstanding: Money
    public let status: DebtStatus

    public init(debt: Debt, payments: [DebtPayment]) throws {
        var total = Decimal.zero
        for payment in payments {
            guard payment.debtID == debt.id else { continue }
            guard payment.amount.currency == debt.principal.currency else {
                throw MoneyError.currencyMismatch(expected: debt.principal.currency.code, actual: payment.amount.currency.code)
            }
            total += payment.amount.amount
        }
        guard total <= debt.principal.amount else { throw DebtError.paymentExceedsOutstanding }
        self.debt = debt
        self.payments = payments.filter { $0.debtID == debt.id }.sorted { $0.paidAt > $1.paidAt }
        paid = try Money(total, currency: debt.principal.currency)
        outstanding = try Money(debt.principal.amount - total, currency: debt.principal.currency)
        status = debt.isArchived ? .archived : (outstanding.amount == .zero ? .settled : .open)
    }

    public func recording(_ payment: DebtPayment) throws -> DebtSummary {
        guard status == .open else { throw DebtError.settledDebt }
        guard payment.debtID == debt.id else { throw DebtError.paymentExceedsOutstanding }
        guard payment.amount.currency == outstanding.currency else {
            throw MoneyError.currencyMismatch(expected: outstanding.currency.code, actual: payment.amount.currency.code)
        }
        guard payment.amount.amount <= outstanding.amount else { throw DebtError.paymentExceedsOutstanding }
        return try DebtSummary(debt: debt, payments: payments + [payment])
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
