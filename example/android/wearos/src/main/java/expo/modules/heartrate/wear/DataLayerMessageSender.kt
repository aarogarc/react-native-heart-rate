package expo.modules.heartrate.wear

import android.content.Context
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

class DataLayerMessageSender(private val context: Context) {

  private val messageClient by lazy { Wearable.getMessageClient(context) }
  private val nodeClient by lazy { Wearable.getNodeClient(context) }

  fun sendHeartRate(bpm: Double, timestamp: Long) {
    val payload = JSONObject().apply {
      put("bpm", bpm)
      put("timestamp", timestamp)
      put("source", "wearOS")
    }.toString().toByteArray()

    nodeClient.connectedNodes.addOnSuccessListener { nodes ->
      for (node in nodes) {
        messageClient.sendMessage(node.id, "/heart-rate", payload)
      }
    }
  }
}
