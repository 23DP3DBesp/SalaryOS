import Foundation

public enum LoanRateType: String, Codable, CaseIterable, Sendable {
    case fixed
    case variable
}

public enum LoanError: Error, Equatable {
    case emptyName
    case emptyLender
    case nonPositivePrincipal
    case invalidInterestRate
    case invalidDuration
    case negativeFee
    case rateChangeNotAllowed
    case rateChangeBeforeStart
    case nonPositiveExtraPayment
    case extraPaymentBeforeStart
    case extraPaymentExceedsBalance
    case invalidInstallmentNumber
    case duplicateInstallmentPayment
    case wrongLoanReference
    case invalidSchedule
}

public struct Loan: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var lender: String
    public let principal: Money
    public let rateType: LoanRateType
    public private(set) var annualInterestRate: Decimal
    public let durationMonths: Int
    public let startDate: Date
    public let fees: Money
    public private(set) var notes: String?
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool

    public init(
        id: UUID = UUID(), name: String, lender: String, principal: Money,
        annualInterestRate: Decimal, rateType: LoanRateType = .fixed,
        durationMonths: Int, startDate: Date, fees: Money? = nil,
        notes: String? = nil, createdAt: Date = .now, updatedAt: Date = .now,
        isArchived: Bool = false
    ) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lender = lender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LoanError.emptyName }
        guard !lender.isEmpty else { throw LoanError.emptyLender }
        guard principal.amount > .zero else { throw LoanError.nonPositivePrincipal }
        guard annualInterestRate >= .zero, annualInterestRate <= 100 else { throw LoanError.invalidInterestRate }
        guard (1...600).contains(durationMonths) else { throw LoanError.invalidDuration }
        let fees = try fees ?? Money(.zero, currency: principal.currency)
        guard fees.currency == principal.currency else {
            throw MoneyError.currencyMismatch(expected: principal.currency.code, actual: fees.currency.code)
        }
        guard fees.amount >= .zero else { throw LoanError.negativeFee }
        self.id = id
        self.name = name
        self.lender = lender
        self.principal = principal
        self.annualInterestRate = annualInterestRate
        self.rateType = rateType
        self.durationMonths = durationMonths
        self.startDate = startDate
        self.fees = fees
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public mutating func update(name: String, lender: String, notes: String?) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lender = lender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LoanError.emptyName }
        guard !lender.isEmpty else { throw LoanError.emptyLender }
        self.name = name
        self.lender = lender
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updatedAt = .now
    }

    public mutating func setArchived(_ archived: Bool) {
        isArchived = archived
        updatedAt = .now
    }
}

public struct LoanRateChange: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let loanID: UUID
    public let annualInterestRate: Decimal
    public let effectiveDate: Date
    public let createdAt: Date

    public init(id: UUID = UUID(), loanID: UUID, annualInterestRate: Decimal, effectiveDate: Date, loan: Loan, createdAt: Date = .now) throws {
        guard loanID == loan.id else { throw LoanError.wrongLoanReference }
        guard loan.rateType == .variable else { throw LoanError.rateChangeNotAllowed }
        guard effectiveDate >= loan.startDate else { throw LoanError.rateChangeBeforeStart }
        guard annualInterestRate >= .zero, annualInterestRate <= 100 else { throw LoanError.invalidInterestRate }
        self.id = id
        self.loanID = loanID
        self.annualInterestRate = annualInterestRate
        self.effectiveDate = effectiveDate
        self.createdAt = createdAt
    }
}

public struct LoanExtraPayment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let loanID: UUID
    public let principalReduction: Money
    public let paidAt: Date
    public let note: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), loanID: UUID, principalReduction: Money, paidAt: Date, loan: Loan, note: String? = nil, createdAt: Date = .now) throws {
        guard loanID == loan.id else { throw LoanError.wrongLoanReference }
        guard principalReduction.amount > .zero else { throw LoanError.nonPositiveExtraPayment }
        guard principalReduction.currency == loan.principal.currency else {
            throw MoneyError.currencyMismatch(expected: loan.principal.currency.code, actual: principalReduction.currency.code)
        }
        guard paidAt >= loan.startDate else { throw LoanError.extraPaymentBeforeStart }
        self.id = id
        self.loanID = loanID
        self.principalReduction = principalReduction
        self.paidAt = paidAt
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
    }
}

