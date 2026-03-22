package expo.modules.heartrate

object HeartRateZoneCalculator {
  // Default max HR — consumers should configure this based on user age
  var maxHeartRate: Int = 190
    private set

  data class Zone(
    val name: String,
    val min: Int,
    val max: Int,
    val color: String,
  )

  fun setAge(age: Int) {
    maxHeartRate = maxOf(220 - age, 100)
  }

  fun getZones(): List<Zone> {
    val max = maxHeartRate
    return listOf(
      Zone("Zone 1 — Warm Up", 0, (max * 0.6).toInt(), "#94A3B8"),
      Zone("Zone 2 — Fat Burn", (max * 0.6).toInt(), (max * 0.7).toInt(), "#22C55E"),
      Zone("Zone 3 — Cardio", (max * 0.7).toInt(), (max * 0.8).toInt(), "#EAB308"),
      Zone("Zone 4 — Hard", (max * 0.8).toInt(), (max * 0.9).toInt(), "#F97316"),
      Zone("Zone 5 — Maximum", (max * 0.9).toInt(), max, "#EF4444"),
    )
  }

  fun getZonesAsMaps(): List<Map<String, Any>> {
    return getZones().map { zone ->
      mapOf(
        "name" to zone.name,
        "min" to zone.min,
        "max" to zone.max,
        "color" to zone.color,
      )
    }
  }

  fun getZoneStatus(bpm: Int): Map<String, Any> {
    val zones = getZones()
    val currentZone = zones.lastOrNull { bpm >= it.min } ?: zones[0]
    val percentOfMax = minOf(100, (bpm.toDouble() / maxHeartRate * 100).toInt())

    return mapOf(
      "currentZone" to mapOf(
        "name" to currentZone.name,
        "min" to currentZone.min,
        "max" to currentZone.max,
        "color" to currentZone.color,
      ),
      "zones" to getZonesAsMaps(),
      "percentOfMax" to percentOfMax,
    )
  }
}
