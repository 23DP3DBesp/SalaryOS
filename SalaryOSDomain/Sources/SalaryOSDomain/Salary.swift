import Foundation

public enum SalaryRecordError: Error, Equatable {
    case invalidDependentCount
    case taxYearDateMismatch
    case negativeAmount
    case inconsistentNet
    case inconsistentEmployerCost
    case emptyDescription
}

/// A saved monthly payroll breakdown. The values describe the employee's payslip
/// estimate or entered figures; the linked ledger posting always records take-home pay.
public struct SalaryRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let taxYear: Int
    public let occurredAt: Date
    public let categoryID: UUID
    public let rulesID: String
    public let gross: Money
    public let employeeSocialContribution: Money
    public let taxableBase: Money
    public let appliedAllowance: Money
    public let incomeTaxWithheld: Money
    public let net: Money
    public let employerSocialContribution: Money
    public let employerCost: Money
    public let taxBookletApplied: Bool
    public let dependentCount: Int
    public let profileName: String
    public let description: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(), taxYear: Int, occurredAt: Date, categoryID: UUID, rulesID: String,
        gross: Money, employeeSocialContribution: Money, taxableBase: Money, appliedAllowance: Money,
        incomeTaxWithheld: Money, net: Money, employerSocialContribution: Money, employerCost: Money,
        taxBookletApplied: Bool, dependentCount: Int, profileName: String = "Main job",
        description: String, createdAt: Date = .now
    ) throws {
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw SalaryRecordError.emptyDescription }
        guard dependentCount >= 0 else { throw SalaryRecordError.invalidDependentCount }
        let profileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileName.isEmpty else { throw SalaryRecordError.emptyDescription }
        guard Calendar.current.component(.year, from: occurredAt) == taxYear else { throw SalaryRecordError.taxYearDateMismatch }
        let values = [gross, employeeSocialContribution, taxableBase, appliedAllowance, incomeTaxWithheld, net, employerSocialContribution, employerCost]
        guard values.allSatisfy({ $0.currency == gross.currency }) else {
            throw MoneyError.currencyMismatch(expected: gross.currency.code, actual: values.first(where: { $0.currency != gross.currency })?.currency.code ?? "")
        }
        guard values.allSatisfy({ $0.amount >= .zero }) else { throw SalaryRecordError.negativeAmount }
        guard gross.amount - employeeSocialContribution.amount - incomeTaxWithheld.amount == net.amount else {
            throw SalaryRecordError.inconsistentNet
        }
        guard gross.amount + employerSocialContribution.amount == employerCost.amount else {
            throw SalaryRecordError.inconsistentEmployerCost
        }
        self.id = id
        self.taxYear = taxYear
        self.occurredAt = occurredAt
        self.categoryID = categoryID
        self.rulesID = rulesID
        self.gross = gross
        self.employeeSocialContribution = employeeSocialContribution
        self.taxableBase = taxableBase
        self.appliedAllowance = appliedAllowance
        self.incomeTaxWithheld = incomeTaxWithheld
        self.net = net
        self.employerSocialContribution = employerSocialContribution
        self.employerCost = employerCost
        self.taxBookletApplied = taxBookletApplied
        self.dependentCount = dependentCount
        self.profileName = profileName
        self.description = description
        self.createdAt = createdAt
    }
}
