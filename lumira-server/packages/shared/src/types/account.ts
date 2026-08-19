export interface RecoveryQrResponse {
  secret: string;
  qrPayload: string;
  expiresAt: number;
}

export interface RecoverResponse {
  deviceId: string;
}

export interface SendCodeResponse {
  sent: true;
}

export interface BindEmailResponse {
  success: true;
}