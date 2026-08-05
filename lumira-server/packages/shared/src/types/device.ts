export interface RegisterDeviceRequest {
  deviceId: string;
}

export interface UserProfile {
  username: string;
  avatarSeed: string;
}

export interface RegisterDeviceResponse {
  token: string;
  isNewDevice: boolean;
  profile: UserProfile;
}

export interface DeviceRecord {
  deviceId: string;
  alias: string | null;
  firstSeenAt: number;
  lastSeenAt: number;
  ipRegion: string | null;
}
