package expo.modules.heartrate

import android.content.Context
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.NodeClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject
import java.util.UUID

class WearDataLayerManager(private val context: Context) {

  interface Listener {
    fun onConnectionChange(isConnected: Boolean)
    fun onError(message: String, code: String)
  }

  var listener: Listener? = null

  private val messageClient by lazy { Wearable.getMessageClient(context) }
  private val nodeClient: NodeClient by lazy { Wearable.getNodeClient(context) }
  private val dataClient by lazy { Wearable.getDataClient(context) }
  private val capabilityClient by lazy { Wearable.getCapabilityClient(context) }

  private val capabilityListener = CapabilityClient.OnCapabilityChangedListener { info ->
    listener?.onConnectionChange(info.nodes.any { it.isNearby })
  }

  fun startListening() {
    capabilityClient.addListener(capabilityListener, WEAR_CAPABILITY)
    capabilityClient.getCapability(WEAR_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
      .addOnSuccessListener { info ->
        listener?.onConnectionChange(info.nodes.isNotEmpty())
      }
  }

  fun stopListening() {
    capabilityClient.removeListener(capabilityListener, WEAR_CAPABILITY)
  }

  fun sendStartCommand(config: Map<String, String>? = null) {
    val fields = mutableMapOf("command" to "startWorkout")
    config?.get("activityType")?.let { fields["activityType"] = it }
    config?.get("workoutName")?.let { fields["workoutName"] = it }
    config?.get("sessionId")?.let { fields["sessionId"] = it }
    sendCommand("/start-workout", fields)
  }

  fun sendStopCommand() {
    sendCommand("/stop-workout", mutableMapOf("command" to "stopWorkout"))
  }

  fun checkConnectivity(callback: (Boolean) -> Unit) {
    nodeClient.connectedNodes
      .addOnSuccessListener { nodes ->
        callback(nodes.isNotEmpty())
      }
      .addOnFailureListener {
        callback(false)
      }
  }

  private fun sendCommand(path: String, fields: MutableMap<String, String>) {
    // commandId lets the watch dedupe message/data-item double delivery;
    // commandTimestamp lets it discard stale replayed starts. The changing
    // values also guarantee each data item's content is unique, so the Data
    // Layer never suppresses it as an unchanged item.
    fields["commandId"] = UUID.randomUUID().toString()
    fields["commandTimestamp"] = System.currentTimeMillis().toString()
    val payload = JSONObject(fields.toMap()).toString()
    val payloadBytes = payload.toByteArray(Charsets.UTF_8)

    // Persist the latest command as a data item so the watch receives it on
    // reconnect/wake even when the live message below is lost
    val request = PutDataMapRequest.create(COMMAND_DATA_PATH).apply {
      dataMap.putString("payload", payload)
    }.asPutDataRequest().setUrgent()
    dataClient.putDataItem(request).addOnFailureListener { e ->
      listener?.onError(e.message ?: "Failed to persist command", "COMMAND_PERSIST_FAILED")
    }

    // Live message for immediate delivery
    nodeClient.connectedNodes
      .addOnSuccessListener { nodes ->
        for (node in nodes) {
          messageClient.sendMessage(node.id, path, payloadBytes).addOnFailureListener { e ->
            listener?.onError(e.message ?: "Failed to send command", "MESSAGE_SEND_FAILED")
          }
        }
      }
      .addOnFailureListener { e ->
        listener?.onError(e.message ?: "Failed to enumerate nodes", "NODES_UNAVAILABLE")
      }
  }

  companion object {
    const val WEAR_CAPABILITY = "muscle_memory_wear"
    const val COMMAND_DATA_PATH = "/workout-command"
  }
}
