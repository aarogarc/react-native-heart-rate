import WatchConnectivity

protocol WatchConnectivityProviderDelegate: AnyObject {
  func didReceiveCommand(_ command: String)
  func didChangePhoneReachability(_ isReachable: Bool)
}

class WatchConnectivityProvider: NSObject {
  static let shared = WatchConnectivityProvider()

  weak var delegate: WatchConnectivityProviderDelegate?

  private var session: WCSession?

  private override init() {
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    session = WCSession.default
    session?.delegate = self
    session?.activate()
  }

  func sendHeartRate(bpm: Double, timestamp: TimeInterval) {
    guard let session, session.isReachable else {
      // Fall back to transferUserInfo for background delivery
      WCSession.default.transferUserInfo([
        "bpm": bpm,
        "timestamp": timestamp,
      ])
      return
    }

    session.sendMessage([
      "bpm": bpm,
      "timestamp": timestamp,
    ], replyHandler: nil, errorHandler: nil)
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityProvider: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    // Activated
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    delegate?.didChangePhoneReachability(session.isReachable)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    if let command = message["command"] as? String {
      delegate?.didReceiveCommand(command)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    if let command = message["command"] as? String {
      delegate?.didReceiveCommand(command)
    }
    replyHandler(["status": "received"])
  }
}
