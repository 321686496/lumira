export interface RegisterDeviceRequest {
  deviceId: string;
}

export interface RegisterDeviceResponse {
  token: string;
  isNewDevice: boolean;
}

export interface DeviceRecord {
  deviceId: string;
  alias: string | null;
  firstSeenAt: number;
  lastSeenAt: number;
  ipRegion: string | null;
}
