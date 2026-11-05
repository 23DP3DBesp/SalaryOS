import Foundation

public enum MoneyError: Error, Equatable {
    case currencyMismatch(expected: String, actual: String)
    case notPositive
    case notFinite
}

/// A rounded monetary amount. Arithmetic never converts through binary floating point.
public struct Money: Hashable, Codable, Sendable {
    public let amount: Decimal
    public let currency: Currency

    public init(_ amount: Decimal, currency: Currency) throws {
        guard !amount.isNaN else { throw MoneyError.notFinite }
        var source = amount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, currency.fractionDigits, .plain)
        self.amount = rounded
        self.currency = currency
    }

    public static func zero(in currency: Currency) -> Money {
        Money(uncheckedAmount: .zero, currency: currency)
    }

    private init(uncheckedAmount: Decimal, currency: Currency) {
        self.amount = uncheckedAmount
        self.currency = currency
    }

    public func adding(_ other: Money) throws -> Money {
        try requireSameCurrency(as: other)
        return try Money(amount + other.amount, currency: currency)
    }

    public func subtracting(_ other: Money) throws -> Money {
        try requireSameCurrency(as: other)
        return try Money(amount - other.amount, currency: currency)
    }

    public func requiringPositive() throws -> Money {
        guard amount > .zero else { throw MoneyError.notPositive }
        return self
    }

    private func requireSameCurrency(as other: Money) throws {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(expected: currency.code, actual: other.currency.code)
        }
    }
}

extension Money {
    private enum CodingKeys: String, CodingKey { case amount, currency }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            container.decode(Decimal.self, forKey: .amount),
            currency: container.decode(Currency.self, forKey: .currency)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
    }
}
