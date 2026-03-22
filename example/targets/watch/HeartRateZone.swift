#if os(watchOS)
import Foundation

struct HeartRateZone: Identifiable {
  let id: Int
  let name: String
  let shortName: String
  let minPercent: Double
  let maxPercent: Double
  let color: ZoneColor

  func minBPM(maxHR: Int) -> Int {
    return Int(Double(maxHR) * minPercent)
  }

  func maxBPM(maxHR: Int) -> Int {
    return Int(Double(maxHR) * maxPercent)
  }

  static let defaultZones: [HeartRateZone] = [
    HeartRateZone(id: 1, name: "Warm Up", shortName: "Z1", minPercent: 0.0, maxPercent: 0.6, color: .gray),
    HeartRateZone(id: 2, name: "Fat Burn", shortName: "Z2", minPercent: 0.6, maxPercent: 0.7, color: .green),
    HeartRateZone(id: 3, name: "Cardio", shortName: "Z3", minPercent: 0.7, maxPercent: 0.8, color: .yellow),
    HeartRateZone(id: 4, name: "Hard", shortName: "Z4", minPercent: 0.8, maxPercent: 0.9, color: .orange),
    HeartRateZone(id: 5, name: "Maximum", shortName: "Z5", minPercent: 0.9, maxPercent: 1.0, color: .red),
  ]
}

enum ZoneColor {
  case gray, green, yellow, orange, red
}
#endif