public struct LoanPayment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let loanID: UUID
    public let installmentNumber: Int
    public let principalPaid: Money
    public let interestPaid: Money
    public let paidAt: Date
    public let note: String?
    public let createdAt: Date

    public var amount: Decimal { principalPaid.amount + interestPaid.amount }

    public init(
        id: UUID = UUID(), loanID: UUID, installmentNumber: Int,
        principalPaid: Money, interestPaid: Money, paidAt: Date,
        loan: Loan, note: String? = nil, createdAt: Date = .now
    ) throws {
        guard loanID == loan.id else { throw LoanError.wrongLoanReference }
        guard (1...loan.durationMonths).contains(installmentNumber) else { throw LoanError.invalidInstallmentNumber }
        guard principalPaid.currency == loan.principal.currency, interestPaid.currency == loan.principal.currency else {
            throw MoneyError.currencyMismatch(expected: loan.principal.currency.code, actual: principalPaid.currency.code)
        }
        guard principalPaid.amount >= .zero, interestPaid.amount >= .zero,
              principalPaid.amount + interestPaid.amount > .zero else { throw LoanError.nonPositiveExtraPayment }
        guard paidAt >= loan.startDate else { throw LoanError.extraPaymentBeforeStart }
        self.id = id
        self.loanID = loanID
        self.installmentNumber = installmentNumber
        self.principalPaid = principalPaid
        self.interestPaid = interestPaid
        self.paidAt = paidAt
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
    }
}

public struct LoanInstallment: Identifiable, Hashable, Sendable {
    public let id: Int
    public let dueDate: Date
    public let openingBalance: Money
    public let appliedRate: Decimal
    public let regularPayment: Money
    public let interest: Money
    public let principalPaid: Money
    public let extraPrincipalPaid: Money
    public let closingBalance: Money
    public let paymentDate: Date?
    public var isPaid: Bool { paymentDate != nil }
}

public struct LoanSchedule: Equatable, Sendable {
    public let installments: [LoanInstallment]
    public let totalInterest: Money
    public let totalRegularPayments: Money
    public let totalExtraPrincipal: Money
    public let fees: Money
    public let estimatedTotalCost: Money

    public var payoffDate: Date? { installments.last(where: { $0.closingBalance.amount == .zero })?.dueDate }
}

