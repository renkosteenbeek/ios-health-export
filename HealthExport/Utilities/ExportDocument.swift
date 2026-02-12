import Foundation

struct ExportDocument {
    let url: URL
    let filename: String

    init(export: WorkoutExport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: export.workout.startDate)
        let name = "workout-\(export.workout.type)-\(dateString).json"
        self.filename = name

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        self.url = url
    }
}
