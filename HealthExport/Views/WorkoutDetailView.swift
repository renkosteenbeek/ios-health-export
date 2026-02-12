import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    @Environment(HealthKitManager.self) private var manager

    let workout: HKWorkout

    @State private var exportURL: URL?
    @State private var workoutExport: WorkoutExport?
    @State private var isBuilding = true
    @State private var buildError: String?
    @State private var showShareSheet = false

    var body: some View {
        List {
            overviewSection
            statisticsSection
            heartRateSection
            routeSection
            eventsSection
            activitiesSection
        }
        .navigationTitle(HealthKitManager.workoutTypeName(workout.workoutActivityType).capitalized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isBuilding {
                    ProgressView()
                } else if exportURL != nil {
                    Button("", systemImage: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .task {
            await loadExport()
        }
    }

    private func loadExport() async {
        isBuilding = true
        do {
            let export = try await manager.buildExport(for: workout)
            workoutExport = export
            let doc = try ExportDocument(export: export)
            exportURL = doc.url
        } catch {
            buildError = error.localizedDescription
        }
        isBuilding = false
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Type", value: HealthKitManager.workoutTypeName(workout.workoutActivityType).capitalized)
            LabeledContent("Source", value: workout.sourceRevision.source.name)
            LabeledContent("Start", value: workout.startDate, format: .dateTime)
            LabeledContent("End", value: workout.endDate, format: .dateTime)
            LabeledContent("Duration", value: formattedDuration)
        }
    }

    @ViewBuilder
    private var statisticsSection: some View {
        if let stats = workoutExport?.workout.statistics {
            Section("Statistics") {
                if let e = stats.activeEnergyBurned {
                    LabeledContent("Active Energy", value: "\(String(format: "%.1f", e.value)) \(e.unit)")
                }
                if let d = stats.distance {
                    LabeledContent("Distance", value: "\(String(format: "%.2f", d.value)) \(d.unit)")
                }
                if let s = stats.stepCount {
                    LabeledContent("Steps", value: "\(String(format: "%.0f", s.value))")
                }
                if let hr = stats.averageHeartRate {
                    LabeledContent("Avg Heart Rate", value: "\(String(format: "%.0f", hr.value)) \(hr.unit)")
                }
                if let hr = stats.maxHeartRate {
                    LabeledContent("Max Heart Rate", value: "\(String(format: "%.0f", hr.value)) \(hr.unit)")
                }
                if let sp = stats.averageSpeed {
                    LabeledContent("Avg Speed", value: "\(String(format: "%.2f", sp.value)) \(sp.unit)")
                }
                if let pw = stats.averagePower {
                    LabeledContent("Avg Power", value: "\(String(format: "%.0f", pw.value)) \(pw.unit)")
                }
            }
        }
    }

    @ViewBuilder
    private var heartRateSection: some View {
        if let samples = workoutExport?.workout.heartRateSamples, !samples.isEmpty {
            Section("Heart Rate") {
                LabeledContent("Samples", value: "\(samples.count)")
                if let min = samples.min(by: { $0.bpm < $1.bpm }),
                   let max = samples.max(by: { $0.bpm < $1.bpm }) {
                    LabeledContent("Range", value: "\(String(format: "%.0f", min.bpm)) - \(String(format: "%.0f", max.bpm)) bpm")
                }
            }
        }
    }

    @ViewBuilder
    private var routeSection: some View {
        if let route = workoutExport?.workout.route, !route.isEmpty {
            Section("Route") {
                LabeledContent("Points", value: "\(route.count)")
                if let first = route.first, let last = route.last {
                    LabeledContent("Start", value: String(format: "%.4f, %.4f", first.latitude, first.longitude))
                    LabeledContent("End", value: String(format: "%.4f, %.4f", last.latitude, last.longitude))
                }
            }
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        if let events = workoutExport?.workout.events, !events.isEmpty {
            Section("Events") {
                ForEach(events, id: \.startDate) { event in
                    LabeledContent(event.type.capitalized, value: event.startDate, format: .dateTime.hour().minute().second())
                }
            }
        }
    }

    @ViewBuilder
    private var activitiesSection: some View {
        if let activities = workoutExport?.workout.activities, !activities.isEmpty {
            Section("Activities") {
                ForEach(activities, id: \.startDate) { activity in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.type.capitalized)
                            .font(.subheadline.weight(.medium))
                        Text("\(String(format: "%.0f", activity.duration / 60)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var formattedDuration: String {
        let total = Int(workout.duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
