// lumira-server/packages/backend/src/modules/notifications/notifications.service.ts

import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { notifications, devices } from '../../database/schema';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { UpdateNotificationDto } from './dto/update-notification.dto';

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

  // ===== 后台 Admin CRUD =====

  /** 后台：返回全部通知（原始 drizzle 行，排序 sortOrder asc, createdAt） */
  async listAdmin() {
    const db = this.dbService.getDb();
    const rows = await db.select()
      .from(notifications)
      .orderBy(asc(notifications.sortOrder), notifications.createdAt);
    return rows;
  }

  async create(dto: CreateNotificationDto) {
    const db = this.dbService.getDb();
    const id = dto.id || `ntf-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    if (dto.id) {
      const existing = await db.select().from(notifications).where(eq(notifications.id, id)).limit(1);
      if (existing.length > 0) throw new ConflictException(`Notification id already exists: ${id}`);
    }
    const now = Date.now();
    const row = {
      id,
      title: dto.title,
      body: dto.body,
      iconKey: dto.iconKey ?? 'announcement',
      category: dto.category ?? 'announcement',
      targetScope: dto.targetScope ?? 'all',
      targetDeviceIdsJson: dto.targetDeviceIdsJson ?? '[]',
      targetCriteriaJson: dto.targetCriteriaJson ?? '{}',
      startAt: dto.startAt ?? null,
      endAt: dto.endAt ?? null,
      isActive: dto.isActive === false ? 0 : 1,
      sortOrder: dto.sortOrder ?? 0,
      createdAt: now,
      updatedAt: now,
    };
    await db.insert(notifications).values(row);
    return (await this.getById(id))!;
  }

  async update(id: string, dto: UpdateNotificationDto) {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    const patch: Record<string, unknown> = { updatedAt: Date.now() };
    if (dto.title !== undefined) patch.title = dto.title;
    if (dto.body !== undefined) patch.body = dto.body;
    if (dto.iconKey !== undefined) patch.iconKey = dto.iconKey;
    if (dto.category !== undefined) patch.category = dto.category;
    if (dto.targetScope !== undefined) patch.targetScope = dto.targetScope;
    if (dto.targetDeviceIdsJson !== undefined) patch.targetDeviceIdsJson = dto.targetDeviceIdsJson;
    if (dto.targetCriteriaJson !== undefined) patch.targetCriteriaJson = dto.targetCriteriaJson;
    if (dto.startAt !== undefined) patch.startAt = dto.startAt;
    if (dto.endAt !== undefined) patch.endAt = dto.endAt;
    if (dto.isActive !== undefined) patch.isActive = dto.isActive ? 1 : 0;
    if (dto.sortOrder !== undefined) patch.sortOrder = dto.sortOrder;
    await db.update(notifications).set(patch).where(eq(notifications.id, id));
    return (await this.getById(id))!;
  }

  async remove(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    await db.delete(notifications).where(eq(notifications.id, id));
    return { success: true };
  }

  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const n = await this.requireExists(id);
    const next = n.isActive ? 0 : 1;
    await db.update(notifications)
      .set({ isActive: next, updatedAt: Date.now() })
      .where(eq(notifications.id, id));
    return { id, isActive: next === 1 };
  }

  private async getById(id: string) {
    const db = this.dbService.getDb();
    const rows = await db.select().from(notifications).where(eq(notifications.id, id)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }
  private async requireExists(id: string) {
    const n = await this.getById(id);
    if (!n) throw new NotFoundException(`Notification not found: ${id}`);
    return n;
  }
}