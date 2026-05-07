import SwiftUI
import LogWeightCore
#if !os(watchOS)
import Charts
#endif

/// HealthKit history (source of truth). Shared by iOS, watchOS, and macOS.
/// Phase 4: iOS/iPadOS/macOS get a trend chart above the list.
struct HistoryView: View {
    private class Cache {
        static let formatter = WeightFormatter(locale: .current, fractionDigits: 1)
        static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = .current
            return f
        }()
    }

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
    @State private var hoveredWeight: Weight?
    /// Per-row frame in the global coordinate space, refreshed by `HistoryRowFramesKey`.
    @State private var rowFrames: [Weight: CGRect] = [:]
    /// Outer list frame in the global coordinate space, refreshed by `HistoryListFrameKey`.
    @State private var listFrame: CGRect = .zero
#endif
    @Environment(\.dismiss) private var dismiss

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        Cache.formatter
    }

    private var dateFormatter: DateFormatter {
        Cache.dateFormatter
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
            VStack(spacing: 0) {
#if !os(watchOS)
                chartSection
                    .padding(.horizontal)
#endif

                HStack {
                    Text("Recent entries")
                        .font(.headline)
                        .accessibilityIdentifier("history.recent-entries-label")
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if let mutationError = mutationError {
                    Text(mutationError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("history.mutation-error")
                }

#if os(watchOS)
                List {
                    ForEach(weights, id: \.self) { weight in
                        historyRow(for: weight)
                    }
                    .onDelete { offsets in
                        Task { @MainActor in await delete(at: offsets) }
                    }
                }
                .listStyle(.plain)
                .accessibilityIdentifier("history.list")
#else
                // ScrollView + LazyVStack instead of List: SwiftUI's List on
                // iOS/macOS bridges to UIKit cells and does NOT propagate scroll
                // geometry to SwiftUI's `.onGeometryChange`, so the
                // topmost-row-while-scrolling highlight cannot be driven from a
                // List. ScrollView keeps SwiftUI in charge of layout.
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(weights, id: \.self) { weight in
                            historyRow(for: weight)
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .accessibilityIdentifier("history.list")
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { newFrame in
                    listFrame = newFrame
                }
#endif
            }
            .disabled(isDeleting || isSavingEdit)
        }
    }

    /// Single row body shared across iOS, watchOS and macOS. On iOS/macOS the
    /// row is rendered inside a ScrollView+LazyVStack and tracks its global
    /// frame for the topmost-fully-visible highlight. On watchOS it stays
    /// inside a List with native swipeActions for editing.
    @ViewBuilder
    private func historyRow(for weight: Weight) -> some View {
        let rowContent = HStack {
            Text(formatter.format(kilograms: weight.valueInKilograms, in: displayUnit))
                .font(.body.monospacedDigit())
            Spacer()
            Text(dateFormatter.string(from: weight.recordedAt))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .privacySensitive()

#if os(watchOS)
        rowContent
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    editingContext = EditingContext(original: weight)
                    mutationError = nil
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
#else
        rowContent
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowHighlightBackground(for: weight))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(listHighlightedWeight == weight ? .isSelected : [])
            .accessibilityValue(listHighlightedWeight == weight ? "Selected" : "")
            // Track this row's global frame so HistoryView can compute which
            // row is 100% visible. .onGeometryChange fires during ScrollView
            // scroll because LazyVStack stays inside the SwiftUI layout system.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                rowFrames[weight] = newFrame
            }
            .onDisappear {
                rowFrames[weight] = nil
            }
            .onTapGesture {
                editingContext = EditingContext(original: weight)
                mutationError = nil
            }
            .contextMenu {
                Button {
                    editingContext = EditingContext(original: weight)
                    mutationError = nil
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { @MainActor in await delete(weight) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
#endif
    }

#if !os(watchOS)
    /// Shared highlight tint for the topmost-fully-visible row and its matching
    /// chart point. Same colour in both places so the relationship is obvious;
    /// opacity 0.35 stays distinct from the chart's teal line and reads clearly
    /// on light and dark backgrounds.
    private static let highlightTint = Color.yellow.opacity(0.35)

    @ViewBuilder
    private func rowHighlightBackground(for weight: Weight) -> some View {
        if listHighlightedWeight == weight {
            Self.highlightTint
                .accessibilityIdentifier("history.row.highlighted")
        } else {
            Color.clear
        }
    }
#endif

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

    /// Newest weight whose row is fully inside the visible list area.
    /// Returns `nil` until both `rowFrames` and `listFrame` have been populated
    /// by their preference keys (so the very first render does not flag a row
    /// before the list bounds are known). Filters by `weights.contains` so a
    /// row that was visible just before a delete cannot persist as a ghost.
    private var topVisibleWeight: Weight? {
        guard listFrame != .zero else { return nil }
        let listTop = listFrame.minY
        let listBottom = listFrame.maxY
        let knownWeights = Set(weights)
        let visible = rowFrames.compactMap { (weight, frame) -> Weight? in
            guard knownWeights.contains(weight) else { return nil }
            return (frame.minY >= listTop && frame.maxY <= listBottom) ? weight : nil
        }
        return visible.max(by: { $0.recordedAt < $1.recordedAt })
    }

    /// Drag-driven `hoveredWeight` (crosshair) wins over scroll-driven
    /// `topVisibleWeight` so an active drag is never overridden by a passive
    /// scroll position.
    private var listHighlightedWeight: Weight? {
        hoveredWeight ?? topVisibleWeight
    }

    /// Same as `listHighlightedWeight`, but `nil` when the candidate's date
    /// falls outside the selected chart range — keeps the row highlighted in
    /// the list while leaving the chart point in its default style.
    private var chartHighlightedWeight: Weight? {
        guard let candidate = listHighlightedWeight else { return nil }
        if let cutoff = selectedRange.cutoffDate(referenceDate: Date()),
           candidate.recordedAt < cutoff {
            return nil
        }
        return candidate
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
                hoveredWeight = nil
            }

            if filteredChartWeights.isEmpty {
                ContentUnavailableView("No data in selected range", systemImage: "chart.xyaxis.line")
                    .frame(height: 180)
            } else {
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
                    .foregroundStyle(chartHighlightedWeight == weight ? Color.yellow : .teal)
                    // Note: chart point uses full-opacity yellow so it stands out
                    // against the line; the row uses Self.highlightTint (yellow .35)
                    // so the tint reads on the row's lighter background.
                    .symbolSize(
                        chartHighlightedWeight == weight
                            ? 140
                            : (hoveredWeight?.recordedAt == weight.recordedAt ? 100 : 50)
                    )
                    .opacity(
                        chartHighlightedWeight == weight
                            ? 1
                            : (hoveredWeight?.recordedAt == weight.recordedAt ? 1 : 0.6)
                    )

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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geo[plotFrame]

                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 8)
                                        .onChanged { value in
                                            let xInPlot = value.location.x - frame.minX
                                            if let hoverDate = proxy.value(atX: xInPlot, as: Date.self) {
                                                let closest = WeightNearestFinder.closest(to: hoverDate, in: filteredChartWeights)
                                                // Snap hover state to an existing sample so chart domain
                                                // never expands beyond the selected range while scrubbing.
                                                hoveredXDate = closest?.recordedAt
                                                hoveredWeight = closest
                                            }
                                        }
                                        .onEnded { _ in
                                            hoveredXDate = nil
                                            hoveredWeight = nil
                                        }
                                )

                            if let hoveredXDate = hoveredXDate,
                               let closest = WeightNearestFinder.closest(to: hoveredXDate, in: filteredChartWeights),
                               let xInPlot = proxy.position(forX: closest.recordedAt) {
                                let tooltipHalfWidth: CGFloat = 64
                                let screenX = min(max(frame.minX + xInPlot, tooltipHalfWidth), geo.size.width - tooltipHalfWidth)
                                ChartHoverOverlay(
                                    weight: closest,
                                    displayUnit: displayUnit,
                                    formatter: formatter,
                                    dateFormatter: dateFormatter
                                )
                                .position(x: screenX, y: frame.minY + 28)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .accessibilityIdentifier("history.chart")
            }
        }
        .padding(.vertical, 4)
    }

    private func displayValue(for weight: Weight) -> Double {
        Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
            .converted(to: displayUnit.unitMass)
            .value
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

#if !os(watchOS)
    /// Single-weight delete for the iOS/macOS context menu. watchOS still
    /// deletes via List's `.onDelete(IndexSet)` path above.
    private func delete(_ weight: Weight) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await store.delete(weight)
            await load()
        } catch HealthKitError.deleteFailed(let code) {
            mutationError = "Couldn't delete entry (code \(code))."
        } catch {
            mutationError = "Unexpected error deleting entry."
        }
    }
#endif
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
        .privacySensitive()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.teal)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
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
