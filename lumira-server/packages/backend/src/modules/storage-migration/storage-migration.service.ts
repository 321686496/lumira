// lumira-server/packages/backend/src/modules/storage-migration/storage-migration.service.ts
// 迁移任务编排：后台异步执行（文件在服务器本地），DB 存迁移记录，失败详情落本地服务器文件。

import { Injectable, BadRequestException, NotFoundException, Inject } from '@nestjs/common';
import { eq, desc } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from '../../database/database.service';
import { storageMigrations } from '../../database/schema';
import { LocalStorageAdapter } from '../../common/storage/local-storage.adapter';
import { R2StorageAdapter } from '../../common/storage/r2-storage.adapter';
import { StorageMigrationAgent, MigrationSummary, FailureRecord } from './storage-migration.agent';

export interface MigrationRecordView {
  id: string;
  status: string;
  triggerBy: string;
  startedAt: number;
  finishedAt: number | null;
  error: string | null;
  summary: MigrationSummary | null;
  failureFile: string | null;
  createdAt: number;
}

export interface RunningJobView {
  running: boolean;
  id?: string;
  phase?: string;
  done?: number;
  total?: number;
  copied?: number;
}

const MIGRATIONS_DIR = path.resolve(
  process.env.MIGRATIONS_DIR || path.join(path.resolve(process.env.UPLOAD_DIR || './data/uploads'), '..', 'migrations'),
);

@Injectable()
export class StorageMigrationService {
  private running: { id: string; agent: StorageMigrationAgent } | null = null;

  constructor(private readonly dbService: DatabaseService) {}

  /** 仅单一任务并发执行 */
  start(triggerBy: string): { id: string } {
    if (this.running) {
      throw new BadRequestException('已有迁移任务正在运行，请等待完成或先停止');
    }
    const id = `sm_${nanoid(10)}`;
    const now = Math.floor(Date.now() / 1000);
    const db = this.dbService.getDb();
    db.insert(storageMigrations).values({
      id, status: 'running', triggerBy, startedAt: now, createdAt: now,
    }).then().catch((e) => console.error('[storage-migration] insert failed', e));

    const agent = new StorageMigrationAgent(this.dbService, new LocalStorageAdapter(), new R2StorageAdapter());
    this.running = { id, agent };

    void this.execute(id, agent, triggerBy, now);
    return { id };
  }

  private async execute(id: string, agent: StorageMigrationAgent, triggerBy: string, startedAt: number): Promise<void> {
    const db = this.dbService.getDb();
    let status: string = 'failed';
    let summaryJson: string | null = null;
    let failureFile: string | null = null;
    let error: string | null = null;
    try {
      const { summary, failures } = await agent.run();
      summaryJson = JSON.stringify(summary);
      if (failures.length > 0) {
        failureFile = await this.writeFailures(id, failures);
      }
      status = summary.success ? 'success' : 'failed';
    } catch (e) {
      if ((e as Error).message === 'migration_stopped') {
        status = 'stopped';
        error = '任务已被手动停止';
      } else {
        status = 'failed';
        error = (e as Error).message;
      }
      console.error(`[storage-migration] ${id} ${status}:`, (e as Error).message);
    } finally {
      const finishedAt = Math.floor(Date.now() / 1000);
      await db.update(storageMigrations)
        .set({ status, finishedAt, error: error ?? null, summaryJson, failureFile })
        .where(eq(storageMigrations.id, id));
      if (this.running?.id === id) this.running = null;
    }
  }

  stop(id: string): { stopped: boolean } {
    if (this.running?.id === id) {
      this.running.agent.cancel();
      return { stopped: true };
    }
    return { stopped: false };
  }

  runningView(): RunningJobView {
    if (!this.running) return { running: false };
    const p = this.running.agent.progress;
    return { running: true, id: this.running.id, phase: p.phase, done: p.done, total: p.total, copied: p.copied };
  }

  async list(): Promise<MigrationRecordView[]> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(storageMigrations).orderBy(desc(storageMigrations.createdAt)).limit(100);
    return rows.map((r) => this.toView(r));
  }

  async get(id: string): Promise<MigrationRecordView> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(storageMigrations).where(eq(storageMigrations.id, id)).limit(1);
    if (rows.length === 0) throw new NotFoundException('迁移记录不存在');
    return this.toView(rows[0]);
  }

  /** 读取迁移详情 + 失败明细文件（本地服务器），供后台展示 */
  async detail(id: string): Promise<MigrationRecordView & { failureDetail: FailureRecord[] }> {
    const rec = await this.get(id);
    let failureDetail: FailureRecord[] = [];
    if (rec.failureFile) {
      const file = path.join(MIGRATIONS_DIR, rec.failureFile.replace(/^migrations\//, ''));
      if (fs.existsSync(file)) {
        try {
          failureDetail = JSON.parse(fs.readFileSync(file, 'utf-8')) as FailureRecord[];
        } catch { /* 文件损坏则返回空 */ }
      }
    }
    return { ...rec, failureDetail };
  }

  private toView(r: typeof storageMigrations.$inferSelect): MigrationRecordView {
    let summary: MigrationSummary | null = null;
    if (r.summaryJson) {
      try { summary = JSON.parse(r.summaryJson) as MigrationSummary; } catch { /* ignore */ }
    }
    return {
      id: r.id, status: r.status, triggerBy: r.triggerBy, startedAt: r.startedAt,
      finishedAt: r.finishedAt, error: r.error, summary, failureFile: r.failureFile, createdAt: r.createdAt,
    };
  }

  private async writeFailures(id: string, failures: FailureRecord[]): Promise<string> {
    const dir = path.join(MIGRATIONS_DIR, id);
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, 'failures.json');
    fs.writeFileSync(file, JSON.stringify(failures, null, 2), 'utf-8');
    return `${id}/failures.json`;
  }
}