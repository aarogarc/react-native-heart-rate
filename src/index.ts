import type { EventSubscription } from 'expo-modules-core';

import HeartRateModule from './HeartRateModule';
import type { ActiveEnergyData, HeartRateData, ConnectionStatus, WorkoutConfig } from './HeartRate.types';

export * from './HeartRate.types';

export const HeartRateMonitor = {
  startMonitoring(config?: WorkoutConfig): void {
    HeartRateModule.startMonitoring(config ? { ...config } : undefined);
  },

  stopMonitoring(): void {
    HeartRateModule.stopMonitoring();
  },

  pauseMonitoring(): void {
    HeartRateModule.pauseMonitoring();
  },

  resumeMonitoring(): void {
    HeartRateModule.resumeMonitoring();
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

  addActiveEnergyListener(callback: (data: ActiveEnergyData) => void): EventSubscription {
    return HeartRateModule.addListener('activeEnergyUpdate', callback);
  },

  addConnectionListener(callback: (status: ConnectionStatus) => void): EventSubscription {
    return HeartRateModule.addListener('connectionChange', callback);
  },

  addErrorListener(callback: (error: { message: string; code: string }) => void): EventSubscription {
    return HeartRateModule.addListener('error', callback);
  },
};

export default HeartRateMonitor;
