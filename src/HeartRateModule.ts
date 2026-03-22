import { NativeModule, requireNativeModule } from 'expo';

import { HeartRateModuleEvents, HeartRateZone } from './HeartRate.types';

declare class HeartRateModule extends NativeModule<HeartRateModuleEvents> {
  startMonitoring(): void;
  stopMonitoring(): void;
  isWatchConnected(): Promise<boolean>;
  getHeartRateZones(): Promise<HeartRateZone[]>;
}

export default requireNativeModule<HeartRateModule>('HeartRate');
