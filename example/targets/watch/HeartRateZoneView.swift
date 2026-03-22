#if os(watchOS)
import SwiftUI

struct HeartRateZoneView: View {
  let bpm: Double
  let zone: HeartRateZone
  let zones: [HeartRateZone]

  var body: some View {
    VStack(spacing: 8) {
      // Large BPM display
      Text("\(Int(bpm))")
        .font(.system(size: 56, weight: .ultraLight, design: .rounded))
        .foregroundStyle(colorForZone(zone))
        .contentTransition(.numericText())

      Text("BPM")
        .font(.caption2)
        .foregroundStyle(.secondary)

      // Zone name
      Text(zone.name)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(colorForZone(zone))

      // Zone bar
      HStack(spacing: 2) {
        ForEach(zones) { z in
          RoundedRectangle(cornerRadius: 3)
            .fill(colorForZone(z))
            .opacity(z.id == zone.id ? 1.0 : 0.25)
            .frame(height: z.id == zone.id ? 12 : 8)
        }
      }
      .padding(.horizontal, 4)
      .animation(.easeInOut(duration: 0.3), value: zone.id)
    }
  }

  private func colorForZone(_ zone: HeartRateZone) -> Color {
    switch zone.color {
    case .gray: return .gray
    case .green: return .green
    case .yellow: return .yellow
    case .orange: return .orange
    case .red: return .red
    }
  }
}
#endif
