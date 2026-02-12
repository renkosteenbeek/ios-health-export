import HealthKit
import CoreLocation
import Observation

@Observable
@MainActor
final class HealthKitManager {
    private let store = HKHealthStore()

    var workouts: [HKWorkout] = []
    var isLoading = false
    var errorMessage: String?

    private var workoutsByID: [UUID: HKWorkout] = [:]

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.runningPower),
        HKQuantityType(.stepCount),
        HKSeriesType.workoutRoute(),
    ]

    func workout(for id: UUID) -> HKWorkout? {
        workoutsByID[id]
    }

    func requestAuthorization() async {
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchWorkouts() async {
        isLoading = true
        defer { isLoading = false }

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let traditionalStrengthPredicate = HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining)
        let functionalStrengthPredicate = HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)

        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            runningPredicate,
            traditionalStrengthPredicate,
            functionalStrengthPredicate,
        ])

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(compoundPredicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 50
        )

        do {
            let results = try await descriptor.result(for: store)
            workouts = results
            workoutsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.uuid, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buildExport(for workout: HKWorkout) async throws -> WorkoutExport {
        async let heartRateSamples = fetchHeartRateSamples(for: workout)
        async let route = fetchRoute(for: workout)

        let statistics = Self.extractStatistics(from: workout)
        let events = Self.extractEvents(from: workout)
        let activities = Self.extractActivities(from: workout)

        let workoutData = WorkoutData(
            type: Self.workoutTypeName(workout.workoutActivityType),
            sourceApp: workout.sourceRevision.source.name,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            statistics: statistics,
            heartRateSamples: try await heartRateSamples,
            route: try await route,
            events: events,
            activities: activities
        )

        return WorkoutExport(
            exportVersion: "1.0",
            exportDate: .now,
            workout: workoutData
        )
    }

    private static func extractStatistics(from workout: HKWorkout) -> WorkoutStatistics {
        var stats = WorkoutStatistics()

        if let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            if let sum = energy.sumQuantity() {
                stats.activeEnergyBurned = StatValue(
                    value: sum.doubleValue(for: .kilocalorie()),
                    unit: "kcal"
                )
            }
        }

        if let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)) {
            if let sum = distance.sumQuantity() {
                stats.distance = StatValue(
                    value: sum.doubleValue(for: .meterUnit(with: .kilo)),
                    unit: "km"
                )
            }
        }

        if let steps = workout.statistics(for: HKQuantityType(.stepCount)) {
            if let sum = steps.sumQuantity() {
                stats.stepCount = StatValue(
                    value: sum.doubleValue(for: .count()),
                    unit: "steps"
                )
            }
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        if let hr = workout.statistics(for: HKQuantityType(.heartRate)) {
            if let avg = hr.averageQuantity() {
                stats.averageHeartRate = StatValue(
                    value: avg.doubleValue(for: bpmUnit),
                    unit: "bpm"
                )
            }
            if let max = hr.maximumQuantity() {
                stats.maxHeartRate = StatValue(
                    value: max.doubleValue(for: bpmUnit),
                    unit: "bpm"
                )
            }
        }

        if let speed = workout.statistics(for: HKQuantityType(.runningSpeed)) {
            if let avg = speed.averageQuantity() {
                stats.averageSpeed = StatValue(
                    value: avg.doubleValue(for: .meter().unitDivided(by: .second())),
                    unit: "m/s"
                )
            }
        }

        if let power = workout.statistics(for: HKQuantityType(.runningPower)) {
            if let avg = power.averageQuantity() {
                stats.averagePower = StatValue(
                    value: avg.doubleValue(for: .watt()),
                    unit: "W"
                )
            }
        }

        return stats
    }

    private nonisolated func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HeartRateSample] {
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: 5000
        )

        let samples = try await descriptor.result(for: store)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        return samples.map { sample in
            HeartRateSample(
                date: sample.startDate,
                bpm: sample.quantity.doubleValue(for: bpmUnit)
            )
        }
    }

    private nonisolated func fetchRoute(for workout: HKWorkout) async throws -> [RoutePoint] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeDescriptor = HKSampleQueryDescriptor(
            predicates: [.workoutRoute(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: 1
        )

        let routes = try await routeDescriptor.result(for: store)
        guard let route = routes.first else { return [] }

        var points: [RoutePoint] = []
        let routeQuery = HKWorkoutRouteQueryDescriptor(route)
        for try await location in routeQuery.results(for: store) {
            points.append(RoutePoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
                speed: location.speed >= 0 ? location.speed : nil
            ))
        }
        return points
    }

    private static func extractEvents(from workout: HKWorkout) -> [WorkoutEventData] {
        guard let events = workout.workoutEvents else { return [] }
        return events.map { event in
            WorkoutEventData(
                type: eventTypeName(event.type),
                startDate: event.dateInterval.start,
                endDate: event.dateInterval.end
            )
        }
    }

    private static func extractActivities(from workout: HKWorkout) -> [ActivityData] {
        workout.workoutActivities.map { activity in
            let stats = extractStatisticsFromActivity(activity)
            let endDate = activity.endDate ?? activity.startDate.addingTimeInterval(activity.duration)
            return ActivityData(
                type: workoutTypeName(activity.workoutConfiguration.activityType),
                startDate: activity.startDate,
                endDate: endDate,
                duration: activity.duration,
                statistics: stats
            )
        }
    }

    private static func extractStatisticsFromActivity(_ activity: HKWorkoutActivity) -> WorkoutStatistics {
        var stats = WorkoutStatistics()

        if let energy = activity.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            if let sum = energy.sumQuantity() {
                stats.activeEnergyBurned = StatValue(
                    value: sum.doubleValue(for: .kilocalorie()),
                    unit: "kcal"
                )
            }
        }

        if let distance = activity.statistics(for: HKQuantityType(.distanceWalkingRunning)) {
            if let sum = distance.sumQuantity() {
                stats.distance = StatValue(
                    value: sum.doubleValue(for: .meterUnit(with: .kilo)),
                    unit: "km"
                )
            }
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        if let hr = activity.statistics(for: HKQuantityType(.heartRate)) {
            if let avg = hr.averageQuantity() {
                stats.averageHeartRate = StatValue(
                    value: avg.doubleValue(for: bpmUnit),
                    unit: "bpm"
                )
            }
            if let max = hr.maximumQuantity() {
                stats.maxHeartRate = StatValue(
                    value: max.doubleValue(for: bpmUnit),
                    unit: "bpm"
                )
            }
        }

        return stats
    }

    static func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "running"
        case .traditionalStrengthTraining: "strength_training"
        case .functionalStrengthTraining: "functional_strength"
        default: "other"
        }
    }

    private static func eventTypeName(_ type: HKWorkoutEventType) -> String {
        switch type {
        case .pause: "pause"
        case .resume: "resume"
        case .lap: "lap"
        case .segment: "segment"
        case .marker: "marker"
        case .motionPaused: "motionPaused"
        case .motionResumed: "motionResumed"
        @unknown default: "unknown"
        }
    }
}
