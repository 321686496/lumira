// lumira-server/packages/backend/src/modules/device/device.service.ts

import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from '../profile/profile-constants';

@Injectable()
export class DeviceService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly jwtService: JwtService,
  ) {}

  async registerDevice(deviceId: string, alias: string | undefined, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 查询是否已存在
    const existing = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    if (existing) {
      // 更新最后活跃时间
      await db.update(devices)
        .set({ lastSeenAt: now })
        .where(eq(devices.deviceId, deviceId));

      const token = this.jwtService.sign({ deviceId });
      const profile = await this.getOrCreateProfile(deviceId);
      return { token, isNewDevice: false, profile };
    }

    // 新设备注册
    await db.insert(devices).values({
      deviceId,
      alias: alias || null,
      firstSeenAt: now,
      lastSeenAt: now,
      ipRegion: ip,
    });

    const token = this.jwtService.sign({ deviceId });
    const profile = await this.getOrCreateProfile(deviceId);
    return { token, isNewDevice: true, profile };
  }

  private async getOrCreateProfile(deviceId: string) {
    const db = this.dbService.getDb();
    const existing = await db.query.userProfiles.findFirst({ where: eq(userProfiles.deviceId, deviceId) });
    if (existing) return { username: existing.username, avatarSeed: existing.avatarSeed };
    const username = randomPick(BUILTIN_USERNAMES);
    const avatarSeed = randomPick(BUILTIN_AVATAR_SEEDS);
    await db.insert(userProfiles).values({
      deviceId, username, avatarSeed, updatedAt: Math.floor(Date.now() / 1000),
    });
    return { username, avatarSeed };
  }
}
