import WatchConnectivity

protocol WatchConnectivityDelegate: AnyObject {
  func didReceiveHeartRate(bpm: Double, timestamp: TimeInterval)
  func didChangeReachability(isReachable: Bool)
  func didEncounterError(message: String, code: String)
}

class WatchConnectivityManager: NSObject {
  static let shared = WatchConnectivityManager()

  weak var delegate: WatchConnectivityDelegate?

  private var session: WCSession?
  private var isActivated = false
  private var pendingCommand: [String: Any]?

  private override init() {
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    session = WCSession.default
    session?.delegate = self
    session?.activate()
  }

  var isWatchReachable: Bool {
    return session?.isReachable ?? false
  }

  var isWatchPaired: Bool {
    return session?.isPaired ?? false
  }

  func sendStartCommand(config: [String: String]? = nil) {
    var message: [String: Any] = ["command": "startWorkout"]
    if let activityType = config?["activityType"] {
      message["activityType"] = activityType
    }
    if let workoutName = config?["workoutName"] {
      message["workoutName"] = workoutName
    }
    if let sessionId = config?["sessionId"] {
      message["sessionId"] = sessionId
    }
    sendCommand(message)
  }

  func sendStopCommand() {
    sendCommand(["command": "stopWorkout"])
  }

  private func sendCommand(_ message: [String: Any]) {
    var stamped = message
    // commandId lets the watch dedupe the sendMessage/applicationContext double
    // delivery; commandTimestamp lets it discard stale context replays. The
    // changing values also defeat WCSession's suppression of an application
    // context identical to the previous one.
    stamped["commandId"] = UUID().uuidString
    stamped["commandTimestamp"] = Date().timeIntervalSince1970

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let session = self.session, self.isActivated else {
        self.pendingCommand = stamped
        return
      }
      self.deliver(stamped, via: session)
    }
  }

  private func deliver(_ message: [String: Any], via session: WCSession) {
    // Persist command in application context so the watch receives it on wake
    do {
      try session.updateApplicationContext(message)
    } catch {
      delegate?.didEncounterError(
        message: error.localizedDescription,
        code: "CONTEXT_UPDATE_FAILED"
      )
    }

    // Also send live if reachable for immediate delivery
    if session.isReachable {
      session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isActivated = activationState == .activated
      if self.isActivated {
        if let pending = self.pendingCommand {
          self.pendingCommand = nil
          self.deliver(pending, via: session)
        }
        self.delegate?.didChangeReachability(isReachable: session.isReachable)
      }
      if let error {
        self.delegate?.didEncounterError(
          message: error.localizedDescription,
          code: "ACTIVATION_FAILED"
        )
      }
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    // No-op, required by protocol
  }

  func sessionDidDeactivate(_ session: WCSession) {
    // Reactivate for watch switching
    session.activate()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    delegate?.didChangeReachability(isReachable: session.isReachable)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    handleIncomingMessage(message)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    handleIncomingMessage(message)
    replyHandler(["status": "received"])
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    // Fallback for when watch sends data in background
    handleIncomingMessage(userInfo)
  }

  private func handleIncomingMessage(_ message: [String: Any]) {
    if let errorMessage = message["workoutError"] as? String {
      delegate?.didEncounterError(message: errorMessage, code: "WATCH_WORKOUT_ERROR")
      return
    }

    guard let bpm = message["bpm"] as? Double else { return }
    let timestamp = (message["timestamp"] as? TimeInterval) ?? Date().timeIntervalSince1970 * 1000
    delegate?.didReceiveHeartRate(bpm: bpm, timestamp: timestamp)
  }
}
