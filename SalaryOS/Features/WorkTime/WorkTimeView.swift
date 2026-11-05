import SalaryOSDomain
import SwiftUI

struct WorkTimeView: View {
    let repository: any WorkTimeRepository
    @State private var selectedMonth = Date.now
    @State private var entries: [WorkEntry] = []
    @State private var summaries: [WorkTimeSummary] = []
    @State private var editingEntry: WorkEntry?
    @State private var isEditorPresented = false
    @State private var errorMessage: String?

    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: selectedMonth) ?? DateInterval(start: selectedMonth, duration: 31 * 24 * 60 * 60)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("work.previous-month")
                    Spacer()
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("work.next-month")
                }
            }
            if !summaries.isEmpty {
                Section("work.month-summary") {
                    ForEach(Array(summaries.enumerated()), id: \.offset) { row in
                        let summary = row.element
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.employer).font(.headline)
                                Text("\(summary.entryCount) · \(summary.hours.formatted(.number.precision(.fractionLength(1)))) \(String(localized: "work.hours"))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(money(summary.estimatedGross)).font(.headline)
                                Text("work.estimated-gross").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    Text("work.estimate-disclaimer")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Section { ContentUnavailableView("work.empty.title", systemImage: "clock", description: Text("work.empty.description")) }
            }
            Section("work.entries") {
                if entries.isEmpty {
                    Text("work.no-entries").foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        Button { editingEntry = entry; isEditorPresented = true } label: {
                            entryRow(entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("work.edit", systemImage: "pencil") { editingEntry = entry; isEditorPresented = true }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("navigation.work-time")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("work.add-entry", systemImage: "plus") { editingEntry = nil; isEditorPresented = true }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: reload) {
            WorkEntryEditor(repository: repository, existingEntry: editingEntry, initialDate: selectedMonth)
        }
        .task { reload() }
        .onChange(of: selectedMonth) { _, _ in reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func entryRow(_ entry: WorkEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.description).font(.headline)
                Text("\(entry.employer) · \(entry.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(entry.startedAt.formatted(date: .omitted, time: .shortened))–\(entry.endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                if entry.unpaidBreakMinutes > 0 {
                    Text("\(entry.unpaidBreakMinutes) \(String(localized: "work.break-minutes.label"))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.paidHours.formatted(.number.precision(.fractionLength(1)))) \(String(localized: "work.hours"))")
                    .font(.subheadline.monospacedDigit())
                if let gross = try? entry.estimatedGross() {
                    Text(money(gross)).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func money(_ value: Money) -> String { value.amount.formatted(.currency(code: value.currency.code)) }

    private func moveMonth(_ offset: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) { selectedMonth = next }
    }

    private func reload() {
        do {
            let end = monthInterval.end.addingTimeInterval(-0.001)
            entries = try repository.entries(from: monthInterval.start, through: end)
            summaries = try WorkTimeCalculator.monthlySummaries(entries: entries, monthContaining: selectedMonth, calendar: .current)
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct WorkEntryEditor: View {
    let repository: any WorkTimeRepository
    let existingEntry: WorkEntry?
    let initialDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var employer = ""
    @State private var description = ""
    @State private var startedAt = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var endedAt = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? Date.now.addingTimeInterval(8 * 3600)
    @State private var breakMinutes = "30"
    @State private var hourlyRate = ""
    @State private var currencyCode = "EUR"
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("work.employer", text: $employer)
                TextField("work.description", text: $description)
                DatePicker("work.started-at", selection: $startedAt)
                DatePicker("work.ended-at", selection: $endedAt)
                TextField("work.break-minutes", text: $breakMinutes)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                HStack {
                    TextField("work.hourly-rate", text: $hourlyRate)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    TextField("work.currency", text: $currencyCode).frame(maxWidth: 70)
                }
                TextField("work.notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle(existingEntry == nil ? "work.add-entry" : "work.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(employer.isEmpty || description.isEmpty || Decimal(string: hourlyRate) == nil)
                }
            }
            .task { load() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 460)
    }

    private func load() {
        guard let existingEntry else {
            startedAt = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
            endedAt = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: initialDate) ?? initialDate.addingTimeInterval(8 * 3600)
            return
        }
        employer = existingEntry.employer
        description = existingEntry.description
        startedAt = existingEntry.startedAt
        endedAt = existingEntry.endedAt
        breakMinutes = String(existingEntry.unpaidBreakMinutes)
        hourlyRate = NSDecimalNumber(decimal: existingEntry.hourlyRate.amount).stringValue
        currencyCode = existingEntry.hourlyRate.currency.code
        notes = existingEntry.notes ?? ""
    }

    private func save() {
        do {
            guard let rate = Decimal(string: hourlyRate.replacingOccurrences(of: ",", with: ".")),
                  let pause = Int(breakMinutes) else { throw WorkTimeError.invalidBreak }
            let entry = try WorkEntry(
                id: existingEntry?.id ?? UUID(), employer: employer, description: description,
                startedAt: startedAt, endedAt: endedAt, unpaidBreakMinutes: pause,
                hourlyRate: Money(rate, currency: Currency(code: currencyCode.uppercased())), notes: notes,
                createdAt: existingEntry?.createdAt ?? .now
            )
            try repository.save(entry)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
