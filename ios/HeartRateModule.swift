import ExpoModulesCore
import HealthKit

public class HeartRateModule: Module {
  private let watchManager = WatchConnectivityManager.shared
  private let healthStore = HKHealthStore()
  private let zoneCalculator = HeartRateZoneCalculator.shared
  private var isMonitoring = false

  private var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  public func definition() -> ModuleDefinition {
    Name("HeartRate")

    Events("heartRateUpdate", "activeEnergyUpdate", "connectionChange", "error")

    OnCreate {
      self.watchManager.delegate = self
      self.watchManager.activate()
    }

    Function("startMonitoring") { (config: [String: String]?) in
      self.zoneCalculator.initialize { _ in }
      self.isMonitoring = true
      // Persist the command (with sessionId/commandId) first so it is waiting
      // in applicationContext when the watch app wakes, then ask watchOS to
      // launch the app in the background. WatchConnectivity remains the
      // fallback when the remote launch is unavailable.
      self.watchManager.sendStartCommand(config: config)
      self.launchWatchApp(config: config)
    }

    Function("stopMonitoring") {
      self.isMonitoring = false
      self.watchManager.sendStopCommand()
    }

    Function("pauseMonitoring") {
      guard self.isMonitoring else { return }
      self.watchManager.sendPauseCommand()
    }

    Function("resumeMonitoring") {
      guard self.isMonitoring else { return }
      self.watchManager.sendResumeCommand()
    }

    AsyncFunction("isWatchConnected") { () -> Bool in
      if self.isSimulator { return true }
      return self.watchManager.isWatchReachable
    }

    AsyncFunction("getHeartRateZones") { () -> [[String: Any]] in
      return self.zoneCalculator.getZones()
    }
  }
}

// MARK: - Remote watch app launch

extension HeartRateModule {
  private func launchWatchApp(config: [String: String]?) {
    guard !isSimulator, HKHealthStore.isHealthDataAvailable() else { return }
    guard watchManager.isWatchPaired else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = mapActivityType(config?["activityType"])
    configuration.locationType = .indoor

    healthStore.startWatchApp(with: configuration) { [weak self] success, error in
      guard let self, !success else { return }
      let message = error?.localizedDescription ?? "Could not launch the watch app"
      self.sendEvent("error", [
        "message": message,
        "code": "WATCH_LAUNCH_FAILED",
      ])
    }
  }

  private func mapActivityType(_ type: String?) -> HKWorkoutActivityType {
    switch type {
    case "traditionalStrengthTraining": return .traditionalStrengthTraining
    case "functionalStrengthTraining": return .functionalStrengthTraining
    case "running": return .running
    case "cycling": return .cycling
    case "walking": return .walking
    case "hiking": return .hiking
    case "yoga": return .yoga
    case "rowing": return .rowing
    case "swimming": return .swimming
    case "crossTraining": return .crossTraining
    case "elliptical": return .elliptical
    case "stairClimbing": return .stairClimbing
    case "pilates": return .pilates
    case "dance": return .dance
    case "cooldown": return .cooldown
    case "coreTraining": return .coreTraining
    case "flexibility": return .flexibility
    case "highIntensityIntervalTraining": return .highIntensityIntervalTraining
    case "jumpRope": return .jumpRope
    case "kickboxing": return .kickboxing
    case "mixedCardio": return .mixedCardio
    default: return .other
    }
  }
}

// MARK: - WatchConnectivityDelegate

extension HeartRateModule: WatchConnectivityDelegate {
  func didReceiveHeartRate(bpm: Double, timestamp: TimeInterval) {
    guard isMonitoring else { return }

    let zoneStatus = zoneCalculator.getZoneStatus(bpm: Int(bpm))

    sendEvent("heartRateUpdate", [
      "bpm": bpm,
      "timestamp": timestamp,
      "source": "watchOS",
      "zone": zoneStatus,
    ])
  }

  func didReceiveActiveEnergy(kcal: Double, timestamp: TimeInterval) {
    guard isMonitoring else { return }

    sendEvent("activeEnergyUpdate", [
      "kcal": kcal,
      "timestamp": timestamp,
      "source": "watchOS",
    ])
  }

  func didChangeReachability(isReachable: Bool) {
    sendEvent("connectionChange", [
      "isConnected": isReachable,
    ])
  }

  func didEncounterError(message: String, code: String) {
    sendEvent("error", [
      "message": message,
      "code": code,
    ])
  }
}
