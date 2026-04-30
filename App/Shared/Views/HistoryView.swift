import SwiftUI
import LogWeightCore
#if !os(watchOS)
import Charts
#endif

/// HealthKit history (source of truth). Shared by iOS, watchOS, and macOS.
/// Phase 4: iOS/iPadOS/macOS get a trend chart above the list.
struct HistoryView: View {

    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @State private var weights: [Weight] = []
    @State private var loadError: String?
    @State private var mutationError: String?
    @State private var isDeleting = false
    @State private var editingContext: EditingContext?
    @State private var isSavingEdit = false
    @Environment(\.dismiss) private var dismiss

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = .current
        return f
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
#if os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button("Close") { dismiss() }
                    }
#else
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
#endif
                }
                .sheet(item: $editingContext, onDismiss: {
                    mutationError = nil
                }) { context in
                    HistoryWeightEditSheet(
                        original: context.original,
                        displayUnit: displayUnit,
                        formatter: formatter,
                        isSaving: $isSavingEdit,
                        store: store,
                        onSave: {
                            mutationError = nil
                            await load()
                            editingContext = nil
                        },
                        onDismiss: {
                            editingContext = nil
                        },
                        onError: { message in
                            mutationError = message
                        }
                    )
#if os(macOS)
                    .frame(minWidth: 320, minHeight: 260)
#endif
                }
                .task {
                    await load()
                }
        }
    }

    /// Stable identity per edit session for `sheet(item:)`.
    private struct EditingContext: Identifiable {
        let id = UUID()
        let original: Weight
    }

    @ViewBuilder
    private var content: some View {
        if let loadError = loadError {
            VStack(spacing: 12) {
                Text("Couldn't read your weight history.")
                    .font(.headline)
                Text(loadError)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else if weights.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "scalemass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No weights yet.")
                    .font(.headline)
                Text("Save your first weight on the entry screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            List {
                if let mutationError = mutationError {
                    Section {
                        Text(mutationError)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
#if !os(watchOS)
                Section {
                    chartSection
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
#endif
                Section {
                    ForEach(weights, id: \.self) { weight in
                        HStack {
                            Text(formatter.format(kilograms: weight.valueInKilograms, in: displayUnit))
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text(dateFormatter.string(from: weight.recordedAt))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .privacySensitive()
#if os(iOS)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingContext = EditingContext(original: weight)
                                mutationError = nil
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
#endif
#if os(macOS) || os(watchOS)
                        .contextMenu {
                            Button {
                                editingContext = EditingContext(original: weight)
                                mutationError = nil
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
#endif
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                } header: {
                    Text("Recent entries")
                }
            }
            .listStyle(.plain)
            .disabled(isDeleting || isSavingEdit)
        }
    }

#if !os(watchOS)
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend")
                .font(.headline)
            Chart(weights.sorted(by: { $0.recordedAt < $1.recordedAt }), id: \.self) { weight in
                LineMark(
                    x: .value("Date", weight.recordedAt),
                    y: .value("Weight", displayValue(for: weight))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.teal)

                PointMark(
                    x: .value("Date", weight.recordedAt),
                    y: .value("Weight", displayValue(for: weight))
                )
                .foregroundStyle(.teal)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .accessibilityIdentifier("history.chart")
        }
        .padding(.vertical, 4)
    }

    private func displayValue(for weight: Weight) -> Double {
        Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
            .converted(to: displayUnit.unitMass)
            .value
    }
#endif

    private func load() async {
        do {
            let result = try await store.recentWeights(limit: 50)
            weights = result
            loadError = nil
            mutationError = nil
        } catch HealthKitError.queryFailed(let code) {
            loadError = "HealthKit query failed (code \(code))."
        } catch {
            loadError = "Unexpected error reading from Apple Health."
        }
    }

    private func delete(at offsets: IndexSet) async {
        isDeleting = true
        defer { isDeleting = false }

        var toDelete: [Weight] = []
        for index in offsets where weights.indices.contains(index) {
            toDelete.append(weights[index])
        }

        do {
            for weight in toDelete {
                try await store.delete(weight)
            }
            await load()
        } catch HealthKitError.deleteFailed(let code) {
            mutationError = "Couldn't delete entry (code \(code))."
        } catch {
            mutationError = "Unexpected error deleting entry."
        }
    }
}

/// Form to edit weight and date/time for a single history row.
private struct HistoryWeightEditSheet: View {

    let original: Weight
    let displayUnit: WeightUnit
    let formatter: WeightFormatter
    @Binding var isSaving: Bool
    let store: HealthKitStore

    /// Called after a successful persist and reload; caller dismisses sheet.
    var onSave: () async -> Void
    var onDismiss: () -> Void
    /// Surface errors without clearing the sheet.
    var onError: (String) -> Void

    @State private var editedText: String
    @State private var editedDate: Date
    @State private var validationMessage: String?
    @FocusState private var valueFieldFocused: Bool

    /// Body weight bounds (matches `EntryState` clamp semantics).
    private static func clampToBodyRangeKilograms(_ kg: Double) -> Double {
        max(1.0, min(500.0, kg))
    }

    init(
        original: Weight,
        displayUnit: WeightUnit,
        formatter: WeightFormatter,
        isSaving: Binding<Bool>,
        store: HealthKitStore,
        onSave: @escaping () async -> Void,
        onDismiss: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.original = original
        self.displayUnit = displayUnit
        self.formatter = formatter
        self._isSaving = isSaving
        self.store = store
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.onError = onError

        let initialFormatted = formatter.format(kilograms: original.valueInKilograms, in: displayUnit)
        self._editedText = State(initialValue: initialFormatted)
        self._editedDate = State(initialValue: original.recordedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Weight", text: $editedText)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .focused($valueFieldFocused)
                        .privacySensitive()
                } footer: {
                    Text("Use your locale’s decimal separator (\(Locale.current.decimalSeparator ?? ".")). Values are saved in \(displayUnit.shortDisplayName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Date & time") {
                    DatePicker(
                        "Recorded at",
                        selection: $editedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .privacySensitive()
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await commit() }
                    }
                    .disabled(isSaving)
                }
#if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        valueFieldFocused = false
                    }
                }
#endif
            }
            .disabled(isSaving)
        }
#if os(macOS)
        .frame(minWidth: 320, idealWidth: 400, minHeight: 240, idealHeight: 320)
#endif
    }

    private func commit() async {
        validationMessage = nil
        let cleaned = editedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parsedKg = formatter.parseToKilograms(cleaned, unit: displayUnit) else {
            validationMessage = "Couldn’t read that weight. Check the number format."
            return
        }

        let clampedKg = Self.clampToBodyRangeKilograms(parsedKg)
        if abs(parsedKg - clampedKg) > 0.000_000_1 {
            validationMessage = "Weight must be between 1 and 500 kg."
            return
        }

        let updated = Weight(valueInKilograms: clampedKg, recordedAt: editedDate)

        isSaving = true
        defer { isSaving = false }

        do {
            try await store.requestAuthorization()
            try await store.replace(old: original, new: updated)
            await onSave()
        } catch HealthKitError.authorizationDenied {
            onError("Health access denied. Allow LogWeight in Settings → Privacy & Security → Health.")
        } catch HealthKitError.healthDataUnavailable {
            onError("Health data isn’t available on this device.")
        } catch HealthKitError.replaceFailed(let code) {
            onError("Couldn't save edit (code \(code)).")
        } catch HealthKitError.queryFailed(let code) {
            onError("Couldn't read entries (code \(code)).")
        } catch {
            onError("Unexpected error saving edit.")
        }
    }
}

#if DEBUG
#Preview("History") {
    HistoryView(store: InMemoryHealthKitStore(samples: [
        Weight(valueInKilograms: 80.0, recordedAt: .now),
        Weight(valueInKilograms: 79.5, recordedAt: .now.addingTimeInterval(-86_400))
    ]))
}
#endif
