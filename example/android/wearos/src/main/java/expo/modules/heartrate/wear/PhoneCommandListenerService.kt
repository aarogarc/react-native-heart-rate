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
