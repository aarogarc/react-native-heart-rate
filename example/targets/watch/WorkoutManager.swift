#if os(watchOS)
import Foundation
import HealthKit
import WatchConnectivity

class WorkoutManager: NSObject, ObservableObject {
  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var simulationTimer: Timer?

  @Published var currentHeartRate: Double = 0
  @Published var isWorkoutActive = false
  @Published var isConnectedToPhone = false
  @Published var currentZone: HeartRateZone = HeartRateZone.defaultZones[0]
  let zones = HeartRateZone.defaultZones

  private var maxHeartRate: Int = 190
  private let connectivityProvider = WatchConnectivityProvider.shared
  private var disconnectTimer: Timer?
  private static let disconnectTimeout: TimeInterval = 1800 // 30 minutes
  private static let startCommandMaxAge: TimeInterval = 600 // 10 minutes

  // isWorkoutActive only flips true after beginCollection succeeds, so this
  // synchronous flag is what actually prevents overlapping session creation
  // when the same start command arrives via sendMessage AND applicationContext.
  private var isStartingWorkout = false
  private var activeWorkoutSessionId: String?
  private var pendingStartConfig: [String: Any]?
  private var authorizationRequested = false
  private var authorizationCompleted = false
  private var handledCommandIds: [String] = []

  private var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  override init() {
    super.init()
    connectivityProvider.delegate = self
    connectivityProvider.activate()

    if !isSimulator {
      requestAuthorization()
      recoverActiveSession()
    }
  }

  private func requestAuthorization() {
    guard !authorizationRequested else { return }
    authorizationRequested = true
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let typesToShare: Set<HKSampleType> = [
      HKObjectType.workoutType(),
    ]

    let typesToRead: Set<HKObjectType> = [
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
    ]

    healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
      DispatchQueue.main.async {
        guard let self else { return }
        self.authorizationCompleted = true
        if success {
          self.loadMaxHeartRate()
        }
        if let error {
          print("HealthKit authorization error: \(error)")
        }
        if let pending = self.pendingStartConfig {
          self.pendingStartConfig = nil
          self.startWorkout(config: pending)
        }
      }
    }
  }

  // A crash mid-workout leaves an active HKWorkoutSession that blocks every
  // future session until it is reattached and ended. Reattach on launch.
  private func recoverActiveSession() {
    healthStore.recoverActiveWorkoutSession { [weak self] recovered, _ in
      DispatchQueue.main.async {
        guard let self, let recovered else { return }
        guard self.session == nil, !self.isStartingWorkout else { return }

        self.session = recovered
        self.builder = recovered.associatedWorkoutBuilder()
        recovered.delegate = self
        self.builder?.delegate = self

        switch recovered.state {
        case .running, .paused, .prepared:
          self.isWorkoutActive = true
        default:
          self.finishAndReset(endDate: Date())
        }
      }
    }
  }

  func startWorkout(config: [String: Any]? = nil) {
    guard !isWorkoutActive, !isStartingWorkout else { return }

    activeWorkoutSessionId = config?["sessionId"] as? String

    if isSimulator {
      startSimulation()
      return
    }

    guard HKHealthStore.isHealthDataAvailable() else { return }

    if !authorizationCompleted {
      pendingStartConfig = config ?? [:]
      requestAuthorization()
      return
    }

    isStartingWorkout = true

    let activityType = mapActivityType(config?["activityType"] as? String)

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = activityType
    configuration.locationType = .unknown

    do {
      let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      let newBuilder = newSession.associatedWorkoutBuilder()
      session = newSession
      builder = newBuilder

      newSession.delegate = self
      newBuilder.delegate = self

      newBuilder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: configuration
      )

      var metadata: [String: Any] = [:]
      if let workoutName = config?["workoutName"] as? String {
        metadata[HKMetadataKeyWorkoutBrandName] = workoutName
      }

      let startDate = Date()
      newSession.startActivity(with: startDate)
      newBuilder.beginCollection(withStart: startDate) { [weak self] success, error in
        DispatchQueue.main.async {
          guard let self, self.session === newSession else { return }
          self.isStartingWorkout = false

          if let error {
            self.abortFailedStart(reason: error.localizedDescription)
            return
          }
          if !success {
            self.abortFailedStart(reason: "Could not begin workout data collection")
            return
          }

          if !metadata.isEmpty {
            newBuilder.addMetadata(metadata) { _, _ in }
          }
          self.isWorkoutActive = true
        }
      }
    } catch {
      isStartingWorkout = false
      session = nil
      builder = nil
      activeWorkoutSessionId = nil
      reportWorkoutError("Failed to create workout session: \(error.localizedDescription)")
    }
  }

  private func abortFailedStart(reason: String) {
    reportWorkoutError("Workout failed to start: \(reason)")
    endActiveSession()
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

  func stopWorkout() {
    pendingStartConfig = nil

    if isSimulator {
      stopSimulation()
      return
    }

    endActiveSession()
  }

  private func endActiveSession() {
    disconnectTimer?.invalidate()
    disconnectTimer = nil

    if let session, session.state == .running || session.state == .paused || session.state == .prepared {
      session.end() // .ended state change triggers finishAndReset
    } else {
      finishAndReset(endDate: Date())
    }
  }

  private func finishAndReset(endDate: Date) {
    disconnectTimer?.invalidate()
    disconnectTimer = nil
    simulationTimer?.invalidate()
    simulationTimer = nil

    let finishingBuilder = builder
    session = nil
    builder = nil
    isStartingWorkout = false
    isWorkoutActive = false
    activeWorkoutSessionId = nil
    currentHeartRate = 0

    finishingBuilder?.endCollection(withEnd: endDate) { _, _ in
      finishingBuilder?.finishWorkout { _, _ in }
    }

    if let pending = pendingStartConfig {
      pendingStartConfig = nil
      startWorkout(config: pending)
    }
  }

  private func reportWorkoutError(_ message: String) {
    print(message)
    connectivityProvider.sendWorkoutError(message)
  }

  // MARK: - Simulator

  private func startSimulation() {
    isWorkoutActive = true
    // Start at resting HR and gradually increase
    var simulatedBPM: Double = 72

    simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      // Simulate natural HR variation: drift up/down with some randomness
      let delta = Double.random(in: -3...5)
      simulatedBPM = min(max(simulatedBPM + delta, 55), 185)
      self.updateHeartRate(simulatedBPM)
    }
  }

  private func stopSimulation() {
    simulationTimer?.invalidate()
    simulationTimer = nil
    isWorkoutActive = false
    activeWorkoutSessionId = nil
    currentHeartRate = 0
  }

  // MARK: - Heart Rate

  private func loadMaxHeartRate() {
    do {
      let dobComponents = try healthStore.dateOfBirthComponents()
      if let year = dobComponents.year {
        let age = Calendar.current.component(.year, from: Date()) - year
        maxHeartRate = max(220 - age, 100)
      }
    } catch {
      // Use default
    }
  }

  private func updateHeartRate(_ bpm: Double) {
    DispatchQueue.main.async {
      self.currentHeartRate = bpm
      self.currentZone = self.zoneForBPM(Int(bpm))
    }

    connectivityProvider.sendHeartRate(
      bpm: bpm,
      timestamp: Date().timeIntervalSince1970 * 1000
    )
  }

  private func zoneForBPM(_ bpm: Int) -> HeartRateZone {
    return zones.last { bpm >= $0.minBPM(maxHR: maxHeartRate) } ?? zones[0]
  }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
  func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    DispatchQueue.main.async {
      guard workoutSession === self.session else { return }
      if toState == .ended {
        self.finishAndReset(endDate: date)
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    DispatchQueue.main.async {
      guard workoutSession === self.session else { return }
      self.reportWorkoutError("Workout session error: \(error.localizedDescription)")
      self.finishAndReset(endDate: Date())
    }
  }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    // Not used for heart rate
  }

  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    for type in collectedTypes {
      guard let quantityType = type as? HKQuantityType,
            quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }

      if let statistics = workoutBuilder.statistics(for: quantityType),
         let quantity = statistics.mostRecentQuantity() {
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        updateHeartRate(bpm)
      }
    }
  }
}

