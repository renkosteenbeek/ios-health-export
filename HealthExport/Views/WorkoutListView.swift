import SwiftUI
import HealthKit

struct WorkoutListView: View {
    @Environment(HealthKitManager.self) private var manager

    @State private var searchText = ""
    @State private var filter: WorkoutFilter = .all

    enum WorkoutFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case strength = "Strength"
    }

    private var filteredWorkouts: [HKWorkout] {
        var results = manager.workouts

        switch filter {
        case .all:
            break
        case .running:
            results = results.filter { $0.workoutActivityType == .running }
        case .strength:
            results = results.filter {
                $0.workoutActivityType == .traditionalStrengthTraining ||
                $0.workoutActivityType == .functionalStrengthTraining
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { workout in
                let typeName = HealthKitManager.workoutTypeName(workout.workoutActivityType)
                let dateString = workout.startDate.formatted(
                    .dateTime.weekday(.wide).month(.abbreviated).day()
                )
                return typeName.contains(query) || dateString.lowercased().contains(query)
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            Group {
                if manager.isLoading {
                    ProgressView("Loading workouts...")
                } else if let error = manager.errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if filteredWorkouts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredWorkouts, id: \.uuid) { workout in
                        NavigationLink(value: workout.uuid) {
                            WorkoutRowView(workout: workout)
                        }
                    }
                }
            }
            .navigationTitle("Health Export")
            .navigationDestination(for: UUID.self) { workoutID in
                if let workout = manager.workout(for: workoutID) {
                    WorkoutDetailView(workout: workout)
                }
            }
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await manager.requestAuthorization()
                await manager.fetchWorkouts()
            }
        }
    }
}
