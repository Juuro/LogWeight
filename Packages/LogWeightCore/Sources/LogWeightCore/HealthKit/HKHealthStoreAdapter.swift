import Foundation
import HealthKit

/// Production `HealthKitStore` backed by a real `HKHealthStore`.
///
/// Lives only on platforms that ship HealthKit (iOS, iPadOS, watchOS, macOS).
/// tvOS does not ship HealthKit; LogWeight does not target tvOS.
public final class HKHealthStoreAdapter: HealthKitStore {

    private let healthStore: HKHealthStore
    private let bodyMassType: HKQuantityType

    public init() {
        self.healthStore = HKHealthStore()
        // Force-unwrap is safe: bodyMass is a system-defined identifier that
        // is guaranteed to resolve on every platform that ships HealthKit.
        // We assert at init so a future SDK regression is caught immediately.
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            preconditionFailure("HKQuantityTypeIdentifier.bodyMass is not available; the SDK is broken.")
        }
        self.bodyMassType = type
    }

    public func authorizationStatus() async -> HealthKitAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .sharingDenied
        }
        switch healthStore.authorizationStatus(for: bodyMassType) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
    }

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        let toShare: Set<HKSampleType> = [bodyMassType]
        let toRead: Set<HKObjectType> = [bodyMassType]
        try await healthStore.requestAuthorization(toShare: toShare, read: toRead)
    }

    public func save(_ weight: Weight) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight.valueInKilograms)
        let sample = HKQuantitySample(
            type: bodyMassType,
            quantity: quantity,
            start: weight.recordedAt,
            end: weight.recordedAt
        )
        do {
            try await healthStore.save(sample)
        } catch let error as HKError {
            throw HealthKitError.saveFailed(reasonCode: error.code.rawValue)
        } catch {
            throw HealthKitError.saveFailed(reasonCode: -1)
        }
    }

    public func recentWeights(limit: Int) async throws -> [Weight] {
        guard HKHealthStore.isHealthDataAvailable() else {
            return []
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Weight], Error>) in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error as? HKError {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: error.code.rawValue))
                    return
                }
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: (error as NSError).code))
                    return
                }
                let weights: [Weight] = (samples ?? []).compactMap { sample in
                    guard let q = sample as? HKQuantitySample else { return nil }
                    let kg = q.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    return Weight(valueInKilograms: kg, recordedAt: q.endDate)
                }
                continuation.resume(returning: weights)
            }
            healthStore.execute(query)
        }
    }

    public func delete(_ weight: Weight) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        let start = weight.recordedAt.addingTimeInterval(-1)
        let end = weight.recordedAt.addingTimeInterval(1)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let matchingSample = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Error>) in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error as? HKError {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: error.code.rawValue))
                    return
                }
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: (error as NSError).code))
                    return
                }

                let target = weight.valueInKilograms
                let sample = (samples ?? [])
                    .compactMap { $0 as? HKQuantitySample }
                    .filter { quantitySample in
                        let value = quantitySample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                        return abs(value - target) < 0.0005
                    }
                    .min(by: { lhs, rhs in
                        abs(lhs.endDate.timeIntervalSince(weight.recordedAt))
                        < abs(rhs.endDate.timeIntervalSince(weight.recordedAt))
                    })
                continuation.resume(returning: sample)
            }
            healthStore.execute(query)
        }

        guard let matchingSample else {
            throw HealthKitError.deleteFailed(reasonCode: -1)
        }

        do {
            try await healthStore.delete(matchingSample)
        } catch let error as HKError {
            throw HealthKitError.deleteFailed(reasonCode: error.code.rawValue)
        } catch {
            throw HealthKitError.deleteFailed(reasonCode: (error as NSError).code)
        }
    }

    public func observeChanges() -> AsyncStream<Void> {
        // Implementation contract: see HealthKitStore protocol comments.
        // We hold the query in a Task-scoped reference so onTermination can stop it.
        let healthStore = self.healthStore
        let bodyMassType = self.bodyMassType
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)

        // The query itself must be alive for the lifetime of the stream.
        // We keep it in a class-bound holder so onTermination can release it.
        let holder = QueryHolder()
        let query = HKObserverQuery(sampleType: bodyMassType, predicate: nil) { _, completion, _ in
            continuation.yield(())
            completion()
        }
        holder.query = query
        healthStore.execute(query)

        continuation.onTermination = { @Sendable _ in
            if let q = holder.query {
                healthStore.stop(q)
                holder.query = nil
            }
        }
        return stream
    }

    /// Holds a strong reference to the active observer query so we can stop it
    /// on stream termination. Class-bound so the closure capture is reference-typed
    /// and reassignment works across the actor boundary.
    private final class QueryHolder: @unchecked Sendable {
        var query: HKObserverQuery?
    }
}