/// Generates a monthly amortization estimate using Decimal arithmetic only.
/// Variable rates and extra principal payments are applied at monthly period boundaries.
public enum LoanCalculator {
    public static func schedule(
        for loan: Loan,
        rateChanges: [LoanRateChange] = [],
        extraPayments: [LoanExtraPayment] = [],
        regularPayments: [LoanPayment] = [],
        calendar: Calendar = .current
    ) throws -> LoanSchedule {
        guard rateChanges.allSatisfy({ $0.loanID == loan.id }), extraPayments.allSatisfy({ $0.loanID == loan.id }), regularPayments.allSatisfy({ $0.loanID == loan.id }) else {
            throw LoanError.wrongLoanReference
        }
        guard rateChanges.allSatisfy({ loan.rateType == .variable && $0.effectiveDate >= loan.startDate }),
              extraPayments.allSatisfy({ $0.paidAt >= loan.startDate && $0.principalReduction.currency == loan.principal.currency }) else {
            throw LoanError.invalidSchedule
        }
        let orderedRates = rateChanges.sorted { $0.effectiveDate < $1.effectiveDate }
        let orderedExtras = extraPayments.sorted { $0.paidAt < $1.paidAt }
        guard Set(regularPayments.map(\.installmentNumber)).count == regularPayments.count,
              regularPayments.allSatisfy({ (1...loan.durationMonths).contains($0.installmentNumber) }) else { throw LoanError.duplicateInstallmentPayment }
        let paymentsByInstallment = Dictionary(uniqueKeysWithValues: regularPayments.map { ($0.installmentNumber, $0) })
        let currency = loan.principal.currency
        var balance = loan.principal.amount
        var totalInterest = Decimal.zero
        var totalRegular = Decimal.zero
        var totalExtra = Decimal.zero
        var installments: [LoanInstallment] = []
        var extraIndex = 0
        if let lastRate = orderedRates.last,
           let finalDate = monthlyDate(start: loan.startDate, offset: loan.durationMonths, calendar: calendar),
           lastRate.effectiveDate > finalDate {
            throw LoanError.invalidSchedule
        }

        for month in 1...loan.durationMonths where balance > .zero {
            guard let dueDate = monthlyDate(start: loan.startDate, offset: month, calendar: calendar) else {
                throw LoanError.invalidSchedule
            }
            let opening = balance
            var extraThisMonth = Decimal.zero
            while extraIndex < orderedExtras.count, orderedExtras[extraIndex].paidAt <= dueDate {
                extraThisMonth += orderedExtras[extraIndex].principalReduction.amount
                extraIndex += 1
            }
            guard extraThisMonth <= balance else { throw LoanError.extraPaymentExceedsBalance }
            balance -= extraThisMonth
            totalExtra += extraThisMonth

            let rate = orderedRates.last(where: { $0.effectiveDate <= dueDate })?.annualInterestRate ?? loan.annualInterestRate
            let monthlyRate = rate / Decimal(1200)
            let interest = try Money(balance * monthlyRate, currency: currency).amount
            let periodsRemaining = loan.durationMonths - month + 1
            let scheduledPayment = paymentsByInstallment[month]
            let payment: Decimal
            let principalPaid: Decimal
            let interestForPeriod: Decimal
            if let scheduledPayment {
                guard scheduledPayment.principalPaid.amount <= balance else { throw LoanError.extraPaymentExceedsBalance }
                payment = scheduledPayment.amount
                principalPaid = scheduledPayment.principalPaid.amount
                interestForPeriod = scheduledPayment.interestPaid.amount
            } else {
                let paymentAmount = try annuityPayment(principal: balance, monthlyRate: monthlyRate, periods: periodsRemaining, currency: currency).amount
                payment = min(paymentAmount, balance + interest)
                principalPaid = min(balance, max(.zero, payment - interest))
                interestForPeriod = interest
            }
            balance = max(.zero, balance - principalPaid)
            let regularMoney = try Money(payment, currency: currency)
            let interestMoney = try Money(interestForPeriod, currency: currency)
            let principalMoney = try Money(principalPaid, currency: currency)
            let extraMoney = try Money(extraThisMonth, currency: currency)
            let closingMoney = try Money(balance, currency: currency)
            installments.append(LoanInstallment(
                id: month, dueDate: dueDate, openingBalance: try Money(opening, currency: currency),
                appliedRate: rate, regularPayment: regularMoney, interest: interestMoney,
                principalPaid: principalMoney, extraPrincipalPaid: extraMoney, closingBalance: closingMoney,
                paymentDate: scheduledPayment?.paidAt
            ))
            totalInterest += interest
            totalRegular += payment
        }
        guard extraIndex == orderedExtras.count else { throw LoanError.extraPaymentExceedsBalance }
        let recordedInstallments = Set(installments.filter(\.isPaid).map(\.id))
        guard Set(paymentsByInstallment.keys).isSubset(of: recordedInstallments) else { throw LoanError.invalidSchedule }
        let totalCost = totalRegular + totalExtra + loan.fees.amount
        return LoanSchedule(
            installments: installments,
            totalInterest: try Money(totalInterest, currency: currency),
            totalRegularPayments: try Money(totalRegular, currency: currency),
            totalExtraPrincipal: try Money(totalExtra, currency: currency),
            fees: loan.fees,
            estimatedTotalCost: try Money(totalCost, currency: currency)
        )
    }

    private static func annuityPayment(principal: Decimal, monthlyRate: Decimal, periods: Int, currency: Currency) throws -> Money {
        guard periods > 0 else { throw LoanError.invalidSchedule }
        if monthlyRate == .zero { return try Money(principal / Decimal(periods), currency: currency) }
        let factor = decimalPower(1 + monthlyRate, exponent: periods)
        let denominator = factor - 1
        guard denominator > .zero else { throw LoanError.invalidSchedule }
        return try Money(principal * monthlyRate * factor / denominator, currency: currency)
    }

    private static func decimalPower(_ value: Decimal, exponent: Int) -> Decimal {
        (0..<exponent).reduce(Decimal(1)) { result, _ in result * value }
    }

    private static func monthlyDate(start: Date, offset: Int, calendar: Calendar) -> Date? {
        guard let monthStart = calendar.dateInterval(of: .month, for: start)?.start,
              let first = calendar.date(byAdding: .month, value: offset, to: monthStart),
              let monthInterval = calendar.dateInterval(of: .month, for: first) else { return nil }
        let day = calendar.component(.day, from: start)
        let dayRange = calendar.range(of: .day, in: .month, for: first) ?? 1..<29
        let clampedDay = min(day, dayRange.upperBound - 1)
        return calendar.date(byAdding: .day, value: clampedDay - 1, to: monthInterval.start)
    }

}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
