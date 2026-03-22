import Foundation
import HealthKit
import WatchConnectivity

class WorkoutManager: NSObject, ObservableObject {
  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?

  @Published var currentHeartRate: Double = 0
  @Published var isWorkoutActive = false
  @Published var isConnectedToPhone = false
  @Published var currentZone: HeartRateZone = HeartRateZone.defaultZones[0]
  let zones = HeartRateZone.defaultZones

  private var maxHeartRate: Int = 190
  private let connectivityProvider = WatchConnectivityProvider.shared

  override init() {
    super.init()
    connectivityProvider.delegate = self
    connectivityProvider.activate()
    loadMaxHeartRate()
  }

  func startWorkout() {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .other
    configuration.locationType = .unknown

    let typesToShare: Set<HKSampleType> = [
      HKObjectType.workoutType(),
    ]

    let typesToRead: Set<HKObjectType> = [
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
    ]

    healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, _ in
      guard let self, success else { return }

      do {
        self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
        self.builder = self.session?.associatedWorkoutBuilder()

        self.session?.delegate = self
        self.builder?.delegate = self

        self.builder?.dataSource = HKLiveWorkoutDataSource(
          healthStore: self.healthStore,
          workoutConfiguration: configuration
        )

        let startDate = Date()
        self.session?.startActivity(with: startDate)
        self.builder?.beginCollection(withStart: startDate) { _, _ in }

        DispatchQueue.main.async {
          self.isWorkoutActive = true
        }
      } catch {
        print("Failed to start workout: \(error)")
      }
    }
  }

  func stopWorkout() {
    session?.end()
    DispatchQueue.main.async {
      self.isWorkoutActive = false
      self.currentHeartRate = 0
    }
  }

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
