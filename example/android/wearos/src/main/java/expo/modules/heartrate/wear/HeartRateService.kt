package expo.modules.heartrate.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
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

class HeartRateService : Service() {

  private lateinit var exerciseClient: ExerciseClient
  private lateinit var messageSender: DataLayerMessageSender
  private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

  private val _currentBPM = MutableStateFlow(0.0)
  val currentBPM: StateFlow<Double> = _currentBPM

  private val _isActive = MutableStateFlow(false)
  val isActive: StateFlow<Boolean> = _isActive

  companion object {
    const val CHANNEL_ID = "heart_rate_channel"
    const val NOTIFICATION_ID = 1
    var instance: HeartRateService? = null
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    instance = this
    exerciseClient = HealthServices.getClient(this).exerciseClient
    messageSender = DataLayerMessageSender(this)
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      "START" -> startExercise()
      "STOP" -> stopExercise()
    }
    return START_STICKY
  }

  override fun onDestroy() {
    instance = null
    serviceScope.cancel()
    super.onDestroy()
  }

  private fun startExercise() {
    startForeground(NOTIFICATION_ID, buildNotification())

    serviceScope.launch {
      val config = ExerciseConfig.builder(ExerciseType.RUNNING)
        .setDataTypes(setOf(DataType.HEART_RATE_BPM))
        .build()

      exerciseClient.setUpdateCallback(exerciseCallback)
      exerciseClient.startExerciseAsync(config).await()
      _isActive.value = true
    }
  }

  private fun stopExercise() {
    serviceScope.launch {
      exerciseClient.endExerciseAsync().await()
      exerciseClient.clearUpdateCallbackAsync(exerciseCallback).await()
      _isActive.value = false
      _currentBPM.value = 0.0
      stopForeground(STOP_FOREGROUND_REMOVE)
      stopSelf()
    }
  }

  private val exerciseCallback = object : ExerciseUpdateCallback {
    override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
      val heartRatePoints = update.latestMetrics.getData(DataType.HEART_RATE_BPM)
      for (point in heartRatePoints) {
        val bpm = point.value
        _currentBPM.value = bpm
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
