import Observation
import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

@MainActor
@Observable
private final class AccountsViewModel {
    private let repository: any AccountRepository & LedgerRepository
    var accounts: [Account] = []
    var balances: [UUID: Money] = [:]
    var errorMessage: String?
    var includesArchived = false

    init(repository: any AccountRepository & LedgerRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            accounts = try repository.accounts(includeArchived: includesArchived).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            balances = try Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, try repository.balance(for: $0)) })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AccountsView: View {
    @State private var model: AccountsViewModel
    private let repository: any AccountRepository & LedgerRepository
    @Binding private var isEditorPresented: Bool
    @State private var editingAccount: Account?
    @State private var searchText = ""
    @State private var showArchived = false

    init(repository: any AccountRepository & LedgerRepository, isEditorPresented: Binding<Bool> = .constant(false)) {
        self.repository = repository
        _model = State(initialValue: AccountsViewModel(repository: repository))
        _isEditorPresented = isEditorPresented
    }

    private var visibleAccounts: [Account] {
        guard !searchText.isEmpty else { return model.accounts }
        return model.accounts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.institution?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if visibleAccounts.isEmpty {
                ContentUnavailableView {
                    Label(showArchived ? "accounts.empty-archived.title" : "accounts.empty.title", systemImage: "building.columns")
                } description: {
                    Text(showArchived ? "accounts.empty-archived.description" : "accounts.empty.description")
                } actions: {
                    if !showArchived {
                        Button("accounts.add") { presentEditor(for: nil) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    Section {
                        ForEach(visibleAccounts) { account in
                            Button {
                                presentEditor(for: account)
                            } label: {
                                AccountRow(account: account, balance: model.balances[account.id])
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(showArchived ? "accounts.archived-section" : "accounts.section")
                    }
                }
                .financeListStyle()
            }
        }
        .navigationTitle("navigation.accounts")
        .searchable(text: $searchText, prompt: Text("accounts.search"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Toggle("accounts.show-archived", isOn: $showArchived)
                        .onChange(of: showArchived) { _, value in
                            model.includesArchived = value
                            model.reload()
                        }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("accounts.filters")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { presentEditor(for: nil) } label: {
                    Label("accounts.add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: model.reload) {
            AccountEditorView(account: editingAccount, repository: repository)
        }
        .alert("common.error-title", isPresented: errorPresented) {
            Button("common.done", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "common.unknown-error")
        }
        .onAppear(perform: model.reload)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private func presentEditor(for account: Account?) {
        editingAccount = account
        isEditorPresented = true
    }
}

private struct AccountRow: View {
    let account: Account
    let balance: Money?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.isLiability ? "creditcard" : "building.columns")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(account.name).font(.headline)
                    if account.isArchived {
                        Text("accounts.archived-badge").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Group {
                    if let institution = account.institution {
                        Text(institution)
                    } else {
                        Text(account.type.localizedKey)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let balance {
                Text(balance.amount.formatted(.currency(code: balance.currency.code)))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(balance.amount < .zero ? .red : .primary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let account: Account?
    let repository: any AccountRepository & LedgerRepository
    @State private var name: String
    @State private var accountType: AccountType
    @State private var currencyCode: String
    @State private var openingBalanceText: String
    @State private var institution: String
    @State private var details: String
    @State private var isArchived: Bool
    @State private var errorMessage: String?

    init(account: Account?, repository: any AccountRepository & LedgerRepository) {
        self.account = account
        self.repository = repository
        _name = State(initialValue: account?.name ?? "")
        _accountType = State(initialValue: account?.type ?? .current)
        _currencyCode = State(initialValue: account?.currency.code ?? "EUR")
        _openingBalanceText = State(initialValue: account.map { NSDecimalNumber(decimal: $0.openingBalance.amount.magnitude).stringValue } ?? "0")
        _institution = State(initialValue: account?.institution ?? "")
        _details = State(initialValue: account?.details ?? "")
        _isArchived = State(initialValue: account?.isArchived ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("accounts.section.identity") {
                    TextField("accounts.field.name", text: $name)
                    Picker("accounts.field.type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.localizedKey).tag(type)
                        }
                    }
                    .disabled(account != nil)
                    TextField("accounts.field.institution", text: $institution)
                    TextField("accounts.field.details", text: $details, axis: .vertical)
                }
                if account == nil {
                    Section("accounts.section.opening") {
                        TextField("accounts.field.currency", text: $currencyCode)
                            .currencyCodeInput()
                        TextField(accountType.isLiability ? "accounts.field.opening-debt" : "accounts.field.opening-balance", text: $openingBalanceText)
                            .decimalKeyboard()
                    }
                } else {
                    Section("accounts.section.balance") {
                        LabeledContent("accounts.field.currency", value: account?.currency.code ?? "")
                        Text("accounts.opening-immutable")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        Toggle("accounts.show-archived", isOn: $isArchived)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(account == nil ? Text("accounts.add-title") : Text("accounts.edit-title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 340, minHeight: 400)
    }

    private func save() {
        do {
            if var account {
                try account.rename(to: name)
                account.updateDetails(institution: institution.nilIfBlank, details: details.nilIfBlank)
                account.setArchived(isArchived)
                try repository.save(account)
            } else {
                let currency = try Currency(code: currencyCode.trimmingCharacters(in: .whitespacesAndNewlines))
                guard let input = Decimal(string: openingBalanceText, locale: locale) else {
                    errorMessage = String(localized: "accounts.error.invalid-opening", locale: locale)
                    return
                }
                let signedBalance = accountType.isLiability ? -input.magnitude : input.magnitude
                let opening = try Money(signedBalance, currency: currency)
                let account = try Account(
                    name: name, type: accountType, currency: currency, openingBalance: opening,
                    institution: institution.nilIfBlank, details: details.nilIfBlank
                )
                try repository.save(account)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension AccountType {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .current: "account-type.current"
        case .savings: "account-type.savings"
        case .cash: "account-type.cash"
        case .creditCard: "account-type.credit-card"
        case .investment: "account-type.investment"
        case .loan: "account-type.loan"
        case .other: "account-type.other"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


private extension View {
    @ViewBuilder func currencyCodeInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.characters).autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
