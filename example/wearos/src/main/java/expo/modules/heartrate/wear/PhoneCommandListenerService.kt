package expo.modules.heartrate.wear

import android.content.Intent
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class PhoneCommandListenerService : WearableListenerService() {

  override fun onMessageReceived(messageEvent: MessageEvent) {
    when (messageEvent.path) {
      "/start-workout" -> {
        val intent = Intent(this, HeartRateService::class.java).apply {
          action = "START"
          if (messageEvent.data.isNotEmpty()) {
            try {
              val json = String(messageEvent.data, Charsets.UTF_8)
              val config = org.json.JSONObject(json)
              if (config.has("activityType")) {
                putExtra("activityType", config.getString("activityType"))
              }
              if (config.has("workoutName")) {
                putExtra("workoutName", config.getString("workoutName"))
              }
            } catch (_: Exception) {}
          }
        }
        startForegroundService(intent)
      }
      "/stop-workout" -> {
        val intent = Intent(this, HeartRateService::class.java).apply {
          action = "STOP"
        }
        startService(intent)
      }
    }
  }
}
