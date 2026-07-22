export interface RewardItem {
  type: 'template' | 'template_pack' | 'achievement';
  id: string;
  label: string;
}

export interface RewardTier {
  tier: number;
  requiredInvites: number;
  rewards: RewardItem[];
  isActive: boolean;
}

export interface UnlockedReward {
  id: number;
  tier: number;
  source: 'invite' | 'redemption';
  sourceDetail: string | null;
  status: 'unlocked' | 'claimed';
  rewardItems: RewardItem[];
  unlockedAt: number;
  claimedAt: number | null;
}

export interface RewardsListResponse {
  rewards: UnlockedReward[];
}

export interface ClaimRewardResponse {
  success: boolean;
}
