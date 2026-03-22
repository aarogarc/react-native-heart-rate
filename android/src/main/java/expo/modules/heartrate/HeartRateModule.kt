package expo.modules.heartrate

import android.os.Build
import android.os.Handler
import android.os.Looper
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlin.random.Random

class HeartRateModule : Module() {
  private val wearManager by lazy { WearDataLayerManager(appContext.reactContext!!) }
  private var isMonitoring = false
  private var simulationHandler: Handler? = null
  private var simulationRunnable: Runnable? = null
  private var simulatedBPM = 72.0

  private val isEmulator: Boolean
    get() = Build.FINGERPRINT.contains("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("sdk_gphone")

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
      stopSimulation()
    }

    Function("startMonitoring") {
      isMonitoring = true
      if (isEmulator) {
        startSimulation()
      } else {
        wearManager.sendStartCommand()
      }
    }

    Function("stopMonitoring") {
      isMonitoring = false
      if (isEmulator) {
        stopSimulation()
      } else {
        wearManager.sendStopCommand()
      }
    }

    AsyncFunction("isWatchConnected") { promise: expo.modules.kotlin.Promise ->
      if (isEmulator) {
        promise.resolve(true)
      } else {
        wearManager.checkConnectivity { connected ->
          promise.resolve(connected)
        }
      }
    }

    AsyncFunction("getHeartRateZones") {
      HeartRateZoneCalculator.getZonesAsMaps()
    }
  }

  private fun startSimulation() {
    simulatedBPM = 72.0
    simulationHandler = Handler(Looper.getMainLooper())
    simulationRunnable = object : Runnable {
      override fun run() {
        if (!isMonitoring) return
        val delta = Random.nextDouble(-3.0, 5.0)
        simulatedBPM = (simulatedBPM + delta).coerceIn(55.0, 185.0)

        val zoneStatus = HeartRateZoneCalculator.getZoneStatus(simulatedBPM.toInt())
        sendEvent("heartRateUpdate", mapOf(
          "bpm" to simulatedBPM,
          "timestamp" to System.currentTimeMillis(),
          "source" to "wearOS",
          "zone" to zoneStatus,
        ))
        simulationHandler?.postDelayed(this, 1000)
      }
    }
    simulationHandler?.post(simulationRunnable!!)
  }

  private fun stopSimulation() {
    simulationRunnable?.let { simulationHandler?.removeCallbacks(it) }
    simulationHandler = null
    simulationRunnable = null
  }
}
