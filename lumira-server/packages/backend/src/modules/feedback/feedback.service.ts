// lumira-server/packages/backend/src/modules/feedback/feedback.service.ts
import { Injectable, BadRequestException } from '@nestjs/common';
import { eq, and, desc, sql } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from '../../database/database.service';
import { feedbacks } from '../../database/schema';
import { CreateFeedbackDto } from './dto/create-feedback.dto';
import type { FeedbackUploadFile } from './feedback.controller';

export interface AdminFeedbackItem {
  id: string;
  deviceId: string;
  type: string;
  content: string;
  contact: string | null;
  status: string;
  screenshots: string[];
  createdAt: number;
  clientIp: string | null;
}

const MAX_SCREENSHOT_BYTES = 10 * 1024 * 1024; // 10MB / 张

function buildPublicUrl(id: string, filename: string): string {
  const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
  return `${base}/uploads/feedback/${id}/${filename}`;
}

function extractExt(file: FeedbackUploadFile): string {
  if (file.filename) {
    const dot = file.filename.lastIndexOf('.');
    if (dot >= 0) {
      const ext = file.filename.slice(dot + 1).toLowerCase();
      if (/^[a-z0-9]+$/.test(ext)) return ext;
    }
  }
  const mimeMap: Record<string, string> = {
    'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png',
    'image/webp': 'webp', 'image/gif': 'gif',
  };
  return mimeMap[file.mimetype] || 'jpg';
}

@Injectable()
export class FeedbackService {
  private readonly uploadDir: string;

  constructor(private readonly dbService: DatabaseService) {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
  }

  async submit(
    deviceId: string,
    dto: CreateFeedbackDto,
    files: FeedbackUploadFile[],
    ip: string,
  ): Promise<{ success: true; id: string; receivedAt: number }> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const id = `fb_${nanoid(12)}`;

    for (const f of files) {
      if (f.buffer.byteLength > MAX_SCREENSHOT_BYTES) {
        throw new BadRequestException('单张截图不能超过 10MB');
      }
    }

    // 保存截图（原子性：任一失败则整体失败，不留孤儿）
    const screenshots: string[] = [];
    files.forEach((file, i) => {
      const ext = extractExt(file);
      const filename = `shot-${i}.${ext}`;
      const dir = path.join(this.uploadDir, 'feedback', id);
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, filename), file.buffer);
      screenshots.push(buildPublicUrl(id, filename));
    });

    await db.insert(feedbacks).values({
      id,
      deviceId,
      type: dto.type,
      content: dto.content,
      contact: dto.contact ?? null,
      status: 'pending',
      screenshotsJson: JSON.stringify(screenshots),
      clientIp: ip,
      createdAt: now,
    });

    return { success: true, id, receivedAt: now };
  }

  async list(params: { page: number; pageSize: number; type?: string; status?: string }) {
    const db = this.dbService.getDb();
    const { page, pageSize } = params;
    const offset = (page - 1) * pageSize;

    const conditions = [
      params.type ? eq(feedbacks.type, params.type) : undefined,
      params.status ? eq(feedbacks.status, params.status) : undefined,
    ].filter((c): c is NonNullable<typeof c> => c !== undefined);

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const rows = await db
      .select()
      .from(feedbacks)
      .where(where)
      .orderBy(desc(feedbacks.createdAt))
      .limit(pageSize)
      .offset(offset);

    const countRows = await db
      .select({ count: sql<number>`count(*)` })
      .from(feedbacks)
      .where(where);
    const total = countRows[0]?.count ?? 0;

    return {
      data: rows.map((r) => ({
        id: r.id,
        deviceId: r.deviceId,
        type: r.type,
        content: r.content,
        contact: r.contact,
        status: r.status,
        screenshots: this.parseScreenshots(r.screenshotsJson),
        createdAt: r.createdAt,
        clientIp: r.clientIp,
      })) as AdminFeedbackItem[],
      total,
      page,
      pageSize,
    };
  }

  async updateStatus(id: string, status: string) {
    const db = this.dbService.getDb();
    const rows = await db.select({ id: feedbacks.id }).from(feedbacks).where(eq(feedbacks.id, id)).limit(1);
    if (rows.length === 0) {
      throw new Error('not_found');
    }
    await db.update(feedbacks).set({ status }).where(eq(feedbacks.id, id));
    return { success: true as const, id, status };
  }

  private parseScreenshots(json: string): string[] {
    try {
      const v = JSON.parse(json);
      return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
    } catch {
      return [];
    }
  }
}