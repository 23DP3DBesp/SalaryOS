import SalaryOSDomain
import SalaryOSTax
import SwiftUI

struct SalaryView: View {
    @State private var grossText = "2500"
    @State private var taxBookletApplied = true
    @State private var dependentCount = 0

    private var result: MonthlySalaryResult? {
        guard let value = Decimal(string: grossText.replacingOccurrences(of: ",", with: ".")),
              let gross = try? Money(value, currency: Currency(code: "EUR"))
        else { return nil }
        return try? LatviaSalaryCalculator.calculate(MonthlySalaryInput(
            gross: gross, taxBookletApplied: taxBookletApplied, dependentCount: dependentCount
        ))
    }

    var body: some View {
        Form {
            Section("salary.input-section") {
                TextField("salary.gross", text: $grossText)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Toggle("salary.booklet", isOn: $taxBookletApplied)
                Stepper(value: $dependentCount, in: 0...10) {
                    Text("salary.dependents \(dependentCount)")
                }
                .disabled(!taxBookletApplied)
            }
            if let result {
                Section("salary.result-section") {
                    summaryRow("salary.net", result.net, emphasized: true)
                    summaryRow("salary.employee-contribution", result.employeeSocialContribution)
                    summaryRow("salary.income-tax", result.incomeTaxWithheld)
                    summaryRow("salary.employer-contribution", result.employerSocialContribution)
                    summaryRow("salary.employer-cost", result.employerCost)
                }
                Section {
                    Text("salary.disclaimer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("salary.invalid-input", systemImage: "eurosign.circle")
            }
        }
        .navigationTitle("navigation.salary")
    }

    private func summaryRow(_ title: LocalizedStringKey, _ money: Money, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(money.amount, format: .currency(code: money.currency.code))
                .fontWeight(emphasized ? .semibold : .regular)
        }
    }
}
