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
    }
  }

  private func requestAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let typesToShare: Set<HKSampleType> = [
      HKObjectType.workoutType(),
    ]

    let typesToRead: Set<HKObjectType> = [
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
    ]

    healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
      guard let self else { return }
      if success {
        self.loadMaxHeartRate()
      }
      if let error {
        print("HealthKit authorization error: \(error)")
      }
    }
  }

  func startWorkout() {
    if isSimulator {
      startSimulation()
      return
    }

    guard HKHealthStore.isHealthDataAvailable() else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .other
    configuration.locationType = .unknown

    do {
      session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      builder = session?.associatedWorkoutBuilder()

      session?.delegate = self
      builder?.delegate = self

      builder?.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: configuration
      )

      let startDate = Date()
      session?.startActivity(with: startDate)
      builder?.beginCollection(withStart: startDate) { [weak self] _, error in
        if let error {
          print("Failed to begin collection: \(error)")
          return
        }
        DispatchQueue.main.async {
          self?.isWorkoutActive = true
        }
      }
    } catch {
      print("Failed to start workout: \(error)")
    }
  }

  func stopWorkout() {
    if isSimulator {
      stopSimulation()
      return
    }

    session?.end()
    DispatchQueue.main.async {
      self.isWorkoutActive = false
      self.currentHeartRate = 0
    }
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
    if toState == .ended {
      builder?.endCollection(withEnd: date) { [weak self] _, _ in
        self?.builder?.finishWorkout { _, _ in }
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    print("Workout session error: \(error)")
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
  func didReceiveCommand(_ command: String) {
    DispatchQueue.main.async {
      switch command {
      case "startWorkout":
        if !self.isWorkoutActive {
          self.startWorkout()
        }
      case "stopWorkout":
        if self.isWorkoutActive {
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
    }
  }
}
#endif
