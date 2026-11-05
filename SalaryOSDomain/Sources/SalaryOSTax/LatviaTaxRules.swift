import Foundation
import SalaryOSDomain

public struct LatviaTaxRules: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let taxYear: Int
    public let effectiveFrom: Date
    public let effectiveThrough: Date
    public let employeeSocialRate: Decimal
    public let employerSocialRate: Decimal
    public let monthlyFlatWithholdingRate: Decimal
    public let annualStandardRate: Decimal
    public let annualHigherRate: Decimal
    public let annualIncomeThreshold: Money
    public let additionalAnnualRate: Decimal
    public let additionalAnnualThreshold: Money
    public let monthlyNonTaxableMinimum: Money
    public let monthlyDependentAllowance: Money
    public let maximumSocialContributionBase: Money
    public let minimumMonthlyWage: Money
    public let sourceURLs: [URL]
    public let verifiedAt: Date

    public static func rules(for taxYear: Int) throws -> LatviaTaxRules {
        guard taxYear == 2026 else { throw TaxCalculationError.unsupportedTaxYear(taxYear) }
        let eur = try Currency(code: "EUR")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: taxYear, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        let verified = ISO8601DateFormatter().date(from: "2026-11-05T00:00:00Z")!
        return LatviaTaxRules(
            id: "LV-2026-v1", taxYear: taxYear, effectiveFrom: start, effectiveThrough: end,
            employeeSocialRate: Decimal(string: "0.105")!, employerSocialRate: Decimal(string: "0.2359")!,
            monthlyFlatWithholdingRate: Decimal(string: "0.255")!, annualStandardRate: Decimal(string: "0.255")!,
            annualHigherRate: Decimal(string: "0.33")!, annualIncomeThreshold: try Money(Decimal(105300), currency: eur),
            additionalAnnualRate: Decimal(string: "0.03")!, additionalAnnualThreshold: try Money(Decimal(200000), currency: eur),
            monthlyNonTaxableMinimum: try Money(Decimal(550), currency: eur),
            monthlyDependentAllowance: try Money(Decimal(250), currency: eur),
            maximumSocialContributionBase: try Money(Decimal(105300), currency: eur),
            minimumMonthlyWage: try Money(Decimal(780), currency: eur),
            sourceURLs: [
                URL(string: "https://www.vid.gov.lv/en/personal-income-tax-rates")!,
                URL(string: "https://www.vid.gov.lv/en/personal-income-tax")!,
                URL(string: "https://www.vid.gov.lv/lv/valsts-socialas-apdrosinasanas-obligato-iemaksu-likmes")!,
                URL(string: "https://www.fm.gov.lv/en/non-taxable-minimum-and-tax-allowances")!
            ], verifiedAt: verified
        )
    }
}

public enum TaxCalculationError: Error, Equatable {
    case unsupportedTaxYear(Int)
    case nonEURCurrency
    case negativeGross
    case invalidDependentCount
}

public struct MonthlySalaryInput: Sendable {
    public let gross: Money
    public let taxBookletApplied: Bool
    public let dependentCount: Int
    public let taxYear: Int

    public init(gross: Money, taxBookletApplied: Bool, dependentCount: Int = 0, taxYear: Int = 2026) {
        self.gross = gross
        self.taxBookletApplied = taxBookletApplied
        self.dependentCount = dependentCount
        self.taxYear = taxYear
    }
}

public struct MonthlySalaryResult: Sendable {
    public let rulesID: String
    public let gross: Money
    public let employeeSocialContribution: Money
    public let taxableBase: Money
    public let appliedAllowance: Money
    public let incomeTaxWithheld: Money
    public let net: Money
    public let employerSocialContribution: Money
    public let employerCost: Money
}

public enum LatviaSalaryCalculator {
    public static func calculate(_ input: MonthlySalaryInput) throws -> MonthlySalaryResult {
        let rules = try LatviaTaxRules.rules(for: input.taxYear)
        guard input.gross.currency.code == "EUR" else { throw TaxCalculationError.nonEURCurrency }
        guard input.gross.amount >= .zero else { throw TaxCalculationError.negativeGross }
        guard input.dependentCount >= 0 else { throw TaxCalculationError.invalidDependentCount }

        let employeeSocial = try amount(input.gross.amount * rules.employeeSocialRate)
        let employerSocial = try amount(input.gross.amount * rules.employerSocialRate)
        let allowance: Money
        if input.taxBookletApplied {
            allowance = try amount(rules.monthlyNonTaxableMinimum.amount + rules.monthlyDependentAllowance.amount * Decimal(input.dependentCount))
        } else {
            allowance = .zero(in: input.gross.currency)
        }
        let taxBaseValue = max(Decimal.zero, input.gross.amount - employeeSocial.amount - allowance.amount)
        let taxBase = try amount(taxBaseValue)
        let withheld = try amount(taxBase.amount * rules.monthlyFlatWithholdingRate)
        let net = try input.gross.subtracting(employeeSocial).subtracting(withheld)
        let cost = try input.gross.adding(employerSocial)
        return MonthlySalaryResult(rulesID: rules.id, gross: input.gross, employeeSocialContribution: employeeSocial,
            taxableBase: taxBase, appliedAllowance: allowance, incomeTaxWithheld: withheld, net: net,
            employerSocialContribution: employerSocial, employerCost: cost)
    }

    private static func amount(_ value: Decimal) throws -> Money {
        try Money(value, currency: Currency(code: "EUR"))
    }
}

public struct AnnualTaxEstimate: Sendable {
    public let annualTaxableIncome: Money
    public let progressiveIncomeTax: Money
    public let additionalIncomeTax: Money
    public let totalIncomeTax: Money
}

public enum LatviaAnnualTaxCalculator {
    /// Estimates PIT on an already prepared annual taxable base and additional-rate income.
    /// It does not prepare the annual declaration or calculate VSAOI/solidarity-tax settlement.
    public static func estimate(taxableIncome: Money, totalIncomeForAdditionalRate: Money? = nil, taxYear: Int = 2026) throws -> AnnualTaxEstimate {
        let rules = try LatviaTaxRules.rules(for: taxYear)
        guard taxableIncome.currency.code == "EUR",
              totalIncomeForAdditionalRate == nil || totalIncomeForAdditionalRate?.currency.code == "EUR" else {
            throw TaxCalculationError.nonEURCurrency
        }
        guard taxableIncome.amount >= .zero else { throw TaxCalculationError.negativeGross }
        let firstBand = min(taxableIncome.amount, rules.annualIncomeThreshold.amount)
        let secondBand = max(.zero, taxableIncome.amount - rules.annualIncomeThreshold.amount)
        let progressive = try Money(firstBand * rules.annualStandardRate + secondBand * rules.annualHigherRate, currency: taxableIncome.currency)
        let additionalIncome = totalIncomeForAdditionalRate?.amount ?? taxableIncome.amount
        let additional = try Money(max(.zero, additionalIncome - rules.additionalAnnualThreshold.amount) * rules.additionalAnnualRate, currency: taxableIncome.currency)
        return AnnualTaxEstimate(annualTaxableIncome: taxableIncome, progressiveIncomeTax: progressive,
            additionalIncomeTax: additional, totalIncomeTax: try progressive.adding(additional))
    }
}
