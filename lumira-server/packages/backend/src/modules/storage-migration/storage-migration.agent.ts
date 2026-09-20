// lumira-server/packages/backend/src/modules/storage-migration/storage-migration.agent.ts
// 迁移 + 全校验执行器：DB 驱动枚举 + 磁盘扫描兜底 → 复制到目标存储 → 三向核对 → 报告 + 失败详情落盘。
// 迁移在服务端后台异步执行（文件在服务器本地），通过 JobHandle 提供进度/取消。

import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  templates,
  templateCategories,
  operationBanners,
  feedbacks,
  userProfiles,
} from '../../database/schema';
import { toStorageKey } from '../../common/storage/storage-key';
import type { StorageAdapter, StorageCategory } from '../../common/storage/storage-adapter.interface';

/** 单个存储 key 引用 */
export interface KeyRef {
  category: StorageCategory;
  entityId: string;
  storageKey: string;
  entityLabel: string; // 如 `template:srv_xxx`、`category:portrait`、`banner:xxx`
}

/** 报告：逐类别三向核对结果 */
export interface CategoryReport {
  category: StorageCategory;
  dbTotal: number;
  diskTotal: number;
  migrated: number;      // 磁盘有文件且目标已存在
  copied: number;        // 本次新复制到目标
  missingTarget: number; // 磁盘有文件但目标缺失（失败/未复制）
  danglingDb: number;    // DB 引用但本地磁盘无文件（坏数据）
  orphans: number;       // 磁盘存在但未被任何 DB 引用
  failed: number;        // 复制抛异常
}

export interface MigrationSummary {
  success: boolean;
  byCategory: Record<string, CategoryReport>;
  totals: {
    db: number;
    disk: number;
    migrated: number;
    copied: number;
    missingTarget: number;
    danglingDb: number;
    orphans: number;
    failed: number;
  };
}

/** 失败详情记录（落本地文件） */
export interface FailureRecord {
  phase: string;
  storageKey: string;
  entityLabel?: string;
  reason: string;
  at: number;
}

/** 从 JSON 文本里递归收集所有「存储 key 形态」的字符串（cover/images/pose.silhouette/icon 等通用化处理） */
function collectStorageKeys(jsonText: string | null): string[] {
  if (!jsonText) return [];
  let data: unknown;
  try {
    data = JSON.parse(jsonText);
  } catch {
    return [];
  }
  const out = new Set<string>();
  const walk = (v: unknown): void => {
    if (Array.isArray(v)) {
      v.forEach(walk);
    } else if (v && typeof v === 'object') {
      for (const val of Object.values(v)) walk(val);
    } else if (typeof v === 'string') {
      const key = toStorageKey(v);
      if (key) out.add(key);
    }
  };
  walk(data);
  return [...out];
}

export class StorageMigrationAgent {
  private cancelled = false;
  readonly progress: { phase: string; total: number; done: number; copied: number } = {
    phase: 'idle', total: 0, done: 0, copied: 0,
  };

  constructor(
    private readonly db: DatabaseService,
    private readonly source: StorageAdapter, // 迁移源：当前激活存储（任意厂商）
    private readonly dest: StorageAdapter,   // 迁移目标：本次选择的存储
  ) {}

  cancel(): void {
    this.cancelled = true;
  }

  private throwIfCancelled(): void {
    if (this.cancelled) throw new Error('migration_stopped');
  }

