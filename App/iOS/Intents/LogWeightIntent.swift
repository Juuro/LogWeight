import AppIntents
import Foundation
import LogWeightCore

/// Logs a weight given by the user (Siri, Shortcuts, Action Button, Spotlight).
///
/// Runs in the app process without opening the app. Decision logic lives in
/// `WeightLogger`; writes go through `HKHealthStoreAdapter` (a `HealthKitStore`).
/// Never logs weights: only literal event names and numeric error codes.
struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Weight"
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    static let description = IntentDescription("Saves your weight to Apple Health.")

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$weight)") {
            \.$unit
        }
    }

    /// A plain number: Siri cannot resolve spoken decimals ("68,9 Kilo") into a
    /// measurement parameter, but handles numbers (see research R1).
    @Parameter(title: "Weight", requestValueDialog: "What's your weight?")
    var weight: Double

    /// Optional. Defaults to the unit chosen in LogWeight's settings.
    @Parameter(title: "Unit")
    var unit: WeightUnitOption?

    func perform() async throws -> some IntentResult & ReturnsValue<Measurement<UnitMass>> & ProvidesDialog {
        let unit = unit?.weightUnit ?? WeightDisplayPreferences.preferredUnit()
        let kilograms = Measurement(value: weight, unit: unit.unitMass)
            .converted(to: .kilograms).value
        let logger = WeightLogger(store: HKHealthStoreAdapter())

        switch await logger.evaluate(kilograms: kilograms) {
        case .ready(let toSave):
            let saved = try await save(toSave, using: logger)
            return Self.result(for: saved, unit: unit)
        case .accessNotGranted:
            SecurityLog.event("weight_log_denied")
            throw LogWeightIntentError.accessNotGranted
        case .invalid:
            throw LogWeightIntentError.invalid
        case .needsConfirmation(let pending, _):
            try await confirmUnusualValue(pending, unit: unit)
            let saved = try await save(pending, using: logger)
            return Self.result(for: saved, unit: unit)
        case .duplicate(let existing):
            SecurityLog.event("weight_log_duplicate")
            return Self.result(for: existing, unit: unit, alreadyLogged: true)
        }
    }

    /// Asks the user to confirm an unusual value. If the question cannot be
    /// answered (the user declines, or the run is unattended, e.g. an
    /// automation) nothing is saved.
    ///
    /// `requestConfirmation(result:)` is deprecated, but its replacement
    /// (`requestConfirmation(conditions:actionName:dialog:)`) needs iOS 18;
    /// see specs/002-siri-log-weight/research.md R5.
    private func confirmUnusualValue(_ pending: Weight, unit: WeightUnit) async throws {
        let text = WeightFormatter().format(kilograms: pending.valueInKilograms, in: unit)
        do {
            try await requestConfirmation(
                result: .result(dialog: IntentDialog("\(text) looks unusual. Log it anyway?"))
            )
        } catch {
            SecurityLog.event("weight_log_declined")
            throw LogWeightIntentError.declined
        }
    }

    /// Writes the weight and refreshes widgets. Throws the dialog to show on failure.
    private func save(_ toSave: Weight, using logger: WeightLogger) async throws -> Weight {
        switch await logger.save(toSave) {
        case .saved(let saved):
            SecurityLog.event("weight_log_saved")
            SharedWeightEntryStore.save(
                WeightEntry(value: saved.valueInKilograms, date: saved.recordedAt)
            )
            WidgetTimelineRefresh.reloadEntryAndChartWidgets()
            return saved
        case .accessNotGranted:
            throw LogWeightIntentError.accessNotGranted
        case .invalid:
            throw LogWeightIntentError.invalid
        case .alreadyLogged, .declined, .failed:
            throw LogWeightIntentError.failed
        }
    }

    static func result(
        for weight: Weight,
        unit: WeightUnit,
        alreadyLogged: Bool = false
    ) -> some IntentResult & ReturnsValue<Measurement<UnitMass>> & ProvidesDialog {
        let text = WeightFormatter().format(kilograms: weight.valueInKilograms, in: unit)
        let value = Measurement(value: weight.value(in: unit), unit: unit.unitMass)
        let dialog: IntentDialog = alreadyLogged
            ? IntentDialog("Already logged \(text).")
            : IntentDialog("Logged \(text).")
        return .result(value: value, dialog: dialog)
    }
}

/// Unit choice for the Shortcuts editor. Siri uses the preferred unit when it is omitted.
enum WeightUnitOption: String, AppEnum {
    case kilograms
    case pounds

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Unit")
    static let caseDisplayRepresentations: [WeightUnitOption: DisplayRepresentation] = [
        .kilograms: DisplayRepresentation(title: "Kilograms"),
        .pounds: DisplayRepresentation(title: "Pounds"),
    ]

    var weightUnit: WeightUnit {
        switch self {
        case .kilograms: return .kilograms
        case .pounds: return .pounds
        }
    }
}

/// Errors shown to the user as the spoken or on-screen dialog.
enum LogWeightIntentError: Error, CustomLocalizedStringResourceConvertible {
    case accessNotGranted
    case invalid
    case declined
    case failed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .accessNotGranted: "Open LogWeight once to allow access to Apple Health."
        case .invalid: "Enter a valid weight."
        case .declined: "Not logged. That weight looks unusual."
        case .failed: "Couldn't log your weight. Please try again."
        }
    }
}
