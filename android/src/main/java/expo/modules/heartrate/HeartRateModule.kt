package expo.modules.heartrate

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class HeartRateModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("HeartRate")

    Events("heartRateUpdate", "connectionChange", "error")

    Function("startMonitoring") {
      // TODO: Send start command to WearOS watch via MessageClient
    }

    Function("stopMonitoring") {
      // TODO: Send stop command to WearOS watch via MessageClient
    }

    AsyncFunction("isWatchConnected") {
      // TODO: Check connected nodes via NodeClient
      false
    }

    AsyncFunction("getHeartRateZones") {
      // TODO: Calculate zones from user profile (220 - age)
      defaultZones()
    }
  }

  private fun defaultZones(): List<Map<String, Any>> {
    return listOf(
      mapOf("name" to "Zone 1 — Warm Up", "min" to 0, "max" to 60, "color" to "#94A3B8"),
      mapOf("name" to "Zone 2 — Fat Burn", "min" to 60, "max" to 70, "color" to "#22C55E"),
      mapOf("name" to "Zone 3 — Cardio", "min" to 70, "max" to 80, "color" to "#EAB308"),
      mapOf("name" to "Zone 4 — Hard", "min" to 80, "max" to 90, "color" to "#F97316"),
      mapOf("name" to "Zone 5 — Maximum", "min" to 90, "max" to 100, "color" to "#EF4444"),
    )
  }
}
