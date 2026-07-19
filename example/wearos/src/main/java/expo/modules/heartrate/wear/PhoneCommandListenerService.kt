package expo.modules.heartrate.wear

import android.content.Context
import android.content.Intent
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

class PhoneCommandListenerService : WearableListenerService() {

  override fun onMessageReceived(messageEvent: MessageEvent) {
    when (messageEvent.path) {
      "/start-workout", "/stop-workout" -> {
        val json = parsePayload(messageEvent.data)
        val command = json?.optString("command")?.takeIf { it.isNotEmpty() }
          ?: if (messageEvent.path == "/start-workout") "startWorkout" else "stopWorkout"
        handleCommand(command, json)
      }
    }
  }

  // The phone also persists the latest command as a data item so it survives
  // the watch being asleep/disconnected when the live message was sent
  override fun onDataChanged(dataEvents: DataEventBuffer) {
    for (event in dataEvents) {
      if (event.type != DataEvent.TYPE_CHANGED) continue
      if (event.dataItem.uri.path != "/workout-command") continue
      val payload = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("payload") ?: continue
      val json = try { JSONObject(payload) } catch (_: Exception) { null } ?: continue
      val command = json.optString("command").takeIf { it.isNotEmpty() } ?: continue
      handleCommand(command, json)
    }
  }

  private fun parsePayload(data: ByteArray): JSONObject? {
    if (data.isEmpty()) return null
    return try { JSONObject(String(data, Charsets.UTF_8)) } catch (_: Exception) { null }
  }

  private fun handleCommand(command: String, json: JSONObject?) {
    // Each command arrives up to twice (live message + persisted data item);
    // process each logical command once
    val commandId = json?.optString("commandId").orEmpty()
    if (commandId.isNotEmpty() && !CommandDeduper.shouldHandle(this, commandId)) return

    when (command) {
      "startWorkout" -> {
        val ts = json?.optLong("commandTimestamp", 0L) ?: 0L
        if (ts > 0 && System.currentTimeMillis() - ts > START_COMMAND_MAX_AGE_MS) {
          // Stale replayed start (e.g. phone app died mid-workout); a live
          // session re-sends a fresh start when the connection returns
          return
        }
        val intent = Intent(this, HeartRateService::class.java).apply {
          action = "START"
          json?.optString("activityType")?.takeIf { it.isNotEmpty() }?.let { putExtra("activityType", it) }
          json?.optString("workoutName")?.takeIf { it.isNotEmpty() }?.let { putExtra("workoutName", it) }
          json?.optString("sessionId")?.takeIf { it.isNotEmpty() }?.let { putExtra("sessionId", it) }
        }
        startForegroundService(intent)
      }
      "stopWorkout" -> {
        startForegroundService(Intent(this, HeartRateService::class.java).apply { action = "STOP" })
      }
    }
  }

  companion object {
    private const val START_COMMAND_MAX_AGE_MS = 10 * 60 * 1000L
  }
}

object CommandDeduper {
  private const val PREFS = "hr_command_dedupe"
  private const val KEY = "handled_ids"
  private const val MAX_IDS = 20

  @Synchronized
  fun shouldHandle(context: Context, commandId: String): Boolean {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val ids = prefs.getString(KEY, "").orEmpty()
      .split(',')
      .filter { it.isNotEmpty() }
      .toMutableList()
    if (commandId in ids) return false
    ids.add(commandId)
    while (ids.size > MAX_IDS) ids.removeAt(0)
    prefs.edit().putString(KEY, ids.joinToString(",")).apply()
    return true
  }
}
