const { withSettingsGradle, withDangerousMod } = require("expo/config-plugins");
const fs = require("fs");
const path = require("path");

/**
 * Expo Config Plugin that adds the WearOS companion app module
 * to the Android project during prebuild.
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

  return config;
}

module.exports = withWearOS;
