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

export type ConnectionStatus = {
  isConnected: boolean;
  watchName?: string;
};

export type HeartRateModuleEvents = {
  heartRateUpdate: (data: HeartRateData) => void;
  connectionChange: (status: ConnectionStatus) => void;
  error: (error: { message: string; code: string }) => void;
};
