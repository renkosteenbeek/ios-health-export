import SwiftUI
import HealthKit

struct WorkoutRowView: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.startDate, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 16) {
                    Label(formattedDuration, systemImage: "clock")
                    Label(keyStat, systemImage: keyStatIcon)
                    if let avgHR = averageHeartRate {
                        Label(avgHR, systemImage: "heart.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch workout.workoutActivityType {
        case .running: "figure.run"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "figure.strengthtraining.traditional"
        default: "figure.mixed.cardio"
        }
    }

    private var iconColor: Color {
        switch workout.workoutActivityType {
        case .running: .green
        case .traditionalStrengthTraining, .functionalStrengthTraining: .orange
        default: .blue
        }
    }

    private var formattedDuration: String {
        let minutes = Int(workout.duration / 60)
        return "\(minutes) min"
    }

    private var keyStat: String {
        if workout.workoutActivityType == .running {
            if let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity() {
                let km = distance.doubleValue(for: .meterUnit(with: .kilo))
                return String(format: "%.2f km", km)
            }
        }
        if let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
            let kcal = energy.doubleValue(for: .kilocalorie())
            return String(format: "%.0f kcal", kcal)
        }
        return "--"
    }

    private var keyStatIcon: String {
        workout.workoutActivityType == .running ? "point.bottomleft.forward.to.point.topright.scurvepath" : "flame"
    }

    private var averageHeartRate: String? {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        guard let avg = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity() else { return nil }
        return String(format: "%.0f bpm", avg.doubleValue(for: bpmUnit))
    }
}
