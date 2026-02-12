import SwiftUI

@main
struct HealthExportApp: App {
    @State private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            WorkoutListView()
                .environment(healthKitManager)
        }
    }
}
