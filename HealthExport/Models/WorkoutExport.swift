import Foundation

struct WorkoutExport: Codable, Sendable {
    let exportVersion: String
    let exportDate: Date
    let workout: WorkoutData
}

struct WorkoutData: Codable, Sendable {
    let type: String
    let sourceApp: String
    let startDate: Date
    let endDate: Date
    let duration: Double
    let statistics: WorkoutStatistics
    let heartRateSamples: [HeartRateSample]
    let route: [RoutePoint]
    let events: [WorkoutEventData]
    let activities: [ActivityData]
}

struct WorkoutStatistics: Codable, Sendable {
    var activeEnergyBurned: StatValue?
    var distance: StatValue?
    var stepCount: StatValue?
    var averageHeartRate: StatValue?
    var maxHeartRate: StatValue?
    var averageSpeed: StatValue?
    var averagePower: StatValue?
}

struct StatValue: Codable, Sendable {
    let value: Double
    let unit: String
}

struct HeartRateSample: Codable, Sendable {
    let date: Date
    let bpm: Double
}

struct RoutePoint: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double?
    let speed: Double?
}

struct WorkoutEventData: Codable, Sendable {
    let type: String
    let startDate: Date
    let endDate: Date?
}

struct ActivityData: Codable, Sendable {
    let type: String
    let startDate: Date
    let endDate: Date
    let duration: Double
    let statistics: WorkoutStatistics
}
