// lumira-server/packages/backend/src/modules/profile/profile.service.ts

import { Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from './profile-constants';

@Injectable()
export class ProfileService {
  constructor(private readonly dbService: DatabaseService) {}

  async getOrCreateProfile(deviceId: string) {
    const db = this.dbService.getDb();
    const existing = await db.query.userProfiles.findFirst({ where: eq(userProfiles.deviceId, deviceId) });
    if (existing) return { username: existing.username, avatarSeed: existing.avatarSeed };
    const username = randomPick(BUILTIN_USERNAMES);
    const avatarSeed = randomPick(BUILTIN_AVATAR_SEEDS);
    await db.insert(userProfiles).values({ deviceId, username, avatarSeed, updatedAt: Math.floor(Date.now() / 1000) });
    return { username, avatarSeed };
  }

  async updateProfile(deviceId: string, patch: { username?: string; avatarSeed?: string }) {
    const db = this.dbService.getDb();
    await this.getOrCreateProfile(deviceId);
    const rows = await db.select().from(userProfiles).where(eq(userProfiles.deviceId, deviceId));
    const updated = {
      username: patch.username ?? rows[0].username,
      avatarSeed: patch.avatarSeed ?? rows[0].avatarSeed,
      updatedAt: Math.floor(Date.now() / 1000),
    };
    await db.update(userProfiles).set(updated).where(eq(userProfiles.deviceId, deviceId));
    return { username: updated.username, avatarSeed: updated.avatarSeed };
  }
}
