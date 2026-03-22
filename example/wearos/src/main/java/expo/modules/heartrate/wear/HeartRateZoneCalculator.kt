package expo.modules.heartrate.wear

import androidx.compose.ui.graphics.Color

data class HeartRateZone(
  val id: Int,
  val name: String,
  val shortName: String,
  val minPercent: Float,
  val maxPercent: Float,
  val color: Color,
) {
  fun minBPM(maxHR: Int): Int = (maxHR * minPercent).toInt()
  fun maxBPM(maxHR: Int): Int = (maxHR * maxPercent).toInt()
}

object HeartRateZoneCalculator {
  var maxHeartRate: Int = 190
    private set

  val zones = listOf(
    HeartRateZone(1, "Warm Up", "Z1", 0.0f, 0.6f, Color(0xFF94A3B8)),
    HeartRateZone(2, "Fat Burn", "Z2", 0.6f, 0.7f, Color(0xFF22C55E)),
    HeartRateZone(3, "Cardio", "Z3", 0.7f, 0.8f, Color(0xFFEAB308)),
    HeartRateZone(4, "Hard", "Z4", 0.8f, 0.9f, Color(0xFFF97316)),
    HeartRateZone(5, "Maximum", "Z5", 0.9f, 1.0f, Color(0xFFEF4444)),
  )

  fun setAge(age: Int) {
    maxHeartRate = maxOf(220 - age, 100)
  }

  fun zoneForBPM(bpm: Int): HeartRateZone {
    return zones.lastOrNull { bpm >= it.minBPM(maxHeartRate) } ?: zones[0]
  }

  fun percentOfMax(bpm: Int): Float {
    return (bpm.toFloat() / maxHeartRate).coerceIn(0f, 1f)
  }
}
