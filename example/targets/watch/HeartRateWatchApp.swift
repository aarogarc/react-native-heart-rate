import SwiftUI

@main
struct HeartRateWatchApp: App {
  @StateObject private var workoutManager = WorkoutManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(workoutManager)
    }
  }
}

struct ContentView: View {
  @EnvironmentObject var workoutManager: WorkoutManager

  var body: some View {
    VStack(spacing: 12) {
      if workoutManager.isWorkoutActive {
        HeartRateZoneView(
          bpm: workoutManager.currentHeartRate,
          zone: workoutManager.currentZone,
          zones: workoutManager.zones
        )

        Button("Stop") {
          workoutManager.stopWorkout()
        }
        .tint(.red)
      } else {
        VStack(spacing: 8) {
          Image(systemName: "heart.fill")
            .font(.system(size: 40))
            .foregroundStyle(.red)

          Text("Heart Rate")
            .font(.headline)

          Text(workoutManager.isConnectedToPhone ? "Phone connected" : "Phone not connected")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        Button("Start") {
          workoutManager.startWorkout()
        }
        .tint(.green)
      }
    }
    .padding()
  }
}
