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
#if !os(watchOS)
    @State private var selectedRange: ChartRange = .oneMonth
    @State private var hoveredXDate: Date?
#endif
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
#if os(iOS) || os(watchOS)
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
#if os(macOS)
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
                        Task { @MainActor in await delete(at: offsets) }
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
    private enum ChartRange: String, CaseIterable {
        case oneWeek
        case oneMonth
        case threeMonths
        case sixMonths
        case oneYear
        case all

        var label: String {
            switch self {
            case .oneWeek: "1W"
            case .oneMonth: "1M"
            case .threeMonths: "3M"
            case .sixMonths: "6M"
            case .oneYear: "1Y"
            case .all: "All"
            }
        }

        func cutoffDate(referenceDate: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .oneWeek:
                calendar.date(byAdding: .day, value: -7, to: referenceDate)
            case .oneMonth:
                calendar.date(byAdding: .month, value: -1, to: referenceDate)
            case .threeMonths:
                calendar.date(byAdding: .month, value: -3, to: referenceDate)
            case .sixMonths:
                calendar.date(byAdding: .month, value: -6, to: referenceDate)
            case .oneYear:
                calendar.date(byAdding: .year, value: -1, to: referenceDate)
            case .all:
                nil
            }
        }
    }

    private var filteredChartWeights: [Weight] {
        let sorted = weights.sorted(by: { $0.recordedAt < $1.recordedAt })
        guard let cutoff = selectedRange.cutoffDate(referenceDate: Date()) else {
            return sorted
        }
        return sorted.filter { $0.recordedAt >= cutoff }
    }

    private var chartSection: some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text("Trend")
                .font(.headline)
            Picker("Range", selection: $selectedRange) {
                ForEach(ChartRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) { _, _ in
                hoveredXDate = nil
            }

            if filteredChartWeights.isEmpty {
                ContentUnavailableView("No data in selected range", systemImage: "chart.xyaxis.line")
                    .frame(height: 180)
            } else {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            Chart(filteredChartWeights, id: \.self) { weight in
                                LineMark(
                                    x: .value("Date", weight.recordedAt),
                                    y: .value("Weight", displayValue(for: weight))
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.teal)

                                PointMark(
                                    x: .value("Date", weight.recordedAt),
                                    y: .value("Weight", displayValue(for: weight))
                                )
                                .foregroundStyle(.teal)
                                .symbolSize(isClosestToHoveredDate(weight) ? 100 : 50)
                                .opacity(isClosestToHoveredDate(weight) ? 1 : 0.6)

                                if let hoveredXDate = hoveredXDate {
                                    RuleMark(x: .value("Hover", hoveredXDate))
                                        .foregroundStyle(.gray.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                }
                            }
                            .chartYScale(domain: chartYDomain)
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let xPosition = value.location.x
                                        let chartWidth = geometry.size.width
                                        let progress = max(0, min(1, xPosition / chartWidth))

                                        guard let minDate = filteredChartWeights.first?.recordedAt,
                                              let maxDate = filteredChartWeights.last?.recordedAt else {
                                            return
                                        }

                                        let timeInterval = maxDate.timeIntervalSince(minDate)
                                        let hoverDate = minDate.addingTimeInterval(timeInterval * progress)
                                        hoveredXDate = hoverDate
                                    }
                                    .onEnded { _ in
                                        hoveredXDate = nil
                                    }
                            )

                            if let hoveredXDate = hoveredXDate,
                               let closest = findClosestWeight(to: hoveredXDate, in: filteredChartWeights) {
                                ChartHoverOverlay(
                                    weight: closest,
                                    displayUnit: displayUnit,
                                    formatter: formatter,
                                    dateFormatter: dateFormatter
                                )
                                .offset(y: -100)
                            }
                        }
                        .frame(height: 180)
                        .accessibilityIdentifier("history.chart")
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(.vertical, 4)
    }

    private func displayValue(for weight: Weight) -> Double {
        Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
            .converted(to: displayUnit.unitMass)
            .value
    }

    private func findClosestWeight(to date: Date, in weights: [Weight]) -> Weight? {
        weights.min { a, b in
            abs(a.recordedAt.timeIntervalSince(date)) < abs(b.recordedAt.timeIntervalSince(date))
        }
    }

    private func isClosestToHoveredDate(_ weight: Weight) -> Bool {
        guard let hoveredXDate = hoveredXDate else { return false }
        guard let closest = findClosestWeight(to: hoveredXDate, in: filteredChartWeights) else { return false }
        return weight.recordedAt == closest.recordedAt
    }

    /// Dynamic chart domain anchored around the user's current weight range.
    /// Keeps all points visible while avoiding a zero-based axis that flattens trends.
    private var chartYDomain: ClosedRange<Double> {
        let values = filteredChartWeights.map(displayValue(for:))
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0.0...1.0
        }

        let span = maximum - minimum
        let minimumVisibleSpan = 1.0
        let padding = max(span * 0.25, 0.4)

        let lowerBound = min(minimum, minimum - padding)
        let adjustedUpper = maximum + padding
        let upperBound = max(adjustedUpper, lowerBound + minimumVisibleSpan)

        return lowerBound...upperBound
    }
