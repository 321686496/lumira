export interface RedeemCodeRequest {
  code: string;
}

export interface RedeemCodeResponse {
  batchId: number;
  campaignName: string;
  rewardTier: number;
  rewardItems: RewardItem[];
}

export interface RedemptionCodeBatch {
  batchId: number;
  campaignName: string;
  rewardTier: number;
  maxUsesPerCode: number;
  totalGenerated: number;
  totalUsed: number;
  validFrom: number | null;
  validUntil: number | null;
  isActive: boolean;
  createdAt: number;
}

export interface RedemptionRecord {
  id: number;
  code: string;
  deviceId: string;
  redeemedAt: number;
  ipAddress: string | null;
}

import { RewardItem } from './rewards';
