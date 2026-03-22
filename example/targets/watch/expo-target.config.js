/** @type {import('@bacons/apple-targets').Config} */
module.exports = {
  type: "watch",
  name: "HeartRateWatch",
  displayName: "Heart Rate",
  deploymentTarget: "10.0",
  frameworks: ["HealthKit", "WatchConnectivity"],
  entitlements: {
    "com.apple.developer.healthkit": true,
    "com.apple.developer.healthkit.access": ["health-records"],
  },
};
