export type HeartRateZone = {
  name: string;
  min: number;
  max: number;
  color: string;
};

export type HeartRateZoneStatus = {
  currentZone: HeartRateZone;
  zones: HeartRateZone[];
  percentOfMax: number;
};

export type HeartRateData = {
  bpm: number;
  timestamp: number;
  source: 'watchOS' | 'wearOS';
  accuracy?: 'low' | 'medium' | 'high';
  zone: HeartRateZoneStatus;
};

export type ActiveEnergyData = {
  kcal: number;
  timestamp: number;
  source: 'watchOS' | 'wearOS';
};

export type ConnectionStatus = {
  isConnected: boolean;
  watchName?: string;
};

export type WorkoutConfig = {
  activityType?: string;
  workoutName?: string;
};

export type HeartRateModuleEvents = {
  heartRateUpdate: (data: HeartRateData) => void;
  activeEnergyUpdate: (data: ActiveEnergyData) => void;
  connectionChange: (status: ConnectionStatus) => void;
  error: (error: { message: string; code: string }) => void;
};
