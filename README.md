# Health Export

iOS app that exports Apple Health workouts to JSON. Supports running, strength training, and functional strength workouts.

## Features

- Browse recent workouts with key stats (distance, calories, heart rate)
- Filter by workout type (running / strength)
- Search workouts by type or date
- View detailed statistics, heart rate data, GPS route, events, and activities
- Export workout data as structured JSON via share sheet

## Export Format

Each export contains:
- Workout metadata (type, source app, duration)
- Statistics (energy, distance, steps, heart rate, speed, power)
- Heart rate samples (up to 5000 per workout)
- GPS route points with altitude and accuracy
- Workout events (pause, resume, lap, etc.)
- Activity segments with per-segment statistics

## Requirements

- iOS 26.0+
- Xcode 26
- Swift 6

## Build

```bash
xcodegen generate
xcodebuild build -scheme HealthExport -destination 'generic/platform=iOS'
```

## Architecture

- **Swift 6 strict concurrency** — `@Observable @MainActor` manager, `nonisolated` HealthKit queries, pure functions as `static`
- **UUID-based navigation** — `NavigationLink(value: UUID)` with O(1) dictionary lookup
- **iOS 26 searchable** — bottom-aligned search bar on iPhone
