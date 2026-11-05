import SalaryOSDomain
import SwiftUI
import UserNotifications

struct CalendarView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository & WorkTimeRepository & ScheduledOperationRepository
    @State private var selectedMonth = Date.now
    @State private var operations: [ScheduledOperation] = []
    @State private var occurrences: [ScheduledOccurrence] = []
    @State private var postedIDs = Set<String>()
    @State private var accounts: [UUID: Account] = [:]
    @State private var editorOperation: ScheduledOperation?
    @State private var isEditorPresented = false
    @State private var postingOccurrence: ScheduledOccurrence?
    @State private var actualDate = Date.now
    @State private var errorMessage: String?
    @State private var reminderCoordinator = CalendarReminderCoordinator()
    @AppStorage("calendar.reminders.enabled") private var remindersEnabled = false

    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: selectedMonth) ?? DateInterval(start: selectedMonth, duration: 31 * 86_400)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain).accessibilityLabel("calendar.previous-month")
                    Spacer()
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.plain).accessibilityLabel("calendar.next-month")
                }
            }
            if occurrences.isEmpty {
                Section { ContentUnavailableView("calendar.empty.title", systemImage: "calendar", description: Text("calendar.empty.description")) }
            } else {
                Section("calendar.upcoming") {
                    ForEach(occurrences) { occurrence in
                        occurrenceRow(occurrence)
                    }
                }
            }
            if !operations.isEmpty {
                Section("calendar.schedules") {
                    ForEach(operations) { operation in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(operation.name).font(.headline)
                                Text("\(operation.recurrence.localizedName) · \(operation.kind.localizedName)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(money(operation.amount)).font(.subheadline)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editorOperation = operation; isEditorPresented = true }
                        .contextMenu {
                            Button("calendar.edit-schedule", systemImage: "pencil") { editorOperation = operation; isEditorPresented = true }
                            Button("calendar.archive-schedule", systemImage: "archivebox") { archive(operation) }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("navigation.calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        toggleReminders()
                    } label: {
                        Image(systemName: remindersEnabled ? "bell.badge" : "bell.slash")
                    }
                    .accessibilityLabel(remindersEnabled ? "calendar.disable-reminders" : "calendar.enable-reminders")
                    .help(remindersEnabled ? "calendar.disable-reminders" : "calendar.enable-reminders")

                    Button("calendar.add-schedule", systemImage: "plus") { editorOperation = nil; isEditorPresented = true }
                }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: calendarDidChange) {
            ScheduledOperationEditor(repository: repository, existingOperation: editorOperation)
        }
        .sheet(item: $postingOccurrence, onDismiss: calendarDidChange) { occurrence in
            NavigationStack {
                Form {
                    LabeledContent("calendar.scheduled-date", value: occurrence.dueDate.formatted(date: .long, time: .omitted))
                    DatePicker("calendar.actual-date", selection: $actualDate, displayedComponents: .date)
                }
                .navigationTitle("calendar.post-operation")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { postingOccurrence = nil } }
                    ToolbarItem(placement: .confirmationAction) { Button("common.post", action: postSelectedOccurrence) }
                }
            }
            .frame(minWidth: 330, minHeight: 230)
        }
        .task {
            reload()
            await refreshReminders()
        }
        .onChange(of: selectedMonth) { _, _ in reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder
    private func occurrenceRow(_ occurrence: ScheduledOccurrence) -> some View {
        let isPosted = postedIDs.contains(occurrence.id)
        let isOverdue = occurrence.dueDate < Calendar.current.startOfDay(for: .now) && !isPosted
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.operation.name).font(.headline)
                Text("\(occurrence.dueDate.formatted(date: .abbreviated, time: .omitted)) · \(accounts[occurrence.operation.accountID]?.name ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
                if isPosted {
                    Label("calendar.recorded", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
                } else if isOverdue {
                    Label("calendar.overdue", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(money(occurrence.operation.amount)).font(.subheadline.weight(.medium))
                if !isPosted {
                    Button("calendar.record", systemImage: "plus.circle") {
                        actualDate = max(occurrence.dueDate, Calendar.current.startOfDay(for: .now))
                        postingOccurrence = occurrence
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func money(_ value: Money) -> String { value.amount.formatted(.currency(code: value.currency.code)) }

    private func moveMonth(_ offset: Int) {
        if let value = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) { selectedMonth = value }
    }

    private func reload() {
        do {
            operations = try repository.operations(includeArchived: false)
            accounts = Dictionary(uniqueKeysWithValues: try repository.accounts(includeArchived: true).map { ($0.id, $0) })
            occurrences = try operations.flatMap {
                try RecurrenceCalendar.occurrences(for: $0, from: monthInterval.start, through: monthInterval.end.addingTimeInterval(-0.001), calendar: .current)
            }.sorted { $0.dueDate < $1.dueDate }
            postedIDs = try repository.postedOccurrenceIDs()
        } catch { errorMessage = error.localizedDescription }
    }

    private func calendarDidChange() {
        reload()
        Task { await refreshReminders() }
    }

    @MainActor
    private func toggleReminders() {
        Task {
            if remindersEnabled {
                remindersEnabled = false
                await reminderCoordinator.cancelAll()
                return
            }
            do {
                guard try await reminderCoordinator.requestPermission() else {
                    errorMessage = String(localized: "calendar.reminders.permission-required")
                    return
                }
                remindersEnabled = true
                await refreshReminders()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func refreshReminders() async {
        guard remindersEnabled else { return }
        do {
            try await reminderCoordinator.refresh(operations: operations, postedIDs: postedIDs)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                remindersEnabled = false
                errorMessage = String(localized: "calendar.reminders.permission-required")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive(_ operation: ScheduledOperation) {
        do { var value = operation; value.setArchived(true); try repository.save(value); calendarDidChange() }
        catch { errorMessage = error.localizedDescription }
    }

    private func postSelectedOccurrence() {
        guard let postingOccurrence else { return }
        do {
            _ = try repository.postOccurrence(operationID: postingOccurrence.operationID, dueDate: postingOccurrence.dueDate, occurredAt: actualDate)
            self.postingOccurrence = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ScheduledOperationEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository & WorkTimeRepository & ScheduledOperationRepository
    let existingOperation: ScheduledOperation?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: ScheduledOperationKind = .expense
    @State private var amount = ""
    @State private var currencyCode = "EUR"
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var recurrence: RecurrenceFrequency = .monthly
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var notes = ""
    @State private var accounts: [Account] = []
    @State private var categories: [SalaryOSDomain.Category] = []
    @State private var errorMessage: String?

    private var availableCategories: [SalaryOSDomain.Category] {
        categories.filter { kind == .income ? ($0.kind == .income || $0.kind == .salary) : $0.kind == .expense }
    }
    private var compatibleAccounts: [Account] { accounts.filter { $0.currency.code == currencyCode.uppercased() } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("calendar.name", text: $name)
                Picker("calendar.operation-type", selection: $kind) {
                    Text("calendar.income").tag(ScheduledOperationKind.income)
                    Text("calendar.expense").tag(ScheduledOperationKind.expense)
                }
                .disabled(existingOperation != nil)
                HStack {
                    TextField("calendar.amount", text: $amount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    TextField("calendar.currency", text: $currencyCode).frame(maxWidth: 70).disabled(existingOperation != nil)
                }
                .disabled(existingOperation != nil)
                Picker("transactions.field.account", selection: $accountID) {
                    Text("transactions.field.choose-account").tag(UUID?.none)
                    ForEach(compatibleAccounts) { account in Text(account.name).tag(Optional(account.id)) }
                }
                .disabled(existingOperation != nil)
                Picker("transactions.field.category", selection: $categoryID) {
                    Text("transactions.field.choose-category").tag(UUID?.none)
                    ForEach(availableCategories) { category in Text(category.name).tag(Optional(category.id)) }
                }
                .disabled(existingOperation != nil)
                Picker("calendar.frequency", selection: $recurrence) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { item in Text(item.localizedName).tag(item) }
                }
                .disabled(existingOperation != nil)
                DatePicker("calendar.starts", selection: $startDate, displayedComponents: .date).disabled(existingOperation != nil)
                Toggle("calendar.has-end-date", isOn: $hasEndDate).disabled(existingOperation != nil)
                if hasEndDate { DatePicker("calendar.ends", selection: $endDate, displayedComponents: .date).disabled(existingOperation != nil) }
                TextField("calendar.notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle(existingOperation == nil ? "calendar.add-schedule" : "calendar.edit-schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(name.isEmpty || Decimal(string: amount) == nil || accountID == nil || categoryID == nil)
                }
            }
            .task { load() }
            .onChange(of: kind) { _, _ in categoryID = availableCategories.first?.id }
            .onChange(of: currencyCode) { _, _ in
                if let accountID, !compatibleAccounts.contains(where: { $0.id == accountID }) { self.accountID = nil }
            }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 560)
    }

    private func load() {
        do {
            accounts = try repository.accounts(includeArchived: false)
            categories = try repository.categories(kind: nil, includeArchived: false)
        } catch { errorMessage = error.localizedDescription }
        if let existingOperation {
            name = existingOperation.name
            kind = existingOperation.kind
            amount = NSDecimalNumber(decimal: existingOperation.amount.amount).stringValue
            currencyCode = existingOperation.amount.currency.code
            accountID = existingOperation.accountID
            categoryID = existingOperation.categoryID
            recurrence = existingOperation.recurrence
            startDate = existingOperation.startDate
            if let end = existingOperation.endDate { hasEndDate = true; endDate = end }
            notes = existingOperation.notes ?? ""
        } else {
            accountID = compatibleAccounts.first?.id
            categoryID = availableCategories.first?.id
        }
    }

    private func save() {
        do {
            guard let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
                  let accountID, let categoryID else { throw ScheduledOperationError.invalidAmount }
            let value = try Money(decimal, currency: Currency(code: currencyCode.uppercased()))
            if var existingOperation {
                try existingOperation.update(name: name, amount: value, notes: notes)
                try repository.save(existingOperation)
            } else {
                let operation = try ScheduledOperation(
                    name: name, kind: kind, amount: value, accountID: accountID,
                    categoryID: categoryID, recurrence: recurrence, startDate: startDate,
                    endDate: hasEndDate ? endDate : nil, notes: notes
                )
                try repository.save(operation)
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension RecurrenceFrequency {
    var localizedName: String {
        switch self {
        case .weekly: String(localized: "calendar.weekly")
        case .monthly: String(localized: "calendar.monthly")
        case .yearly: String(localized: "calendar.yearly")
        }
    }
}

private extension ScheduledOperationKind {
    var localizedName: String {
        switch self {
        case .income: String(localized: "calendar.income")
        case .expense: String(localized: "calendar.expense")
        }
    }
}
