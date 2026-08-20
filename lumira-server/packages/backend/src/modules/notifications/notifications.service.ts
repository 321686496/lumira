// lumira-server/packages/backend/src/modules/notifications/notifications.service.ts

import { Injectable } from '@nestjs/common';
import { and, eq, gte, lte, asc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { notifications, devices } from '../../database/schema';

@Injectable()
export class NotificationsService {
  constructor(private readonly dbService: DatabaseService) {}

  async listForDevice(deviceId: string) {
    const db = this.dbService.getDb();
    const now = Date.now();
    const rows = await db.select()
      .from(notifications)
      .where(eq(notifications.isActive, 1))
      .orderBy(asc(notifications.sortOrder), notifications.createdAt);
    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    const list = rows
      .filter((n) => {
        if (n.startAt && now < n.startAt) return false;
        if (n.endAt && now > n.endAt) return false;
        return this.matches(n, device);
      })
      .map((n) => ({
        id: n.id,
        title: n.title,
        body: n.body,
        iconKey: n.iconKey,
        category: n.category,
        startAt: n.startAt ?? null,
        endAt: n.endAt ?? null,
      }));
    return { notifications: list };
  }

  /** 定向匹配：scope=all 恒真；devices 按 id；criteria 按设备字段 + 通配 */
  private matches(n: typeof notifications.$inferSelect, device: typeof devices.$inferSelect | undefined) {
    if (n.targetScope === 'all') return true;
    if (n.targetScope === 'devices') {
      const ids: string[] = JSON.parse(n.targetDeviceIdsJson || '[]');
      const devId = device ? device.deviceId : undefined;
      return Boolean(device && devId && ids.includes(devId));
    }
    // criteria
    const c = JSON.parse(n.targetCriteriaJson || '{}') as Record<string, string[] | undefined>;
    const hit = (field: 'platform' | 'deviceModel' | 'osVersion' | 'appVersion' | 'email', key: string): boolean => {
      const list = c[key];
      if (!list || list.length === 0) return true;
      const value = device ? device[field] : null;
      return list.some((rule) => rule === '*' || (value != null && value === rule));
    };
    if (!hit('platform', 'platform')) return false;
    if (!hit('deviceModel', 'deviceModel')) return false;
    if (!hit('osVersion', 'osVersion')) return false;
    if (!hit('appVersion', 'appVersion')) return false;
    if (!hit('email', 'email')) return false;
    return true;
  }
}