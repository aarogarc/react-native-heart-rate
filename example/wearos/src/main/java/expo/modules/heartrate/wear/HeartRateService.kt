package expo.modules.heartrate.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.guava.await
import kotlin.random.Random

class HeartRateService : Service() {

  private var exerciseClient: ExerciseClient? = null
  private lateinit var messageSender: DataLayerMessageSender
  private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var simulationHandler: Handler? = null
  private var simulationRunnable: Runnable? = null
  private var simulatedBPM = 72.0

  private val isEmulator: Boolean
    get() = Build.FINGERPRINT.contains("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("sdk_gwear") ||
            Build.MODEL.contains("sdk_gphone") ||
            Build.HARDWARE.contains("ranchu")

  companion object {
    const val CHANNEL_ID = "heart_rate_channel"
    const val NOTIFICATION_ID = 1

    // Global state flows so UI can observe even before service starts
    val currentBPM = MutableStateFlow(0.0)
    val isActive = MutableStateFlow(false)
    var instance: HeartRateService? = null
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    instance = this
    if (!isEmulator) {
      exerciseClient = HealthServices.getClient(this).exerciseClient
    }
    messageSender = DataLayerMessageSender(this)
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      "START" -> {
        val activityType = intent.getStringExtra("activityType")
        if (isEmulator) startSimulation() else startExercise(activityType)
      }
      "STOP" -> {
        if (isEmulator) stopSimulation() else stopExercise()
      }
    }
    return START_STICKY
  }

  override fun onDestroy() {
    instance = null
    stopSimulation()
    serviceScope.cancel()
    super.onDestroy()
  }

  // MARK: - Simulation

  private fun startSimulation() {
    startForeground(NOTIFICATION_ID, buildNotification())
    isActive.value = true
    simulatedBPM = 72.0

    simulationHandler = Handler(Looper.getMainLooper())
    simulationRunnable = object : Runnable {
      override fun run() {
        if (!isActive.value) return
        val delta = Random.nextDouble(-3.0, 5.0)
        simulatedBPM = (simulatedBPM + delta).coerceIn(55.0, 185.0)
        currentBPM.value = simulatedBPM
        messageSender.sendHeartRate(simulatedBPM, System.currentTimeMillis())
        simulationHandler?.postDelayed(this, 1000)
      }
    }
    simulationHandler?.post(simulationRunnable!!)
  }

  private fun stopSimulation() {
    simulationRunnable?.let { simulationHandler?.removeCallbacks(it) }
    simulationHandler = null
    simulationRunnable = null
    isActive.value = false
    currentBPM.value = 0.0
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
  }

  // MARK: - Real Exercise

  private fun startExercise(activityType: String? = null) {
    startForeground(NOTIFICATION_ID, buildNotification())

    serviceScope.launch {
      val exerciseType = mapActivityType(activityType)
      val config = ExerciseConfig.builder(exerciseType)
        .setDataTypes(setOf(DataType.HEART_RATE_BPM))
        .build()

      exerciseClient?.setUpdateCallback(exerciseCallback)
      exerciseClient?.startExerciseAsync(config)?.await()
      isActive.value = true
    }
  }

  private fun mapActivityType(type: String?): ExerciseType {
    return when (type) {
      "traditionalStrengthTraining" -> ExerciseType.STRENGTH_TRAINING
      "functionalStrengthTraining" -> ExerciseType.STRENGTH_TRAINING
      "running" -> ExerciseType.RUNNING
      "cycling" -> ExerciseType.BIKING
      "walking" -> ExerciseType.WALKING
      "hiking" -> ExerciseType.HIKING
      "yoga" -> ExerciseType.YOGA
      "rowing" -> ExerciseType.ROWING_MACHINE
      "swimming" -> ExerciseType.SWIMMING_POOL
      "crossTraining" -> ExerciseType.WORKOUT
      "elliptical" -> ExerciseType.ELLIPTICAL
      "stairClimbing" -> ExerciseType.STAIR_CLIMBING
      "pilates" -> ExerciseType.PILATES
      "dance" -> ExerciseType.DANCING
      "coreTraining" -> ExerciseType.WORKOUT
      "flexibility" -> ExerciseType.STRETCHING
      "highIntensityIntervalTraining" -> ExerciseType.HIGH_INTENSITY_INTERVAL_TRAINING
      "jumpRope" -> ExerciseType.JUMP_ROPE
      "kickboxing" -> ExerciseType.KICKBOXING
      "mixedCardio" -> ExerciseType.WORKOUT
      else -> ExerciseType.WORKOUT
    }
  }

  private fun stopExercise() {
    serviceScope.launch {
      exerciseClient?.endExerciseAsync()?.await()
      exerciseClient?.clearUpdateCallbackAsync(exerciseCallback)?.await()
      isActive.value = false
      currentBPM.value = 0.0
      stopForeground(STOP_FOREGROUND_REMOVE)
      stopSelf()
    }
  }

  private val exerciseCallback = object : ExerciseUpdateCallback {
    override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
      val heartRatePoints = update.latestMetrics.getData(DataType.HEART_RATE_BPM)
      for (point in heartRatePoints) {
        val bpm = point.value
        currentBPM.value = bpm
        messageSender.sendHeartRate(bpm, System.currentTimeMillis())
      }
    }

    override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
    override fun onRegistered() {}
    override fun onRegistrationFailed(throwable: Throwable) {}
    override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Heart Rate Monitoring",
        NotificationManager.IMPORTANCE_LOW,
      )
      val manager = getSystemService(NotificationManager::class.java)
      manager.createNotificationChannel(channel)
    }
  }

  private fun buildNotification(): Notification {
    return Notification.Builder(this, CHANNEL_ID)
      .setContentTitle("Heart Rate Monitor")
      .setContentText("Monitoring heart rate...")
      .setSmallIcon(android.R.drawable.ic_menu_mylocation)
      .setOngoing(true)
      .build()
  }
}
