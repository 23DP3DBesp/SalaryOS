import Foundation
import SalaryOSDomain
import SalaryOSTax
import Testing

struct LatviaTaxCalculatorTests {
    private func eur(_ amount: String) throws -> Money {
        try Money(Decimal(string: amount)!, currency: Currency(code: "EUR"))
    }

    @Test func calculatesMonthlySalaryWithTaxBooklet() throws {
        let result = try LatviaSalaryCalculator.calculate(MonthlySalaryInput(gross: eur("1000"), taxBookletApplied: true))
        #expect(result.employeeSocialContribution.amount == Decimal(string: "105")!)
        #expect(result.taxableBase.amount == Decimal(string: "345")!)
        #expect(result.incomeTaxWithheld.amount == Decimal(string: "87.98")!)
        #expect(result.net.amount == Decimal(string: "807.02")!)
        #expect(result.employerCost.amount == Decimal(string: "1235.90")!)
    }

    @Test func appliesDependentAllowanceOnlyWithBooklet() throws {
        let withBooklet = try LatviaSalaryCalculator.calculate(MonthlySalaryInput(gross: eur("1000"), taxBookletApplied: true, dependentCount: 1))
        let without = try LatviaSalaryCalculator.calculate(MonthlySalaryInput(gross: eur("1000"), taxBookletApplied: false, dependentCount: 1))
        #expect(withBooklet.appliedAllowance.amount == Decimal(string: "800")!)
        #expect(withBooklet.incomeTaxWithheld.amount == Decimal(string: "24.23")!)
        #expect(without.incomeTaxWithheld.amount == Decimal(string: "228.23")!)
    }

    @Test func annualEstimateUsesMarginalBandsAndAdditionalRate() throws {
        let result = try LatviaAnnualTaxCalculator.estimate(taxableIncome: eur("120000"), totalIncomeForAdditionalRate: eur("210000"))
        #expect(result.progressiveIncomeTax.amount == Decimal(string: "31702.50")!)
        #expect(result.additionalIncomeTax.amount == Decimal(string: "300")!)
        #expect(result.totalIncomeTax.amount == Decimal(string: "32002.50")!)
    }

    @Test func rulesAreVersionedAndUnknownYearsFail() throws {
        #expect(try LatviaTaxRules.rules(for: 2026).id == "LV-2026-v1")
        #expect(throws: TaxCalculationError.self) { try LatviaTaxRules.rules(for: 2027) }
    }
}
