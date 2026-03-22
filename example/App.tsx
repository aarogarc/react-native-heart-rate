import { useEffect, useState } from 'react';
import { HeartRateMonitor, type HeartRateData, type HeartRateZone } from 'react-native-heart-rate';
import { SafeAreaView, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function App() {
  const [isMonitoring, setIsMonitoring] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [currentHR, setCurrentHR] = useState<HeartRateData | null>(null);
  const [recentReadings, setRecentReadings] = useState<HeartRateData[]>([]);
  const [zones, setZones] = useState<HeartRateZone[]>([]);

  useEffect(() => {
    HeartRateMonitor.getHeartRateZones().then(setZones);
    HeartRateMonitor.isWatchConnected().then(setIsConnected);

    const hrSub = HeartRateMonitor.addHeartRateListener((data) => {
      setCurrentHR(data);
      setRecentReadings((prev) => [data, ...prev].slice(0, 20));
    });

    const connSub = HeartRateMonitor.addConnectionListener((status) => {
      setIsConnected(status.isConnected);
    });

    return () => {
      hrSub.remove();
      connSub.remove();
    };
  }, []);

  const toggleMonitoring = () => {
    if (isMonitoring) {
      HeartRateMonitor.stopMonitoring();
    } else {
      HeartRateMonitor.startMonitoring();
    }
    setIsMonitoring(!isMonitoring);
  };

  const currentZone = currentHR?.zone.currentZone;

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.container}>
        <Text style={styles.header}>Heart Rate Monitor</Text>

        {/* Connection Status */}
        <View style={styles.card}>
          <View style={styles.statusRow}>
            <View style={[styles.statusDot, { backgroundColor: isConnected ? '#22C55E' : '#EF4444' }]} />
            <Text style={styles.statusText}>
              {isConnected ? 'Watch Connected' : 'Watch Disconnected'}
            </Text>
          </View>
        </View>

        {/* BPM Display */}
        <View style={[styles.card, styles.bpmCard, { borderColor: currentZone?.color ?? '#94A3B8' }]}>
          <Text style={[styles.bpmValue, { color: currentZone?.color ?? '#000' }]}>
            {currentHR?.bpm ?? '--'}
          </Text>
          <Text style={styles.bpmLabel}>BPM</Text>
          {currentZone && (
            <Text style={[styles.zoneName, { color: currentZone.color }]}>
              {currentZone.name}
            </Text>
          )}
        </View>

        {/* Zone Bar */}
        {zones.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Heart Rate Zones</Text>
            <View style={styles.zoneBar}>
              {zones.map((zone) => (
                <View
                  key={zone.name}
                  style={[
                    styles.zoneSegment,
                    {
                      backgroundColor: zone.color,
                      opacity: currentZone?.name === zone.name ? 1 : 0.3,
                      flex: zone.max - zone.min,
                    },
                  ]}
                >
                  <Text style={styles.zoneSegmentText}>{zone.max}%</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* Start/Stop Button */}
        <TouchableOpacity
          style={[styles.button, { backgroundColor: isMonitoring ? '#EF4444' : '#22C55E' }]}
          onPress={toggleMonitoring}
        >
          <Text style={styles.buttonText}>
            {isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'}
          </Text>
        </TouchableOpacity>

        {/* Recent Readings */}
        {recentReadings.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Recent Readings</Text>
            {recentReadings.map((reading, i) => (
              <View key={i} style={styles.readingRow}>
                <Text style={[styles.readingBpm, { color: reading.zone.currentZone.color }]}>
                  {reading.bpm} BPM
                </Text>
                <Text style={styles.readingTime}>
                  {new Date(reading.timestamp).toLocaleTimeString()}
                </Text>
                <Text style={styles.readingSource}>{reading.source}</Text>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#111',
  },
  header: {
    fontSize: 28,
    fontWeight: '700',
    color: '#fff',
    margin: 20,
  },
  card: {
    marginHorizontal: 20,
    marginBottom: 16,
    backgroundColor: '#1C1C1E',
    borderRadius: 16,
    padding: 20,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#8E8E93',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 12,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 10,
  },
  statusText: {
    fontSize: 16,
    color: '#fff',
  },
  bpmCard: {
    alignItems: 'center',
    borderWidth: 2,
  },
  bpmValue: {
    fontSize: 80,
    fontWeight: '200',
    fontVariant: ['tabular-nums'],
  },
  bpmLabel: {
    fontSize: 18,
    color: '#8E8E93',
    marginTop: -8,
  },
  zoneName: {
    fontSize: 16,
    fontWeight: '600',
    marginTop: 12,
  },
  zoneBar: {
    flexDirection: 'row',
    height: 32,
    borderRadius: 8,
    overflow: 'hidden',
  },
  zoneSegment: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  zoneSegmentText: {
    fontSize: 10,
    fontWeight: '600',
    color: '#fff',
  },
  button: {
    marginHorizontal: 20,
    marginBottom: 16,
    borderRadius: 16,
    padding: 18,
    alignItems: 'center',
  },
  buttonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  readingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#2C2C2E',
  },
  readingBpm: {
    fontSize: 16,
    fontWeight: '600',
    width: 80,
  },
  readingTime: {
    fontSize: 14,
    color: '#8E8E93',
    flex: 1,
    textAlign: 'center',
  },
  readingSource: {
    fontSize: 12,
    color: '#636366',
    width: 60,
    textAlign: 'right',
  },
});
