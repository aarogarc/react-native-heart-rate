# react-native-heart-rate

Real-time heart rate monitoring from Apple Watch (watchOS) and Wear OS devices for React Native apps built with Expo.

## Features

- Real-time BPM streaming from wearable devices
- Heart rate zone calculation (5 zones based on max HR)
- Watch/wearable connection status monitoring
- Configurable workout type and name for Apple Health / Google Fit
- Automatic simulator/emulator mode for development
- HealthKit age-based max HR calculation (iOS)

## Installation

```bash
npm install react-native-heart-rate
# or
bun add react-native-heart-rate
```

This is an Expo native module. After installing, you must create a new development build — it will not work with Expo Go.

## Platform Setup

The phone-side native module is auto-linked by Expo. However, the companion watch/wearable app requires additional setup per platform because it is a standalone native app that runs on the watch.

### iOS (Apple Watch)

The watchOS companion app is set up using [`@bacons/apple-targets`](https://github.com/EvanBacon/apple-targets), which generates the watchOS target in your Xcode project during prebuild.

#### 1. Install the config plugin

```bash
npm install @bacons/apple-targets
```

#### 2. Create the watch target directory

```
mkdir -p targets/watch
```

#### 3. Copy the watch app source files

Copy the following files from this package's `example/targets/watch/` directory into your `targets/watch/` directory:

```
targets/watch/
├── expo-target.config.js    # Target configuration (customize this)
├── Info.plist               # Watch app metadata
├── Assets.xcassets/         # App icon and assets
├── HeartRateWatchApp.swift  # SwiftUI app entry point
├── WorkoutManager.swift     # HealthKit workout session + HR monitoring
├── WatchConnectivityProvider.swift  # Phone <-> Watch communication
├── HeartRateZone.swift      # Zone definitions
└── HeartRateZoneView.swift  # Watch UI
```

#### 4. Customize `expo-target.config.js`

Update the target name and display name for your app:

```js
module.exports = {
  type: "watch",
  name: "YourAppWatch",
  displayName: "Your App",
  deploymentTarget: "10.0",
  frameworks: ["HealthKit", "WatchConnectivity"],
  entitlements: {
    "com.apple.developer.healthkit": true,
    "com.apple.developer.healthkit.access": ["health-records"],
  },
  infoPlist: {
    NSHealthShareUsageDescription: "Your app monitors your heart rate during workouts.",
    NSHealthUpdateUsageDescription: "Your app saves workout data to Apple Health.",
  },
};
```

#### 5. Register the plugin in your app config

```json
{
  "plugins": [
    "@bacons/apple-targets"
  ]
}
```

#### 6. Update HealthKit description

If you're using `@kingstinct/react-native-healthkit`, update its description to mention heart rate:

```json
["@kingstinct/react-native-healthkit", {
  "NSHealthShareUsageDescription": "Your app reads your heart rate to track workouts."
}]
```

#### 7. Clean prebuild

The watch target is generated during prebuild. If you have an existing `ios/` directory, you must do a clean prebuild:

```bash
npx expo prebuild -p ios --clean
```

After this, `expo run:ios` will build both the phone and watch apps. The watch app is automatically installed on the paired Apple Watch.

---

### Android (Wear OS)

The Wear OS companion app is a separate Android module built alongside your phone app using an Expo config plugin.

#### 1. Copy the wearos directory

Copy the `example/wearos/` directory into the root of your project:

```
wearos/
├── build.gradle             # Gradle config (customize namespace/applicationId)
├── src/main/
│   ├── AndroidManifest.xml  # Permissions and service declarations
│   ├── java/expo/modules/heartrate/wear/
│   │   ├── MainActivity.kt              # Compose UI
│   │   ├── HeartRateService.kt          # Health Services heart rate monitoring
│   │   ├── PhoneCommandListenerService.kt  # Receives commands from phone
│   │   ├── DataLayerMessageSender.kt    # Sends HR data to phone
│   │   └── HeartRateZoneCalculator.kt   # Zone calculation
│   └── res/
│       └── values/strings.xml           # App name
```

#### 2. Update `wearos/build.gradle`

Change the namespace and applicationId to match your app:

```gradle
android {
    namespace 'com.yourcompany.yourapp.wear'
    defaultConfig {
        applicationId "com.yourcompany.yourapp.wear"
    }
}
```

#### 3. Update app label

In `wearos/src/main/AndroidManifest.xml`, change the label:

```xml
<application android:label="Your App">
```

And in `wearos/src/main/res/values/strings.xml`:

```xml
<string name="app_name">Your App</string>
```

#### 4. Create the config plugin

Create `plugins/withWearOS.js` in your project:

```js
const {
  withSettingsGradle,
  withAppBuildGradle,
  withDangerousMod,
} = require("expo/config-plugins");
const fs = require("fs");
const path = require("path");

function withWearOS(config) {
  config = withSettingsGradle(config, (config) => {
    if (!config.modResults.contents.includes("include ':wearos'")) {
      config.modResults.contents = config.modResults.contents.replace(
        "include ':app'",
        "include ':app'\ninclude ':wearos'\nproject(':wearos').projectDir = new File(rootProject.projectDir, '../wearos')"
      );
    }
    return config;
  });

  config = withAppBuildGradle(config, (config) => {
    if (!config.modResults.contents.includes("wearos:assemble")) {
      config.modResults.contents += `
afterEvaluate {
    tasks.matching { it.name == "assembleDebug" }.configureEach {
        finalizedBy(":wearos:assembleDebug")
    }
    tasks.matching { it.name == "assembleRelease" }.configureEach {
        finalizedBy(":wearos:assembleRelease")
    }
}
`;
    }
    return config;
  });

  config = withDangerousMod(config, [
    "android",
    (config) => {
      const wearosResDir = path.join(
        config.modRequest.projectRoot, "wearos", "src", "main", "res"
      );
      const iconSource = path.join(
        config.modRequest.projectRoot, "assets", "icon.png"
      );
      if (fs.existsSync(iconSource)) {
        const mipmapDir = path.join(wearosResDir, "mipmap-hdpi");
        fs.mkdirSync(mipmapDir, { recursive: true });
        fs.copyFileSync(iconSource, path.join(mipmapDir, "ic_launcher.png"));
      }
      return config;
    },
  ]);

  return config;
}

module.exports = withWearOS;
```

#### 5. Register the plugin

```json
{
  "plugins": [
    "./plugins/withWearOS"
  ]
}
```

#### 6. Clean prebuild

```bash
npx expo prebuild -p android --clean
```

---

## API Reference

### `HeartRateMonitor`

```typescript
import { HeartRateMonitor } from 'react-native-heart-rate';
```

#### `startMonitoring(config?: WorkoutConfig): void`

Starts heart rate monitoring. Sends a start command to the paired watch/wearable. On simulator/emulator, starts generating simulated heart rate data (~72 BPM baseline with variance).

```typescript
HeartRateMonitor.startMonitoring({
  activityType: 'traditionalStrengthTraining',
  workoutName: 'Push Day',
});
```

#### `stopMonitoring(): void`

Stops heart rate monitoring and ends the workout session on the watch.

#### `isWatchConnected(): Promise<boolean>`

Returns whether a watch/wearable is currently connected and reachable.

#### `getHeartRateZones(): Promise<HeartRateZone[]>`

Returns the 5 heart rate zones calculated from the user's max HR (derived from HealthKit date of birth on iOS, default 190 on Android).

#### `addHeartRateListener(callback): EventSubscription`

Subscribes to real-time heart rate updates (~1 per second).

```typescript
const subscription = HeartRateMonitor.addHeartRateListener((data) => {
  console.log(data.bpm);              // 142
  console.log(data.zone.currentZone); // { name: 'Cardio', min: 70, max: 80, color: '#FFCC00' }
  console.log(data.zone.percentOfMax); // 74.7
  console.log(data.source);           // 'watchOS' or 'wearOS'
});

// Later:
subscription.remove();
```

#### `addConnectionListener(callback): EventSubscription`

Subscribes to watch connection status changes.

```typescript
const subscription = HeartRateMonitor.addConnectionListener((status) => {
  console.log(status.isConnected); // true
  console.log(status.watchName);   // 'Apple Watch'
});
```

#### `addErrorListener(callback): EventSubscription`

Subscribes to error events.

```typescript
const subscription = HeartRateMonitor.addErrorListener((error) => {
  console.log(error.message); // 'Watch is not reachable'
  console.log(error.code);    // 'WATCH_NOT_REACHABLE'
});
```

### Types

```typescript
type WorkoutConfig = {
  activityType?: string;  // See supported types below
  workoutName?: string;   // Custom label for the workout
};

type HeartRateData = {
  bpm: number;
  timestamp: number;
  source: 'watchOS' | 'wearOS';
  accuracy?: 'low' | 'medium' | 'high';
  zone: HeartRateZoneStatus;
};

type HeartRateZoneStatus = {
  currentZone: HeartRateZone;
  zones: HeartRateZone[];
  percentOfMax: number;
};

type HeartRateZone = {
  name: string;
  min: number;
  max: number;
  color: string;
};

type ConnectionStatus = {
  isConnected: boolean;
  watchName?: string;
};
```

### Supported Activity Types

The `activityType` string is mapped to native workout types on each platform:

| activityType | Apple HealthKit | Wear OS Health Services |
|---|---|---|
| `traditionalStrengthTraining` | `.traditionalStrengthTraining` | `STRENGTH_TRAINING` |
| `functionalStrengthTraining` | `.functionalStrengthTraining` | `STRENGTH_TRAINING` |
| `running` | `.running` | `RUNNING` |
| `cycling` | `.cycling` | `BIKING` |
| `walking` | `.walking` | `WALKING` |
| `hiking` | `.hiking` | `HIKING` |
| `yoga` | `.yoga` | `YOGA` |
| `rowing` | `.rowing` | `ROWING_MACHINE` |
| `swimming` | `.swimming` | `SWIMMING_POOL` |
| `crossTraining` | `.crossTraining` | `WORKOUT` |
| `elliptical` | `.elliptical` | `ELLIPTICAL` |
| `stairClimbing` | `.stairClimbing` | `STAIR_CLIMBING` |
| `pilates` | `.pilates` | `PILATES` |
| `dance` | `.dance` | `DANCING` |
| `coreTraining` | `.coreTraining` | `WORKOUT` |
| `flexibility` | `.flexibility` | `STRETCHING` |
| `highIntensityIntervalTraining` | `.highIntensityIntervalTraining` | `HIGH_INTENSITY_INTERVAL_TRAINING` |
| `jumpRope` | `.jumpRope` | `JUMP_ROPE` |
| `kickboxing` | `.kickboxing` | `KICKBOXING` |
| `mixedCardio` | `.mixedCardio` | `WORKOUT` |

If unrecognized or omitted, defaults to `.other` (iOS) / `WORKOUT` (Android).

## Simulator / Emulator

On iOS Simulator and Android Emulator, the module automatically generates simulated heart rate data:

- Baseline: ~72 BPM
- Variance: -3 to +5 BPM per second
- Range: 55-185 BPM
- `isWatchConnected()` returns `true`

No physical watch is needed for development.

## Example Usage

```typescript
import { useEffect, useState } from 'react';
import { HeartRateMonitor, HeartRateData, HeartRateZone } from 'react-native-heart-rate';

export default function App() {
  const [bpm, setBpm] = useState<number | null>(null);
  const [zone, setZone] = useState<HeartRateZone | null>(null);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    HeartRateMonitor.isWatchConnected().then(setConnected);

    const hrSub = HeartRateMonitor.addHeartRateListener((data) => {
      setBpm(data.bpm);
      setZone(data.zone.currentZone);
    });

    const connSub = HeartRateMonitor.addConnectionListener((status) => {
      setConnected(status.isConnected);
    });

    return () => {
      hrSub.remove();
      connSub.remove();
    };
  }, []);

  const toggle = () => {
    if (bpm !== null) {
      HeartRateMonitor.stopMonitoring();
      setBpm(null);
    } else {
      HeartRateMonitor.startMonitoring({
        activityType: 'traditionalStrengthTraining',
        workoutName: 'My Workout',
      });
    }
  };

  return (
    // Your UI here
    // bpm, zone.name, zone.color, connected
  );
}
```

## Known Issues

- **bun symlinks**: When installing as a local file dependency with bun (`bun add ../react-native-heart-rate`), bun creates per-file symlinks in `node_modules` that Expo's autolinking cannot follow. Workaround: after `bun add`, replace the symlinked directory with a real copy:
  ```bash
  rm -rf node_modules/react-native-heart-rate
  cp -R ../react-native-heart-rate node_modules/react-native-heart-rate
  rm -rf node_modules/react-native-heart-rate/node_modules node_modules/react-native-heart-rate/.git
  ```

## License

MIT
