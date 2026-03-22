package expo.modules.heartrate

/**
 * Static bridge between WearDataLayerListenerService (system-managed)
 * and HeartRateModule (React Native lifecycle).
 *
 * The listener service doesn't have direct access to the module instance,
 * so we use this singleton to forward HR data. Events are buffered if
 * the module hasn't registered yet.
 */
object HeartRateEventBridge {
  private var listener: ((HeartRateEvent) -> Unit)? = null
  private val buffer = mutableListOf<HeartRateEvent>()
  private const val MAX_BUFFER_SIZE = 50

  fun register(listener: (HeartRateEvent) -> Unit) {
    this.listener = listener
    // Flush any buffered events
    synchronized(buffer) {
      buffer.forEach { listener(it) }
      buffer.clear()
    }
  }

  fun unregister() {
    listener = null
  }

  fun emit(event: HeartRateEvent) {
    val currentListener = listener
    if (currentListener != null) {
      currentListener(event)
    } else {
      synchronized(buffer) {
        if (buffer.size < MAX_BUFFER_SIZE) {
          buffer.add(event)
        }
      }
    }
  }
}

data class HeartRateEvent(
  val bpm: Double,
  val timestamp: Long,
)
