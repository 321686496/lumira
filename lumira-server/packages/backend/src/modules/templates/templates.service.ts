// lumira-server/packages/backend/src/modules/templates/templates.service.ts

import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { ownedTemplates, templatePrices } from '../../database/schema';
import { PointsService } from '../points/points.service';

@Injectable()
export class TemplatesService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
  ) {}

  /** 查询设备已拥有的模板 id 列表 */
  async listOwned(deviceId: string) {
    const db = this.dbService.getDb();
    const rows = await db.query.ownedTemplates.findMany({
      where: eq(ownedTemplates.deviceId, deviceId),
      orderBy: (t, { desc }) => [desc(t.unlockedAt)],
    });
    return {
      templateIds: rows.map((r) => r.templateId),
      records: rows.map((r) => ({
        id: r.id,
        templateId: r.templateId,
        source: r.source as 'redemption' | 'points' | 'invite' | 'admin_grant',
        sourceDetail: r.sourceDetail,
        unlockedAt: r.unlockedAt,
      })),
    };
  }

  /** 查询所有模板积分定价 */
  async listPrices() {
    const db = this.dbService.getDb();
    const rows = await db.query.templatePrices.findMany({
      where: eq(templatePrices.isActive, 1),
    });
    return {
      prices: rows.map((r) => ({
        templateId: r.templateId,
        priceCredits: r.priceCredits,
        isActive: r.isActive === 1,
      })),
    };
  }

  /** 积分兑换模板 */
  async exchange(deviceId: string, templateId: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查定价
    const price = await db.query.templatePrices.findFirst({
      where: and(
        eq(templatePrices.templateId, templateId),
        eq(templatePrices.isActive, 1),
      ),
    });
    if (!price) {
      throw new NotFoundException('Template not available for exchange');
    }

    // 2. 检查是否已拥有（幂等：已拥有则直接返回成功）
    const existing = await db.query.ownedTemplates.findFirst({
      where: and(
        eq(ownedTemplates.deviceId, deviceId),
        eq(ownedTemplates.templateId, templateId),
      ),
    });
    if (existing) {
      throw new ConflictException('Template already owned');
    }

    // 3. 扣积分（余额不足会抛 BadRequestException）
    const newBalance = await this.pointsService.spendPoints(
      deviceId,
      price.priceCredits,
      'exchange_template',
      templateId,
    );

    // 4. 写入拥有记录
    await db.insert(ownedTemplates).values({
      deviceId,
      templateId,
      source: 'points',
      sourceDetail: `credits:${price.priceCredits}`,
      unlockedAt: now,
    }).run();

    return {
      success: true,
      templateId,
      spentCredits: price.priceCredits,
      balance: newBalance,
    };
  }

  /**
   * 内部方法：直接授予模板拥有权（供兑换码/邀请奖励调用，不扣积分）
   * 幂等：已拥有则跳过
   */
  async grantTemplate(
    deviceId: string,
    templateId: string,
    source: 'redemption' | 'invite' | 'admin_grant',
    sourceDetail: string | null = null,
  ): Promise<boolean> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 幂等检查
    const existing = await db.query.ownedTemplates.findFirst({
      where: and(
        eq(ownedTemplates.deviceId, deviceId),
        eq(ownedTemplates.templateId, templateId),
      ),
    });
    if (existing) {
      return false; // 已拥有，未实际写入
    }

    await db.insert(ownedTemplates).values({
      deviceId,
      templateId,
      source,
      sourceDetail,
      unlockedAt: now,
    }).run();
    return true;
  }
}
