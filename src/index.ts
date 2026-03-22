import type { EventSubscription } from 'expo-modules-core';

import HeartRateModule from './HeartRateModule';
import type { HeartRateData, ConnectionStatus } from './HeartRate.types';

export * from './HeartRate.types';

export const HeartRateMonitor = {
  startMonitoring(): void {
    HeartRateModule.startMonitoring();
  },

  stopMonitoring(): void {
    HeartRateModule.stopMonitoring();
  },

  async isWatchConnected(): Promise<boolean> {
    return HeartRateModule.isWatchConnected();
  },

  async getHeartRateZones() {
    return HeartRateModule.getHeartRateZones();
  },

  addHeartRateListener(callback: (data: HeartRateData) => void): EventSubscription {
    return HeartRateModule.addListener('heartRateUpdate', callback);
  },

  addConnectionListener(callback: (status: ConnectionStatus) => void): EventSubscription {
    return HeartRateModule.addListener('connectionChange', callback);
  },

  addErrorListener(callback: (error: { message: string; code: string }) => void): EventSubscription {
    return HeartRateModule.addListener('error', callback);
  },
};

export default HeartRateMonitor;
