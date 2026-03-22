package expo.modules.heartrate.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

class MainActivity : ComponentActivity() {
  private val permissionsGranted = mutableStateOf(false)

  private val requiredPermissions = arrayOf(
    Manifest.permission.BODY_SENSORS,
    Manifest.permission.ACTIVITY_RECOGNITION,
  )

  private val permissionLauncher = registerForActivityResult(
    ActivityResultContracts.RequestMultiplePermissions()
  ) { results ->
    permissionsGranted.value = results.values.all { it }
    if (permissionsGranted.value) {
      startHeartRateService()
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    permissionsGranted.value = requiredPermissions.all {
      ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    // Auto-start: request permissions or start service immediately
    if (permissionsGranted.value) {
      if (!HeartRateService.isActive.value) {
        startHeartRateService()
      }
    } else {
      permissionLauncher.launch(requiredPermissions)
    }

    setContent {
      MaterialTheme {
        HeartRateScreen()
      }
    }
  }

  private fun startHeartRateService() {
    val intent = Intent(this, HeartRateService::class.java).apply {
      action = "START"
    }
    startForegroundService(intent)
  }

  @Composable
  fun HeartRateScreen() {
    val bpm by HeartRateService.currentBPM.collectAsState()
    val isActive by HeartRateService.isActive.collectAsState()

    val currentZone = HeartRateZoneCalculator.zoneForBPM(bpm.toInt())

    Column(
      modifier = Modifier
        .fillMaxSize()
        .background(Color.Black)
        .padding(16.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
    ) {
      if (isActive) {
        // BPM display
        Text(
          text = if (bpm > 0) "${bpm.toInt()}" else "--",
          fontSize = 48.sp,
          fontWeight = FontWeight.ExtraLight,
          color = currentZone.color,
          textAlign = TextAlign.Center,
        )

        Text(
          text = "BPM",
          fontSize = 12.sp,
          color = Color.Gray,
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Zone bar
        Row(
          modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
          horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
          HeartRateZoneCalculator.zones.forEach { zone ->
            val isCurrentZone = zone.id == currentZone.id
            Box(
              modifier = Modifier
                .weight(1f)
                .height(if (isCurrentZone) 12.dp else 8.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(zone.color.copy(alpha = if (isCurrentZone) 1f else 0.25f)),
            )
          }
        }
      } else {
        // Starting state
        CircularProgressIndicator(
          indicatorColor = Color.Red,
          trackColor = Color.DarkGray,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
          text = "Starting...",
          fontSize = 14.sp,
          color = Color.Gray,
        )
      }
    }
  }
}
