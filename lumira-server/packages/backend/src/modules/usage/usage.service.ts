// lumira-server/packages/backend/src/modules/usage/usage.service.ts
import { Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { usageEvents } from '../../database/schema';
import type { EventInputDto } from './dto/batch-events.dto';
import type { UsageStatsResponse, UsageStatsItem, UsageItemType } from '@lumira/shared';

@Injectable()
export class UsageService {
  constructor(private readonly dbService: DatabaseService) {}

  /** 批量上报。用 INSERT ... ON DUPLICATE KEY UPDATE 保证 client_event_id 幂等。 */
  async recordBatch(deviceId: string, events: EventInputDto[]): Promise<{ inserted: number }> {
    if (events.length === 0) return { inserted: 0 };
    const db = this.dbService.getDb();
    // 逐条 ON DUPLICATE（client_event_id 唯一索引），重复上报不重复计数
    for (const e of events) {
      await db.execute(sql`
        INSERT INTO ${usageEvents}
          (${usageEvents.deviceId}, ${usageEvents.clientEventId}, ${usageEvents.itemType},
           ${usageEvents.itemId}, ${usageEvents.itemSource}, ${usageEvents.eventType}, ${usageEvents.occurredAt})
        VALUES (${deviceId}, ${e.clientEventId}, ${e.itemType}, ${e.itemId}, ${e.itemSource}, ${e.eventType}, ${e.occurredAt})
        ON DUPLICATE KEY UPDATE \`client_event_id\` = ${e.clientEventId}
      `);
    }
    return { inserted: events.length };
  }

  /** 全站按 itemType+itemId+eventType 累加汇总。 */
  async stats(itemType?: UsageItemType): Promise<UsageStatsResponse> {
    const db = this.dbService.getDb();
    const rows = await db.execute(sql`
      SELECT item_id AS itemId, item_type AS itemType, event_type AS eventType, COUNT(*) AS cnt
      FROM ${usageEvents}
      WHERE ${itemType ? sql`item_type = ${itemType}` : sql`1=1`}
      GROUP BY item_id, item_type, event_type
    `);
    const summary = new Map<string, UsageStatsItem>();
    for (const r of (rows[0] as unknown as Array<Record<string, unknown>>)) {
      const key = `${String(r.itemType)}:${String(r.itemId)}`;
      const item = summary.get(key) ?? { itemId: String(r.itemId), itemType: String(r.itemType) as UsageItemType, useShoot: 0, openDetail: 0, sceneSelect: 0 };
      const cnt = Number(r.cnt);
      if (r.eventType === 'use_shoot') item.useShoot += cnt;
      else if (r.eventType === 'open_detail') item.openDetail += cnt;
      else if (r.eventType === 'scene_select') item.sceneSelect += cnt;
      summary.set(key, item);
    }
    return { items: [...summary.values()] };
  }
}