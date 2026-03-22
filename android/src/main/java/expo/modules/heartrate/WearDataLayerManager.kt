package expo.modules.heartrate

import android.content.Context
import com.google.android.gms.wearable.NodeClient
import com.google.android.gms.wearable.Wearable

class WearDataLayerManager(private val context: Context) {

  private val messageClient by lazy { Wearable.getMessageClient(context) }
  private val nodeClient: NodeClient by lazy { Wearable.getNodeClient(context) }

  fun sendStartCommand() {
    sendCommand("/start-workout")
  }

  fun sendStopCommand() {
    sendCommand("/stop-workout")
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

  private fun sendCommand(path: String) {
    nodeClient.connectedNodes.addOnSuccessListener { nodes ->
      for (node in nodes) {
        messageClient.sendMessage(node.id, path, byteArrayOf())
      }
    }
  }
}
