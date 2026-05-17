import ExpoModulesCore

public class HeartRateModule: Module {
  private let watchManager = WatchConnectivityManager.shared
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

    Events("heartRateUpdate", "connectionChange", "error")

    OnCreate {
      self.watchManager.delegate = self
      self.watchManager.activate()
    }

    Function("startMonitoring") { (config: [String: String]?) in
      self.zoneCalculator.initialize { _ in }
      self.isMonitoring = true
      self.watchManager.sendStartCommand(config: config)
    }

    Function("stopMonitoring") {
      self.isMonitoring = false
      self.watchManager.sendStopCommand()
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
