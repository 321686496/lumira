// lumira-server/packages/backend/src/modules/device/device.service.ts

import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';
import { ProfileService } from '../profile/profile.service';

@Injectable()
export class DeviceService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly jwtService: JwtService,
    private readonly profileService: ProfileService,
  ) {}

  async registerDevice(
    deviceId: string,
    alias: string | undefined,
    ip: string,
    deviceInfo?: {
      platform?: string;
      osVersion?: string;
      deviceModel?: string;
      appVersion?: string;
    },
  ) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existing = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    if (existing) {
      await db.update(devices)
        .set({
          lastSeenAt: now,
          ...(deviceInfo?.platform && { platform: deviceInfo.platform }),
          ...(deviceInfo?.osVersion && { osVersion: deviceInfo.osVersion }),
          ...(deviceInfo?.deviceModel && { deviceModel: deviceInfo.deviceModel }),
          ...(deviceInfo?.appVersion && { appVersion: deviceInfo.appVersion }),
        })
        .where(eq(devices.deviceId, deviceId));

      const token = this.jwtService.sign({ deviceId });
      const profile = await this.profileService.getOrCreateProfile(deviceId);
      return { token, isNewDevice: false, profile };
    }

    await db.insert(devices).values({
      deviceId,
      alias: alias || null,
      platform: deviceInfo?.platform || null,
      osVersion: deviceInfo?.osVersion || null,
      deviceModel: deviceInfo?.deviceModel || null,
      appVersion: deviceInfo?.appVersion || null,
      firstSeenAt: now,
      lastSeenAt: now,
      ipRegion: ip,
    });

    const token = this.jwtService.sign({ deviceId });
    const profile = await this.profileService.getOrCreateProfile(deviceId);
    return { token, isNewDevice: true, profile };
  }
}
