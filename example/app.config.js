const fs = require("fs");
const path = require("path");

// Load .env.local if it exists (gitignored, safe for secrets)
const envPath = path.join(__dirname, ".env.local");
if (fs.existsSync(envPath)) {
  const envFile = fs.readFileSync(envPath, "utf8");
  for (const line of envFile.split("\n")) {
    const [key, ...rest] = line.split("=");
    if (key && rest.length) {
      process.env[key.trim()] = rest.join("=").trim();
    }
  }
}

const appleTeamId = process.env.APPLE_TEAM_ID;

if (!appleTeamId) {
  console.warn(
    "\x1b[33m⚠ APPLE_TEAM_ID not set. Create example/.env.local with:\n  APPLE_TEAM_ID=YOUR_TEAM_ID\n\x1b[0m"
  );
}

module.exports = {
  expo: {
    name: "Heart Rate Example",
    slug: "heart-rate-example",
    version: "1.0.0",
    orientation: "portrait",
    icon: "./assets/icon.png",
    userInterfaceStyle: "dark",
    splash: {
      image: "./assets/splash-icon.png",
      resizeMode: "contain",
      backgroundColor: "#111111",
    },
    ios: {
      supportsTablet: true,
      bundleIdentifier: "expo.modules.heartrate.example",
      ...(appleTeamId && { appleTeamId }),
      infoPlist: {
        NSHealthShareUsageDescription:
          "This app displays heart rate data from your Apple Watch.",
      },
      entitlements: {
        "com.apple.developer.healthkit": true,
      },
    },
    android: {
      adaptiveIcon: {
        backgroundColor: "#E6F4FE",
        foregroundImage: "./assets/android-icon-foreground.png",
        backgroundImage: "./assets/android-icon-background.png",
        monochromeImage: "./assets/android-icon-monochrome.png",
      },
      predictiveBackGestureEnabled: false,
      package: "expo.modules.heartrate.example",
    },
    plugins: ["@bacons/apple-targets", "./plugins/withWearOS"],
  },
};
