package expo.modules.heartrate

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

class WearDataLayerListenerService : WearableListenerService() {

  override fun onMessageReceived(messageEvent: MessageEvent) {
    when (messageEvent.path) {
      "/heart-rate" -> {
        val json = JSONObject(String(messageEvent.data))
        val bpm = json.getDouble("bpm")
        val timestamp = json.getLong("timestamp")

        HeartRateEventBridge.emit(HeartRateEvent(bpm = bpm, timestamp = timestamp))
      }
      "/workout-error" -> {
        val message = try {
          JSONObject(String(messageEvent.data)).optString("message", "Watch workout error")
        } catch (_: Exception) {
          "Watch workout error"
        }
        HeartRateEventBridge.emitError(message)
      }
    }
  }
}