#endif

    private func load() async {
        do {
            let result = try await store.recentWeights(limit: 5_000)
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
    @State private var editedKilograms: Double
    @State private var editedDate: Date
    @State private var selectedDay: Int
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    @State private var validationMessage: String?
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
        let initialDateComponents = Calendar.current.dateComponents([.day, .month, .year], from: original.recordedAt)
        self._editedText = State(initialValue: initialFormatted)
        self._editedKilograms = State(initialValue: original.valueInKilograms)
        self._editedDate = State(initialValue: original.recordedAt)
        self._selectedDay = State(initialValue: initialDateComponents.day ?? 1)
        self._selectedMonth = State(initialValue: initialDateComponents.month ?? 1)
        self._selectedYear = State(initialValue: initialDateComponents.year ?? Calendar.current.component(.year, from: .now))
    }

    var body: some View {
#if os(watchOS)
        NavigationStack {
            VStack(spacing: 6) {
                VStack(spacing: 10) {
                    Text(formatter.format(kilograms: editedKilograms, in: displayUnit))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .privacySensitive()

                    HStack(spacing: 16) {
                        Button {
                            editedKilograms = Self.clampToBodyRangeKilograms(editedKilograms - 0.1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Decrease weight")

                        Button {
                            editedKilograms = Self.clampToBodyRangeKilograms(editedKilograms + 0.1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Increase weight")
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        fieldTag("Day")
                            .frame(width: 44, alignment: .leading)
                        fieldTag("Month")
                            .frame(width: 44, alignment: .leading)
                        fieldTag("Year")
                            .frame(width: 62, alignment: .leading)
                    }
                    .frame(width: 156, alignment: .leading)

                    HStack(spacing: 3) {
                        Picker("Day", selection: $selectedDay) {
                            ForEach(dayOptions, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(width: 44, height: 74)
                        .clipped()
                        .tint(.primary)
                        .onChange(of: selectedDay) { _, _ in
                            updateEditedDateFromSelection()
                        }

                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(width: 44, height: 74)
                        .clipped()
                        .tint(.primary)
                        .onChange(of: selectedMonth) { _, _ in
                            normalizeDayAndUpdateDate()
                        }

                        Picker("Year", selection: $selectedYear) {
                            ForEach(yearOptions, id: \.self) { year in
                                Text(String(format: "%04d", year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(width: 62, height: 74)
                        .clipped()
                        .tint(.primary)
                        .onChange(of: selectedYear) { _, _ in
                            normalizeDayAndUpdateDate()
                        }
                    }
                    .scaleEffect(y: 0.88, anchor: .top)
                    .frame(height: 70)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
                .privacySensitive()
            }
            .padding(.top, 4)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { @MainActor in await commit() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save")
                    .disabled(isSaving)
                }
            }
            .disabled(isSaving)
        }
#else
        NavigationStack {
#if os(iOS)
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text(formatter.format(kilograms: editedKilograms, in: displayUnit))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .fontWeight(.semibold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .privacySensitive()

                    HStack(spacing: 16) {
                        Button {
                            editedKilograms = Self.clampToBodyRangeKilograms(editedKilograms - 0.1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.title)
                                .frame(width: 88, height: 88)
                                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Decrease weight")

                        Button {
                            editedKilograms = Self.clampToBodyRangeKilograms(editedKilograms + 0.1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title)
                                .frame(width: 88, height: 88)
                                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase weight")
                    }

                    Text("Use − / + to adjust weight in 0.1 \(displayUnit.shortDisplayName) steps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recorded at")
                        .font(.headline)
                    DatePicker(
                        "",
                        selection: $editedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .privacySensitive()
                }
                .frame(maxWidth: .infinity)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { @MainActor in await commit() }
                    }
                    .disabled(isSaving)
                }
            }
            .disabled(isSaving)
#else
            Form {
                Section {
                    TextField("Weight", text: $editedText)
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
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { @MainActor in await commit() }
                    }
                    .disabled(isSaving)
                }
            }
            .disabled(isSaving)
#endif
        }
#if os(macOS)
        .frame(minWidth: 320, idealWidth: 400, minHeight: 240, idealHeight: 320)
#endif
#endif
    }

    @ViewBuilder
    private func fieldTag(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.secondary)
    }

    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let startYear = min(currentYear - 10, selectedYear)
        let endYear = max(currentYear + 10, selectedYear)
        return Array(startYear...endYear)
    }

    private var dayOptions: [Int] {
        Array(1...daysInSelectedMonth)
    }

    private var daysInSelectedMonth: Int {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        guard
            let date = Calendar.current.date(from: components),
            let range = Calendar.current.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }

    private func normalizeDayAndUpdateDate() {
        if selectedDay > daysInSelectedMonth {
            selectedDay = daysInSelectedMonth
        }
        updateEditedDateFromSelection()
    }

    private func updateEditedDateFromSelection() {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: editedDate)
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second

        if let updatedDate = calendar.date(from: components) {
            editedDate = updatedDate
        }
    }

    private func commit() async {
        validationMessage = nil
#if os(watchOS) || os(iOS)
        let clampedKg = Self.clampToBodyRangeKilograms(editedKilograms)
        let updated = Weight(valueInKilograms: clampedKg, recordedAt: editedDate)
#else
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
#endif
        if updated.recordedAt > .now {
            validationMessage = "Date/time can’t be in the future."
            return
        }
        if updated == original {
            await onSave()
            return
        }

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

#if !os(watchOS)
private struct ChartHoverOverlay: View {
    let weight: Weight
    let displayUnit: WeightUnit
    let formatter: WeightFormatter
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 4) {
            Text(formatter.format(kilograms: weight.valueInKilograms, in: displayUnit))
                .font(.system(.body, design: .rounded).monospacedDigit())
                .fontWeight(.semibold)
                .privacySensitive()
            Text(dateFormatter.string(from: weight.recordedAt))
                .font(.caption2)
                .privacySensitive()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .foregroundStyle(.teal)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
#endif

#if DEBUG
#Preview("History") {
    HistoryView(store: InMemoryHealthKitStore(samples: [
        Weight(valueInKilograms: 80.0, recordedAt: .now),
        Weight(valueInKilograms: 79.5, recordedAt: .now.addingTimeInterval(-86_400))
    ]))
}
#endif
