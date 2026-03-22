package expo.modules.heartrate

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class HeartRateModule : Module() {
  private val wearManager by lazy { WearDataLayerManager(appContext.reactContext!!) }
  private var isMonitoring = false

  override fun definition() = ModuleDefinition {
    Name("HeartRate")

    Events("heartRateUpdate", "connectionChange", "error")

    OnCreate {
      HeartRateEventBridge.register { event ->
        if (isMonitoring) {
          val zoneStatus = HeartRateZoneCalculator.getZoneStatus(event.bpm.toInt())
          sendEvent("heartRateUpdate", mapOf(
            "bpm" to event.bpm,
            "timestamp" to event.timestamp,
            "source" to "wearOS",
            "zone" to zoneStatus,
          ))
        }
      }
    }

    OnDestroy {
      HeartRateEventBridge.unregister()
    }

    Function("startMonitoring") {
      isMonitoring = true
      wearManager.sendStartCommand()
    }

    Function("stopMonitoring") {
      isMonitoring = false
      wearManager.sendStopCommand()
    }

    AsyncFunction("isWatchConnected") { promise: expo.modules.kotlin.Promise ->
      wearManager.checkConnectivity { connected ->
        promise.resolve(connected)
      }
    }

    AsyncFunction("getHeartRateZones") {
      HeartRateZoneCalculator.getZonesAsMaps()
    }
  }
}
