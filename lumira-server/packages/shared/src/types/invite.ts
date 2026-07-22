export interface GenerateInviteResponse {
  inviteCode: string;
}

export interface ActivateInviteRequest {
  inviteCode: string;
  channel?: 'direct' | 'share_card' | 'qrcode';
}

export interface ActivateInviteResponse {
  inviterDeviceId: string;
  tierReached: number | null;
  rewards: { tier: number; items: RewardItem[] } | null;
}

export interface InviteStatsResponse {
  totalInvites: number;
  currentTier: number;
  nextTier: { tier: number; requiredInvites: number; rewards: RewardItem[] } | null;
  unlockedRewards: UnlockedReward[];
}

export interface InviteRecord {
  id: number;
  inviterDeviceId: string;
  inviteeDeviceId: string;
  inviteCode: string;
  channel: string;
  activatedAt: number;
  inviterIp: string | null;
  inviteeIp: string | null;
}

// 引用 rewards.ts 中的类型
import { RewardItem, UnlockedReward } from './rewards';
