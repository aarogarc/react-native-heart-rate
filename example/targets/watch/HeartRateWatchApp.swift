#if os(watchOS)
import SwiftUI

@main
struct HeartRateWatchApp: App {
  @StateObject private var workoutManager = WorkoutManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(workoutManager)
        .onAppear {
          if !workoutManager.isWorkoutActive {
            workoutManager.startWorkout()
          }
        }
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
      } else {
        ProgressView()
          .tint(.red)
        Text("Starting...")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
  }
}
#endif
