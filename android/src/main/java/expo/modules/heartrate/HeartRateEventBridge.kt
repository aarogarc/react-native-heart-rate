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
  private var errorListener: ((String) -> Unit)? = null
  private var energyListener: ((ActiveEnergyEvent) -> Unit)? = null
  private var lastEnergy: ActiveEnergyEvent? = null
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

  fun registerErrorListener(listener: (String) -> Unit) {
    errorListener = listener
  }

  fun registerEnergyListener(listener: (ActiveEnergyEvent) -> Unit) {
    energyListener = listener
    lastEnergy?.let { listener(it) }
  }

  fun unregister() {
    listener = null
    errorListener = null
    energyListener = null
  }

  fun emitEnergy(event: ActiveEnergyEvent) {
    lastEnergy = event
    energyListener?.invoke(event)
  }

  fun emitError(message: String) {
    errorListener?.invoke(message)
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

data class ActiveEnergyEvent(
  val kcal: Double,
  val timestamp: Long,
)
