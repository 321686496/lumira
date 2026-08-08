export interface RedeemCodeRequest {
  code: string;
}

export interface RewardTemplateInfo {
  templateId: string;
  templateName: string;
}

export interface RedeemCodeResponse {
  batchId: number;
  campaignName: string;
  rewardPoints: number;
  balance: number;
  rewardTemplates: RewardTemplateInfo[];
}

export interface RedemptionCodeBatch {
  batchId: number;
  campaignName: string;
  rewardPoints: number;
  rewardTemplates: string;
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