// MARK: - WatchConnectivityProviderDelegate

extension WorkoutManager: WatchConnectivityProviderDelegate {
  func didReceiveCommand(_ command: String, config: [String: Any]?) {
    DispatchQueue.main.async {
      // The phone delivers each command via both sendMessage and
      // applicationContext (and replays the context on activation) — process
      // each logical command once.
      if let commandId = config?["commandId"] as? String {
        if self.handledCommandIds.contains(commandId) { return }
        self.handledCommandIds.append(commandId)
        if self.handledCommandIds.count > 20 {
          self.handledCommandIds.removeFirst(self.handledCommandIds.count - 20)
        }
      }

      switch command {
      case "startWorkout":
        if let ts = config?["commandTimestamp"] as? TimeInterval,
           Date().timeIntervalSince1970 - ts > WorkoutManager.startCommandMaxAge {
          // Stale applicationContext replay (e.g. phone app died mid-workout
          // last week). A live session re-sends a fresh start on reachability.
          return
        }

        if self.isWorkoutActive || self.isStartingWorkout {
          let incomingSessionId = config?["sessionId"] as? String
          if incomingSessionId == nil || incomingSessionId == self.activeWorkoutSessionId {
            return
          }
          // A different app session started while an old workout is still
          // recording — roll over to the new one.
          self.pendingStartConfig = config
          self.endActiveSession()
        } else {
          self.startWorkout(config: config)
        }
      case "stopWorkout":
        if self.isWorkoutActive || self.isStartingWorkout || self.session != nil {
          self.stopWorkout()
        }
      default:
        break
      }
    }
  }

  func didChangePhoneReachability(_ isReachable: Bool) {
    DispatchQueue.main.async {
      self.isConnectedToPhone = isReachable

      if self.isWorkoutActive {
        if isReachable {
          self.disconnectTimer?.invalidate()
          self.disconnectTimer = nil
        } else if self.disconnectTimer == nil {
          self.disconnectTimer = Timer.scheduledTimer(withTimeInterval: WorkoutManager.disconnectTimeout, repeats: false) { [weak self] _ in
            guard let self, self.isWorkoutActive else { return }
            self.stopWorkout()
          }
        }
      }
    }
  }
}
#endif
