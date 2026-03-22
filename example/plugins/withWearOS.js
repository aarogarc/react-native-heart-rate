const {
  withSettingsGradle,
  withAppBuildGradle,
  withDangerousMod,
} = require("expo/config-plugins");
const fs = require("fs");
const path = require("path");

/**
 * Expo Config Plugin that adds the WearOS companion app module
 * to the Android project during prebuild.
 *
 * - Adds ':wearos' to settings.gradle pointing to ../wearos
 * - Adds a Gradle task dependency so building the phone app also builds the WearOS APK
 * - Copies the app icon into WearOS resources
 */
function withWearOS(config) {
  // Add ':wearos' to settings.gradle
  config = withSettingsGradle(config, (config) => {
    if (!config.modResults.contents.includes("include ':wearos'")) {
      config.modResults.contents = config.modResults.contents.replace(
        "include ':app'",
        "include ':app'\ninclude ':wearos'\nproject(':wearos').projectDir = new File(rootProject.projectDir, '../wearos')"
      );
    }
    return config;
  });

  // Add task dependency so :app build also triggers :wearos build
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

  // Copy app icon into WearOS mipmap resources
  config = withDangerousMod(config, [
    "android",
    (config) => {
      const wearosResDir = path.join(
        config.modRequest.projectRoot,
        "wearos",
        "src",
        "main",
        "res"
      );

      // Use the main app icon as the WearOS icon source
      const iconSource = path.join(
        config.modRequest.projectRoot,
        "assets",
        "icon.png"
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
