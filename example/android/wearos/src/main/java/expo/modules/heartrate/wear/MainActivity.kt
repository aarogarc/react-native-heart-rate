package expo.modules.heartrate.wear

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContent {
      MaterialTheme {
        HeartRateScreen()
      }
    }
  }

  @Composable
  fun HeartRateScreen() {
    val service = HeartRateService.instance
    val bpm by (service?.currentBPM ?: kotlinx.coroutines.flow.MutableStateFlow(0.0)).collectAsState()
    val isActive by (service?.isActive ?: kotlinx.coroutines.flow.MutableStateFlow(false)).collectAsState()

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

        Spacer(modifier = Modifier.height(4.dp))

        // Zone name
        Text(
          text = currentZone.name,
          fontSize = 14.sp,
          fontWeight = FontWeight.SemiBold,
          color = currentZone.color,
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

        Spacer(modifier = Modifier.height(12.dp))

        Button(
          onClick = {
            val intent = Intent(this@MainActivity, HeartRateService::class.java).apply {
              action = "STOP"
            }
            startService(intent)
          },
          colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFFEF4444)),
        ) {
          Text("Stop", fontSize = 14.sp)
        }
      } else {
        // Idle state
        Text(
          text = "Heart Rate",
          fontSize = 18.sp,
          fontWeight = FontWeight.Medium,
          color = Color.White,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(
          onClick = {
            val intent = Intent(this@MainActivity, HeartRateService::class.java).apply {
              action = "START"
            }
            startForegroundService(intent)
          },
          colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF22C55E)),
        ) {
          Text("Start", fontSize = 14.sp)
        }
      }
    }
  }
}
