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

  func sendStartCommand() {
    sendCommand("startWorkout")
  }

  func sendStopCommand() {
    sendCommand("stopWorkout")
  }

  private func sendCommand(_ command: String) {
    guard let session, session.isReachable else {
      delegate?.didEncounterError(
        message: "Watch is not reachable",
        code: "WATCH_NOT_REACHABLE"
      )
      return
    }

    session.sendMessage(["command": command], replyHandler: nil) { [weak self] error in
      self?.delegate?.didEncounterError(
        message: error.localizedDescription,
        code: "SEND_FAILED"
      )
    }
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    isActivated = activationState == .activated
    if let error {
      delegate?.didEncounterError(
        message: error.localizedDescription,
        code: "ACTIVATION_FAILED"
      )
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
    guard let bpm = message["bpm"] as? Double else { return }
    let timestamp = (message["timestamp"] as? TimeInterval) ?? Date().timeIntervalSince1970 * 1000
    delegate?.didReceiveHeartRate(bpm: bpm, timestamp: timestamp)
  }
}
