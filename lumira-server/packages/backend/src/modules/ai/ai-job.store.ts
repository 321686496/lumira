// lumira-server/packages/backend/src/modules/ai/ai-job.store.ts
// AI 生成任务持久化层：DB 行（列表展示数据）+ 存储文件（详情/事件流/产物/输入）。
// 只负责「存 / 取 / 删」，不含调度与阶段逻辑。
import { Injectable } from '@nestjs/common';
import { asc, desc, eq, inArray, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { aiTemplateJobs } from '../../database/schema';
import { activeStorageAdapter } from '../../common/storage/runtime-storage';
import type { PipelineStage } from './ai-pipeline-job.service';

export type AiJobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped' | 'interrupted';
export type AiJobMode = 'auto' | 'analyze-only';

export const SETTLED_STATUSES: readonly AiJobStatus[] = ['done', 'error', 'stopped', 'interrupted'];

export interface AiJobRow {
  id: string;
  status: AiJobStatus;
  mode: AiJobMode;
  title: string;
  currentStage: PipelineStage | null;
  poseTotal: number;
  poseDone: number;
  silTotal: number;
  silDone: number;
  queuePos: number;
  inputSummary: Record<string, unknown>;
  errorCode: string | null;
  errorMessage: string | null;
  detailKey: string | null;
  createdAt: number;
  startedAt: number | null;
  finishedAt: number | null;
}

export interface StoredArtifact { index: number; mimeType: string; storageKey: string; url: string }

export interface AiJobDetailFile {
  stages: unknown;
  error: unknown | null;
  warnings: unknown[];
  draft: unknown | null;
  trace: unknown[];
  raw: unknown | null;
  research: unknown[];
  researchBrief: unknown | null;
  researchVision: unknown | null;
  artifacts: {
    poseFiles: StoredArtifact[];
    poseErrors: unknown[];
    silFiles: StoredArtifact[];
    silErrors: unknown[];
  };
  inputs: Record<string, unknown>;
}

export type AiJobPatch = Partial<
  Pick<
    AiJobRow,
    | 'status' | 'currentStage' | 'poseTotal' | 'poseDone' | 'silTotal' | 'silDone'
    | 'queuePos' | 'errorCode' | 'errorMessage' | 'detailKey' | 'startedAt' | 'finishedAt'
  >
>;

const MIME_EXT: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

function extOf(mimeType: string): string {
  return MIME_EXT[mimeType] ?? 'png';
}

@Injectable()
export class AiJobStoreService {
  constructor(private readonly dbService: DatabaseService) {}

  private get db() {
    return this.dbService.getDb();
  }

  /** 任务目录 storageKey 前缀 */
  detailKeyOf(jobId: string): string {
    return `/uploads/ai-jobs/${jobId}/`;
  }

  async insertJob(row: AiJobRow): Promise<void> {
    await this.db.insert(aiTemplateJobs).values({
      id: row.id,
      status: row.status,
      mode: row.mode,
      title: row.title,
      currentStage: row.currentStage,
      poseTotal: row.poseTotal,
      poseDone: row.poseDone,
      silTotal: row.silTotal,
      silDone: row.silDone,
      queuePos: row.queuePos,
      inputSummaryJson: JSON.stringify(row.inputSummary ?? {}),
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      detailKey: row.detailKey ?? this.detailKeyOf(row.id),
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
    });
  }

  async updateJob(id: string, patch: AiJobPatch): Promise<void> {
    if (!Object.keys(patch).length) return;
    await this.db.update(aiTemplateJobs).set(patch).where(eq(aiTemplateJobs.id, id));
  }

  /** 按传入顺序重写 queue_pos（1-based），仅供队列服务排队时刷新 */
  async setQueuePositions(orderedIds: string[]): Promise<void> {
    await Promise.all(orderedIds.map((id, i) => this.updateJob(id, { queuePos: i + 1 })));
  }

  async findJob(id: string): Promise<AiJobRow | null> {
    const r = await this.db.query.aiTemplateJobs.findFirst({ where: eq(aiTemplateJobs.id, id) });
    return r ? this.toRow(r) : null;
  }

  async listJobs(opts: { status?: AiJobStatus; limit: number; offset: number }): Promise<{ items: AiJobRow[]; total: number }> {
    const where = opts.status ? eq(aiTemplateJobs.status, opts.status) : undefined;
    const rows = await this.db
      .select()
      .from(aiTemplateJobs)
      .where(where)
      .orderBy(desc(aiTemplateJobs.createdAt))
      .limit(opts.limit)
      .offset(opts.offset);
    const [counted] = await this.db.select({ count: sql<number>`count(*)` }).from(aiTemplateJobs).where(where);
    return { items: rows.map((r) => this.toRow(r)), total: Number(counted?.count ?? 0) };
  }

  /** 重启恢复用：按创建时间升序取全部排队中任务 */
  async listQueued(): Promise<AiJobRow[]> {
    const rows = await this.db
      .select()
      .from(aiTemplateJobs)
      .where(eq(aiTemplateJobs.status, 'queued'))
      .orderBy(asc(aiTemplateJobs.createdAt));
    return rows.map((r) => this.toRow(r));
  }

  async deleteJob(id: string): Promise<void> {
    await this.db.delete(aiTemplateJobs).where(eq(aiTemplateJobs.id, id));
    await activeStorageAdapter.deleteByDir('ai-jobs', id);
  }

  /** 批量清理全部终态任务（含文件），返回删除条数 */
  async deleteSettled(): Promise<number> {
    const rows = await this.db
      .select({ id: aiTemplateJobs.id })
      .from(aiTemplateJobs)
      .where(inArray(aiTemplateJobs.status, [...SETTLED_STATUSES]));
    for (const r of rows) await this.deleteJob(r.id);
    return rows.length;
  }

  // ===== 存储文件 =====

  async writeDetail(id: string, detail: AiJobDetailFile): Promise<void> {
    await activeStorageAdapter.write('ai-jobs', id, 'detail.json', Buffer.from(JSON.stringify(detail)));
  }

  async readDetail(id: string): Promise<AiJobDetailFile | null> {
    const key = `${this.detailKeyOf(id)}detail.json`;
    if (!(await activeStorageAdapter.exists(key))) return null;
    return JSON.parse((await activeStorageAdapter.readBuffer(key)).toString('utf8')) as AiJobDetailFile;
  }

  async writeEvents(id: string, events: unknown[]): Promise<void> {
    const body = events.map((e) => JSON.stringify(e)).join('\n');
    await activeStorageAdapter.write('ai-jobs', id, 'events.jsonl', Buffer.from(body));
  }

  async readEvents(id: string): Promise<unknown[]> {
    const key = `${this.detailKeyOf(id)}events.jsonl`;
    if (!(await activeStorageAdapter.exists(key))) return [];
    const text = (await activeStorageAdapter.readBuffer(key)).toString('utf8');
    return text
      .split('\n')
      .filter((line) => line.trim())
      .map((line) => JSON.parse(line) as unknown);
  }

  /** 产物图：一次写入不覆盖（immutable 缓存安全） */
  async writeArtifact(
    id: string,
    kind: 'pose' | 'sil',
    index: number,
    mimeType: string,
    buffer: Buffer,
  ): Promise<StoredArtifact> {
    const filename = `${kind}-${index}.${extOf(mimeType)}`;
    const storageKey = await activeStorageAdapter.write('ai-jobs', id, filename, buffer);
    return { index, mimeType, storageKey, url: storageKey };
  }

  /** 输入图：供停止后续跑 / 后端重启后续跑 */
  async writeInput(
    id: string,
    kind: 'example' | 'ref',
    index: number,
    mimeType: string,
    buffer: Buffer,
  ): Promise<string> {
    return activeStorageAdapter.write('ai-jobs', id, `input/${kind}-${index}.${extOf(mimeType)}`, buffer);
  }

  /** 读取全部输入图（按 storageKey 升序，名称形如 input/example-0.png） */
  async readInputs(id: string): Promise<Array<{ name: string; buffer: Buffer }>> {
    const keys = (await activeStorageAdapter.listKeys(`${this.detailKeyOf(id)}input`)).sort();
    const out: Array<{ name: string; buffer: Buffer }> = [];
    for (const key of keys) {
      out.push({ name: key.replace(this.detailKeyOf(id), ''), buffer: await activeStorageAdapter.readBuffer(key) });
    }
    return out;
  }

  private toRow(r: Record<string, unknown>): AiJobRow {
    let inputSummary: Record<string, unknown> = {};
    const raw = r.inputSummaryJson as string | null | undefined;
    if (raw) {
      try {
        inputSummary = JSON.parse(raw) as Record<string, unknown>;
      } catch {
        inputSummary = {};
      }
    }
    return {
      id: r.id as string,
      status: r.status as AiJobStatus,
      mode: r.mode as AiJobMode,
      title: r.title as string,
      currentStage: (r.currentStage as PipelineStage | null) ?? null,
      poseTotal: Number(r.poseTotal ?? 0),
      poseDone: Number(r.poseDone ?? 0),
      silTotal: Number(r.silTotal ?? 0),
      silDone: Number(r.silDone ?? 0),
      queuePos: Number(r.queuePos ?? 0),
      inputSummary,
      errorCode: (r.errorCode as string | null) ?? null,
      errorMessage: (r.errorMessage as string | null) ?? null,
      detailKey: (r.detailKey as string | null) ?? null,
      createdAt: Number(r.createdAt ?? 0),
      startedAt: r.startedAt == null ? null : Number(r.startedAt),
      finishedAt: r.finishedAt == null ? null : Number(r.finishedAt),
    };
  }
}