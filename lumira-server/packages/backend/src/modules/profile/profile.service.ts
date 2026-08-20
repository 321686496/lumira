// lumira-server/packages/backend/src/modules/profile/profile.service.ts
import * as fs from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from './profile-constants';
import { UpdateProfileDto } from './dto/update-profile.dto';

export interface ProfileView {
  username: string;
  avatarSeed: string;
  gender: string | null;
  favoriteCategories: string[];
  painPoints: string[];
  skillLevel: string | null;
  expectations: string[];
  commonScenes: string[];
  shootFrequency: string | null;
  avatarUrl: string | null;
  updatedAt: number;
}

function parseArr(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

function toProfileView(row: typeof userProfiles.$inferSelect): ProfileView {
  return {
    username: row.username,
    avatarSeed: row.avatarSeed,
    gender: row.gender,
    favoriteCategories: parseArr(row.favoriteCategoriesJson),
    painPoints: parseArr(row.painPointsJson),
    skillLevel: row.skillLevel,
    expectations: parseArr(row.expectationsJson),
    commonScenes: parseArr(row.commonScenesJson),
    shootFrequency: row.shootFrequency,
    avatarUrl: row.avatarUrl,
    updatedAt: row.updatedAt,
  };
}

@Injectable()
export class ProfileService {
  constructor(private readonly dbService: DatabaseService) {}

  async getOrCreateProfile(deviceId: string): Promise<ProfileView> {
    const db = this.dbService.getDb();
    const existing = await db.query.userProfiles.findFirst({ where: eq(userProfiles.deviceId, deviceId) });
    if (existing) return toProfileView(existing);

    const now = Math.floor(Date.now() / 1000);
    await db.insert(userProfiles).values({
      deviceId,
      username: randomPick(BUILTIN_USERNAMES),
      avatarSeed: randomPick(BUILTIN_AVATAR_SEEDS),
      updatedAt: now,
    });
    return this.getOrCreateProfile(deviceId);
  }

  async updateProfile(deviceId: string, dto: UpdateProfileDto): Promise<ProfileView> {
    const db = this.dbService.getDb();
    await this.getOrCreateProfile(deviceId);
    const now = Math.floor(Date.now() / 1000);
    const fields: Partial<typeof userProfiles.$inferInsert> = { updatedAt: now };
    if (dto.username !== undefined) fields.username = dto.username;
    if (dto.avatarSeed !== undefined) fields.avatarSeed = dto.avatarSeed;
    if (dto.gender !== undefined) fields.gender = dto.gender;
    if (dto.skillLevel !== undefined) fields.skillLevel = dto.skillLevel;
    if (dto.shootFrequency !== undefined) fields.shootFrequency = dto.shootFrequency;
    if (dto.avatarUrl !== undefined) fields.avatarUrl = dto.avatarUrl;
    if (dto.favoriteCategories !== undefined) fields.favoriteCategoriesJson = JSON.stringify(dto.favoriteCategories);
    if (dto.painPoints !== undefined) fields.painPointsJson = JSON.stringify(dto.painPoints);
    if (dto.expectations !== undefined) fields.expectationsJson = JSON.stringify(dto.expectations);
    if (dto.commonScenes !== undefined) fields.commonScenesJson = JSON.stringify(dto.commonScenes);
    await db.update(userProfiles).set(fields).where(eq(userProfiles.deviceId, deviceId));
    return this.getOrCreateProfile(deviceId);
  }

  /** 问卷提交时同步 6 项偏好 + 性别到 user_profiles（只写偏好字段，不覆盖 username/avatar）。 */
  async mergeQuestionnairePrefs(deviceId: string, prefs: {
    gender?: string | null;
    favorite_categories?: string[];
    pain_points?: string[];
    skill_level?: string | null;
    expectations?: string[];
    common_scenes?: string[];
    shoot_frequency?: string | null;
  }): Promise<void> {
    const db = this.dbService.getDb();
    await this.getOrCreateProfile(deviceId);
    const now = Math.floor(Date.now() / 1000);
    const fields: Partial<typeof userProfiles.$inferInsert> = { updatedAt: now };
    if (prefs.gender !== undefined && prefs.gender !== null) fields.gender = prefs.gender;
    if (prefs.favorite_categories?.length) fields.favoriteCategoriesJson = JSON.stringify(prefs.favorite_categories);
    if (prefs.pain_points?.length) fields.painPointsJson = JSON.stringify(prefs.pain_points);
    if (prefs.skill_level !== undefined && prefs.skill_level !== null) fields.skillLevel = prefs.skill_level;
    if (prefs.expectations?.length) fields.expectationsJson = JSON.stringify(prefs.expectations);
    if (prefs.common_scenes?.length) fields.commonScenesJson = JSON.stringify(prefs.common_scenes);
    if (prefs.shoot_frequency !== undefined && prefs.shoot_frequency !== null) fields.shootFrequency = prefs.shoot_frequency;
    if (Object.keys(fields).length > 1) {
      await db.update(userProfiles).set(fields).where(eq(userProfiles.deviceId, deviceId));
    }
  }

  /** 保存自定义头像到 {UPLOAD_DIR}/users/{deviceId}/avatar.{ext}，删除旧文件，写 avatar_url。 */
  async saveAvatar(deviceId: string, buffer: Buffer, ext: string): Promise<{ avatarUrl: string }> {
    await this.getOrCreateProfile(deviceId);
    const uploadDir = process.env.UPLOAD_DIR || path.resolve('./data/uploads');
    const dir = path.join(uploadDir, 'users', deviceId);
    fs.mkdirSync(dir, { recursive: true });

    // 删除旧头像
    const db = this.dbService.getDb();
    const oldRow = await db
      .select({ url: userProfiles.avatarUrl })
      .from(userProfiles)
      .where(eq(userProfiles.deviceId, deviceId))
      .limit(1);
    const oldUrl = oldRow[0]?.url;
    if (oldUrl) {
      const oldName = oldUrl.split('/').pop();
      if (oldName) fs.rmSync(path.join(dir, oldName), { force: true });
    }

    const filename = `avatar.${ext}`;
    fs.writeFileSync(path.join(dir, filename), buffer);

    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    const avatarUrl = `${base}/uploads/users/${deviceId}/${filename}`;
    await this.updateProfile(deviceId, { avatarUrl });
    return { avatarUrl };
  }
}