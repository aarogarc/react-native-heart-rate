import HealthKit

struct HeartRateZoneInfo {
  let name: String
  let min: Int
  let max: Int
  let color: String
}

class HeartRateZoneCalculator {
  static let shared = HeartRateZoneCalculator()

  private let healthStore = HKHealthStore()
  private var maxHeartRate: Int = 190 // default fallback
  private var zones: [HeartRateZoneInfo] = []

  private init() {
    zones = buildZones(maxHR: maxHeartRate)
  }

  /// Request HealthKit authorization and load the user's date of birth to calculate max HR.
  func initialize(completion: @escaping (Bool) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(false)
      return
    }

    let typesToRead: Set<HKObjectType> = [
      HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
    ]

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
      guard let self, success else {
        completion(false)
        return
      }

      self.loadMaxHeartRate()
      completion(true)
    }
  }

  private func loadMaxHeartRate() {
    do {
      let dobComponents = try healthStore.dateOfBirthComponents()
      if let year = dobComponents.year {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let age = currentYear - year
        maxHeartRate = max(220 - age, 100) // floor at 100
        zones = buildZones(maxHR: maxHeartRate)
      }
    } catch {
      // Use default max HR if DOB is not available
    }
  }

  private func buildZones(maxHR: Int) -> [HeartRateZoneInfo] {
    return [
      HeartRateZoneInfo(name: "Zone 1 — Warm Up", min: 0, max: Int(Double(maxHR) * 0.6), color: "#94A3B8"),
      HeartRateZoneInfo(name: "Zone 2 — Fat Burn", min: Int(Double(maxHR) * 0.6), max: Int(Double(maxHR) * 0.7), color: "#22C55E"),
      HeartRateZoneInfo(name: "Zone 3 — Cardio", min: Int(Double(maxHR) * 0.7), max: Int(Double(maxHR) * 0.8), color: "#EAB308"),
      HeartRateZoneInfo(name: "Zone 4 — Hard", min: Int(Double(maxHR) * 0.8), max: Int(Double(maxHR) * 0.9), color: "#F97316"),
      HeartRateZoneInfo(name: "Zone 5 — Maximum", min: Int(Double(maxHR) * 0.9), max: maxHR, color: "#EF4444"),
    ]
  }

  func getZones() -> [[String: Any]] {
    return zones.map { zone in
      [
        "name": zone.name,
        "min": zone.min,
        "max": zone.max,
        "color": zone.color,
      ] as [String: Any]
    }
  }

  func getZoneStatus(bpm: Int) -> [String: Any] {
    let currentZone = zones.last { bpm >= $0.min } ?? zones[0]
    let percentOfMax = min(100, Int(Double(bpm) / Double(maxHeartRate) * 100))

    return [
      "currentZone": [
        "name": currentZone.name,
        "min": currentZone.min,
        "max": currentZone.max,
        "color": currentZone.color,
      ],
      "zones": getZones(),
      "percentOfMax": percentOfMax,
    ]
  }
}
