// lumira-server/packages/backend/src/modules/rewards/rewards.service.ts

import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { rewardUnlocks, rewardTiers } from '../../database/schema';

@Injectable()
export class RewardsService {
  constructor(private readonly dbService: DatabaseService) {}

  async listRewards(deviceId: string) {
    const db = this.dbService.getDb();

    const unlocks = await db.query.rewardUnlocks.findMany({
      where: eq(rewardUnlocks.deviceId, deviceId),
    });

    const tiers = await db.query.rewardTiers.findMany();

    const rewards = unlocks.map((unlock) => {
      const tier = tiers.find((t) => t.tier === unlock.tier);
      return {
        id: unlock.id,
        tier: unlock.tier,
        source: unlock.source,
        sourceDetail: unlock.sourceDetail,
        status: unlock.status,
        rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
        unlockedAt: unlock.unlockedAt,
        claimedAt: unlock.claimedAt,
      };
    });

    return { rewards };
  }

  async claimReward(deviceId: string, rewardId: number) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const reward = await db.query.rewardUnlocks.findFirst({
      where: eq(rewardUnlocks.id, rewardId),
    });

    if (!reward) {
      throw new NotFoundException('Reward not found');
    }

    if (reward.deviceId !== deviceId) {
      throw new NotFoundException('Reward not found');
    }

    if (reward.status === 'claimed') {
      throw new ConflictException('Reward already claimed');
    }

    await db.update(rewardUnlocks)
      .set({ status: 'claimed', claimedAt: now })
      .where(eq(rewardUnlocks.id, rewardId));

    return { success: true };
  }
}
