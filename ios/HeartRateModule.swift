import ExpoModulesCore

public class HeartRateModule: Module {
  private let watchManager = WatchConnectivityManager.shared
  private let zoneCalculator = HeartRateZoneCalculator.shared
  private var isMonitoring = false
  private var simulationTimer: Timer?

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
      self.zoneCalculator.initialize { _ in }
    }

    Function("startMonitoring") {
      self.isMonitoring = true
      if self.isSimulator {
        self.startSimulation()
      } else {
        self.watchManager.sendStartCommand()
      }
    }

    Function("stopMonitoring") {
      self.isMonitoring = false
      if self.isSimulator {
        self.stopSimulation()
      } else {
        self.watchManager.sendStopCommand()
      }
    }

    AsyncFunction("isWatchConnected") { () -> Bool in
      if self.isSimulator { return true }
      return self.watchManager.isWatchReachable
    }

    AsyncFunction("getHeartRateZones") { () -> [[String: Any]] in
      return self.zoneCalculator.getZones()
    }
  }

  // MARK: - Simulation

  private func startSimulation() {
    var simulatedBPM: Double = 72

    DispatchQueue.main.async {
      self.simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self, self.isMonitoring else { return }
        let delta = Double.random(in: -3...5)
        simulatedBPM = min(max(simulatedBPM + delta, 55), 185)
        self.didReceiveHeartRate(bpm: simulatedBPM, timestamp: Date().timeIntervalSince1970 * 1000)
      }
    }
  }

  private func stopSimulation() {
    simulationTimer?.invalidate()
    simulationTimer = nil
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