  /** 从 DB 枚举「每个应用图片存储的实体」的 storageKey（DB 驱动） */
  private async enumerateDbKeys(): Promise<{
    dbRefs: KeyRef[];
    dbKeys: Set<string>;
  }> {
    const dbs = this.db.getDb();
    const dbRefs: KeyRef[] = [];
    const dbKeys = new Set<string>();
    const push = (category: StorageCategory, entityId: string, entityLabel: string, refs: string[]) => {
      for (const storageKey of refs) {
        if (!dbKeys.has(storageKey)) {
          dbKeys.add(storageKey);
          dbRefs.push({ category, entityId, storageKey, entityLabel });
        }
      }
    };

    // 1) 模板：cover_url + images_json + pose_json
    const tpl = await dbs.select({
      id: templates.id,
      coverUrl: templates.coverUrl,
      imagesJson: templates.imagesJson,
      poseJson: templates.poseJson,
    }).from(templates);
    for (const t of tpl) {
      const label = `template:${t.id}`;
      const refs = [...collectStorageKeys(t.imagesJson), ...collectStorageKeys(t.poseJson)];
      const cover = toStorageKey(t.coverUrl);
      if (cover) refs.push(cover);
      push('templates', t.id, label, refs);
    }

    // 2) 分类图标
    const cats = await dbs.select({ key: templateCategories.key, iconUrl: templateCategories.iconUrl }).from(templateCategories);
    for (const c of cats) {
      const icon = toStorageKey(c.iconUrl);
      push('categories', c.key, `category:${c.key}`, icon ? [icon] : []);
    }

    // 3) Banner 配图
    const bann = await dbs.select({ id: operationBanners.id, imageUrl: operationBanners.imageUrl }).from(operationBanners);
    for (const b of bann) {
      const img = toStorageKey(b.imageUrl);
      push('banners', b.id, `banner:${b.id}`, img ? [img] : []);
    }

    // 4) 反馈截图（存的是绝对 URL，toStorageKey 归整为相对 key）
    const fbs = await dbs.select({ id: feedbacks.id, screenshotsJson: feedbacks.screenshotsJson }).from(feedbacks);
    for (const f of fbs) {
      push('feedback', f.id, `feedback:${f.id}`, collectStorageKeys(f.screenshotsJson));
    }

    // 5) 用户头像（绝对 URL → 相对 key）
    const ups = await dbs.select({ deviceId: userProfiles.deviceId, avatarUrl: userProfiles.avatarUrl }).from(userProfiles);
    for (const u of ups) {
      const av = toStorageKey(u.avatarUrl);
      push('users', u.deviceId, `user:${u.deviceId}`, av ? [av] : []);
    }

    return { dbRefs, dbKeys };
  }

  /** 磁盘扫描兜底：本地上传目录所有文件 */
  private async enumerateDiskKeys(): Promise<Set<string>> {
    return new Set(await this.source.listKeys());
  }

