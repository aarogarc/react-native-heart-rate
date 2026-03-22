import ExpoModulesCore

public class HeartRateModule: Module {
  public func definition() -> ModuleDefinition {
    Name("HeartRate")

    Events("heartRateUpdate", "connectionChange", "error")

    Function("startMonitoring") {
      // TODO: Send start command to watch via WatchConnectivity
    }

    Function("stopMonitoring") {
      // TODO: Send stop command to watch via WatchConnectivity
    }

    AsyncFunction("isWatchConnected") { () -> Bool in
      // TODO: Check WCSession.default.isReachable
      return false
    }

    AsyncFunction("getHeartRateZones") { () -> [[String: Any]] in
      // TODO: Read zones from HealthKit or calculate from user profile
      return Self.defaultZones()
    }
  }

  private static func defaultZones() -> [[String: Any]] {
    // Default 5-zone model based on percentage of max heart rate
    // Max HR will be calculated from HealthKit date of birth (220 - age)
    return [
      ["name": "Zone 1 — Warm Up", "min": 0, "max": 60, "color": "#94A3B8"],
      ["name": "Zone 2 — Fat Burn", "min": 60, "max": 70, "color": "#22C55E"],
      ["name": "Zone 3 — Cardio", "min": 70, "max": 80, "color": "#EAB308"],
      ["name": "Zone 4 — Hard", "min": 80, "max": 90, "color": "#F97316"],
      ["name": "Zone 5 — Maximum", "min": 90, "max": 100, "color": "#EF4444"],
    ]
  }
}
