import ExpoModulesCore

public class HeartRateModule: Module {
  private let watchManager = WatchConnectivityManager.shared
  private let zoneCalculator = HeartRateZoneCalculator.shared
  private var isMonitoring = false

  public func definition() -> ModuleDefinition {
    Name("HeartRate")

    Events("heartRateUpdate", "connectionChange", "error")

    OnCreate {
      self.watchManager.delegate = self
      self.watchManager.activate()
      self.zoneCalculator.initialize { _ in }
    }

    Function("startMonitoring") {
      self.isMonitoring = true
      self.watchManager.sendStartCommand()
    }

    Function("stopMonitoring") {
      self.isMonitoring = false
      self.watchManager.sendStopCommand()
    }

    AsyncFunction("isWatchConnected") { () -> Bool in
      return self.watchManager.isWatchReachable
    }

    AsyncFunction("getHeartRateZones") { () -> [[String: Any]] in
      return self.zoneCalculator.getZones()
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