  /** 解析 storageKey `/uploads/{cat}/{id}/{filename}` → write 参数 */
  private parseParts(storageKey: string): { category: StorageCategory; id: string; filename: string } {
    const parts = storageKey.replace(/^\/uploads\//, '').split('/');
    const category = parts[0] as StorageCategory;
    const id = parts[1] ?? '';
    const filename = parts.slice(2).join('/') || 'unknown';
    return { category, id, filename };
  }

  private emptyCategoryCounts(): Record<string, CategoryReport> {
    const byCategory: Record<string, CategoryReport> = {};
    for (const cat of ['templates', 'categories', 'banners', 'feedback', 'users'] as StorageCategory[]) {
      byCategory[cat] = {
        category: cat, dbTotal: 0, diskTotal: 0, migrated: 0, copied: 0,
        missingTarget: 0, danglingDb: 0, orphans: 0, failed: 0,
      };
    }
    return byCategory;
  }

  /** 仅对指定失败 storageKey 重试：源→目标复制 + 逐条核对（源/目标复用记录里的厂商）。 */
  async retryOnly(scopedKeys: string[]): Promise<{
    summary: MigrationSummary;
    failures: FailureRecord[];
    copiedKeys: string[];
  }> {
    const keys = [...new Set(scopedKeys)];
    this.progress.phase = 'copy';
    this.progress.total = keys.length;
    this.progress.done = 0;
    this.progress.copied = 0;

    const failures: FailureRecord[] = [];
    const copiedKeys: string[] = [];
    const targetKeys = new Set(await this.dest.listKeys());

    // 复制缺失的文件
    for (const storageKey of keys) {
      this.throwIfCancelled();
      this.progress.done++;
      if (targetKeys.has(storageKey)) continue; // 目标已有（上次可能已部分成功）
      const { category, id, filename } = this.parseParts(storageKey);
      try {
        const buffer = await this.source.readBuffer(storageKey);
        await this.dest.write(category, id, filename, buffer);
        copiedKeys.push(storageKey);
        this.progress.copied++;
      } catch (e) {
        failures.push({ phase: 'copy', storageKey, reason: `重试复制失败：${(e as Error).message}`, at: Date.now() });
      }
    }

    this.progress.phase = 'verify';
    const finalTarget = new Set<string>([...targetKeys, ...copiedKeys]);
    const byCategory = this.emptyCategoryCounts();
    const totals = { db: 0, disk: 0, migrated: 0, copied: 0, missingTarget: 0, danglingDb: 0, orphans: 0, failed: 0 };

    for (const storageKey of keys) {
      const cat = (storageKey.replace(/^\/uploads\//, '').split('/')[0] || '') as StorageCategory;
      const r = byCategory[cat];
      if (!r) continue;
      r.dbTotal++;
      totals.db++;
      let onDisk = true;
      try { await this.source.readBuffer(storageKey); } catch { onDisk = false; }
      const covered = finalTarget.has(storageKey);
      if (!onDisk) {
        r.danglingDb++;
        failures.push({ phase: 'verify', storageKey, reason: '源存储中无该文件，无法重试', at: Date.now() });
      } else if (covered) {
        r.migrated++;
        if (copiedKeys.includes(storageKey)) r.copied++;
      } else {
        r.missingTarget++;
        failures.push({ phase: 'verify', storageKey, reason: '目标存储仍缺失该文件', at: Date.now() });
      }
    }

    for (const cat of Object.values(byCategory)) {
      totals.migrated += cat.migrated;
      totals.copied += cat.copied;
      totals.missingTarget += cat.missingTarget;
      totals.danglingDb += cat.danglingDb;
      totals.orphans += cat.orphans;
    }
    totals.failed = failures.length;

    this.progress.phase = 'done';
    return {
      summary: { success: totals.missingTarget === 0 && totals.failed === 0, byCategory, totals },
      failures,
      copiedKeys,
    };
  }

  /**
   * 执行一次完整迁移：枚举 → 复制 → 三向核对。
   * 返回 { refs, diskKeys, targetKeys, summary, failures, copiedKeys }
   */
  async run(): Promise<{
    refs: KeyRef[];
    diskKeys: Set<string>;
    targetKeys: Set<string>;
    summary: MigrationSummary;
    failures: FailureRecord[];
    copiedKeys: string[];
  }> {
    const start = Date.now();
    // 阶段 A：枚举
    this.progress.phase = 'enum-db';
    const { dbRefs, dbKeys } = await this.enumerateDbKeys();
    this.throwIfCancelled();
    this.progress.phase = 'enum-disk';
    const diskKeys = await this.enumerateDiskKeys();
    this.throwIfCancelled();
    this.progress.phase = 'enum-target';
    const targetKeys = new Set(await this.dest.listKeys());
    this.throwIfCancelled();

    const failures: FailureRecord[] = [];
    const copiedKeys: string[] = [];

    // 阶段 B：复制（磁盘文件 → 目标），幂等：目标已有则跳过
    const union = new Set<string>([...dbKeys, ...diskKeys]);
    this.progress.phase = 'copy';
    this.progress.total = union.size;
    this.progress.done = 0;
    this.progress.copied = 0;
    for (const storageKey of union) {
      this.throwIfCancelled();
      this.progress.done++;
      if (targetKeys.has(storageKey)) continue; // 已迁
      if (!diskKeys.has(storageKey)) continue;  // 本地无文件，交由核对阶段标记 dangling
      try {
        const buffer = await this.source.readBuffer(storageKey);
        const { category, id, filename } = this.parseParts(storageKey);
        await this.dest.write(category, id, filename, buffer);
        copiedKeys.push(storageKey);
        this.progress.copied++;
      } catch (e) {
        failures.push({ phase: 'copy', storageKey, reason: `复制失败：${(e as Error).message}`, at: Date.now() });
      }
    }
    this.throwIfCancelled();

    // 阶段 C：三向核对（重新拉目标清单，纳入本次复制结果）
    this.progress.phase = 'verify';
    const finalTargetKeys = new Set<string>([...targetKeys, ...copiedKeys]);

    const byCategory: Record<string, CategoryReport> = {};
    const totals = {
      db: dbRefs.length,
      disk: diskKeys.size,
      migrated: 0,
      copied: 0,
      missingTarget: 0,
      danglingDb: 0,
      orphans: 0,
      failed: 0,
    };

    // DB 引用数按类别
    const dbCountByCat = new Map<StorageCategory, number>();
    for (const ref of dbRefs) dbCountByCat.set(ref.category, (dbCountByCat.get(ref.category) ?? 0) + 1);
    // 磁盘数按类别
    const diskCountByCat = new Map<StorageCategory, number>();
    for (const k of diskKeys) {
      const cat = (k.replace(/^\/uploads\//, '').split('/')[0] || '') as StorageCategory;
      diskCountByCat.set(cat, (diskCountByCat.get(cat) ?? 0) + 1);
    }

    const cats: StorageCategory[] = ['templates', 'categories', 'banners', 'feedback', 'users'];
    for (const cat of cats) {
      const report: CategoryReport = {
        category: cat,
        dbTotal: dbCountByCat.get(cat) ?? 0,
        diskTotal: diskCountByCat.get(cat) ?? 0,
        migrated: 0, copied: 0, missingTarget: 0, danglingDb: 0, orphans: 0, failed: 0,
      };
      byCategory[cat] = report;
    }

    // 逐 DB 引用核对
    for (const ref of dbRefs) {
      const r = byCategory[ref.category];
      const onDisk = diskKeys.has(ref.storageKey);
      const inTarget = finalTargetKeys.has(ref.storageKey);
      if (!onDisk) {
        r.danglingDb++;
        failures.push({ phase: 'verify', storageKey: ref.storageKey, entityLabel: ref.entityLabel, reason: 'DB 引用但本地磁盘无文件（坏数据）', at: Date.now() });
        continue;
      }
      if (inTarget) {
        r.migrated++;
      } else if (copiedKeys.includes(ref.storageKey)) {
        r.copied++;
      } else {
        r.missingTarget++;
        failures.push({ phase: 'verify', storageKey: ref.storageKey, entityLabel: ref.entityLabel, reason: '磁盘有文件但目标缺失', at: Date.now() });
      }
    }

    // 孤儿：磁盘有但 DB 未引用（信息项，不计失败）
    for (const k of diskKeys) {
      if (!dbKeys.has(k)) {
        const cat = (k.replace(/^\/uploads\//, '').split('/')[0] || '') as StorageCategory;
        if (byCategory[cat]) byCategory[cat].orphans++;
      }
    }

    for (const cat of cats) {
      const r = byCategory[cat];
      totals.migrated += r.migrated;
      totals.copied += r.copied;
      totals.missingTarget += r.missingTarget;
      totals.danglingDb += r.danglingDb;
      totals.orphans += r.orphans;
      totals.failed = failures.length;
    }

    const summary: MigrationSummary = {
      success: totals.missingTarget === 0 && totals.failed === 0,
      byCategory,
      totals,
    };
    // 历史存量头像/截图若存的是绝对 URL，统一重写为相对 storageKey：切 R2 后它们才能真正走 R2 访问
    await this.normalizeStoredKeys();

    void start;
    return { refs: dbRefs, diskKeys, targetKeys, summary, failures, copiedKeys };
  }

  /** 把手写库里的绝对 `/uploads` URL 重写为相对 storageKey（头像 + 反馈截图） */
  private async normalizeStoredKeys(): Promise<void> {
    const db = this.db.getDb();

    // 用户头像
    const ups = await db.select({ deviceId: userProfiles.deviceId, avatarUrl: userProfiles.avatarUrl }).from(userProfiles);
    for (const u of ups) {
      const key = toStorageKey(u.avatarUrl);
      if (key !== null && key !== u.avatarUrl) {
        await db.update(userProfiles).set({ avatarUrl: key }).where(eq(userProfiles.deviceId, u.deviceId));
      }
    }

    // 反馈截图（数组，逐条归整）
    const fbs = await db.select({ id: feedbacks.id, screenshotsJson: feedbacks.screenshotsJson }).from(feedbacks);
    for (const f of fbs) {
      let arr: string[] = [];
      try { arr = JSON.parse(f.screenshotsJson); } catch { /* ignore */ }
      if (!Array.isArray(arr)) continue;
      const normalized = arr.map((s) => toStorageKey(s) ?? s);
      const changed = normalized.some((n, i) => n !== arr[i]);
      if (changed) {
        await db.update(feedbacks).set({ screenshotsJson: JSON.stringify(normalized) }).where(eq(feedbacks.id, f.id));
      }
    }
  }
}