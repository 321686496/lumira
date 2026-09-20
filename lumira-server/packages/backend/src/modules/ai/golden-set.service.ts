// lumira-server/packages/backend/src/modules/ai/golden-set.service.ts
// Task 11 Golden Set 回归门禁 + Trend Index 新鲜度衰减 + 失败案例库。
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md 9.1 / 9.3
//
// - GoldenSetService.run()：遍历 GOLDEN_SET 用例，逐一跑 orchestrator + imageScore，汇总 pass/score/reasons（回归闸门）。
// - registerFailCase()：生成失败的案例登记入库（AI 向导/跑批报错时调用）。
// - upsertTrend()/getFreshTrend()：趋势索引幂等落库 + 新鲜度衰减查询（默认 7 天 TTL，过期触发增量）。

import { Injectable } from '@nestjs/common';
import { and, eq, gte } from 'drizzle-orm';
import type { MySql2Database } from 'drizzle-orm/mysql2';
import * as schema from '../../database/schema';
import { AiOrchestratorService } from './ai-orchestrator.service';
import type { OrchestratorInput, OrchestratorRunOptions } from './ai-orchestrator.service';
import { ImageScoreService } from './image-score.service';
import type { CategoryNode } from './normalize';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import { GOLDEN_SET } from './golden-set.data';

// ===== 数据集类型（golden-set.data.ts 复用）=====

export interface GoldenCase {
  /** 用例唯一 id */
  id: string;
  /** 用户意图（可作为 orchestrator 的 text 输入） */
  intent: string;
  creationReq?: string;
  imageBase64?: string;
  imageMime?: string;
  poseCount?: number;
  description: string;
  /** 期望验收要点（人工校验时逐条核对；自动化阶段作为评分的 reference 语义） */
  expectedPoints: string[];
  keywords: string[];
  categories: CategoryNode[];
  desc?: ImageDescription;
  poseSheet?: PoseRefSheet;
}

// ===== Trend Index 条目 =====

export interface TrendIndexItem {
  topic: string;
  source: string;
  /** 观察日期 YYYY-MM-DD（新鲜度衰减依据） */
  trendDate: string;
  title: string;
  snippet?: string;
  keywords?: string[];
  imgUrl?: string;
  url?: string;
  popularity?: number;
  payload?: Record<string, unknown>;
}

export interface TrendIndexRunOptions {
  /** 新鲜度窗口（天），默认 7 */
  ttlDays?: number;
  /** miss（无新鲜条目）时触发增量研究；回调无返回值 */
  onMiss?: () => Promise<unknown> | unknown;
}

export type FailCaseTrace = Array<Record<string, unknown>>;
export interface RegisterFailCaseOptions {
  templateId?: string;
}

// ===== helpers =====

function nowSec(): number {
  return Math.floor(Date.now() / 1000);
}

/** 返回 YYYY-MM-DD（UTC），保证与 trendDate 字典序可比 */
function dateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function parseKeywords(json: unknown): string[] | undefined {
  if (typeof json !== 'string' || !json) return undefined;
  try {
    const arr = JSON.parse(json);
    return Array.isArray(arr) ? arr.filter((x): x is string => typeof x === 'string') : undefined;
  } catch {
    return undefined;
  }
}

function fromTrendRow(row: typeof schema.trendIndex.$inferSelect): TrendIndexItem | undefined {
  let payload: Record<string, unknown> | undefined;
  if (row.payloadJson) {
    try {
      const parsed = JSON.parse(row.payloadJson);
      if (parsed && typeof parsed === 'object') payload = parsed as Record<string, unknown>;
    } catch {
      payload = undefined;
    }
  }
  return {
    topic: row.topic,
    source: row.source,
    trendDate: row.trendDate,
    title: row.title,
    snippet: row.snippet ?? undefined,
    keywords: parseKeywords(row.keywordsJson),
    imgUrl: row.imgUrl ?? undefined,
    url: row.url ?? undefined,
    popularity: typeof row.popularity === 'number' ? row.popularity : undefined,
    payload,
  };
}

// ===== 趋势索引（新鲜度衰减）=====

/** 幂等 upsert：by topic×source×trendDate；已存在 → update（inserted=false），否则 insert（inserted=true） */
export async function upsertTrend(
  db: MySql2Database<typeof schema>,
  item: TrendIndexItem,
): Promise<{ inserted: boolean }> {
  const exists = await db
    .select({ id: schema.trendIndex.id })
    .from(schema.trendIndex)
    .where(
      and(
        eq(schema.trendIndex.topic, item.topic),
        eq(schema.trendIndex.source, item.source ?? ''),
        eq(schema.trendIndex.trendDate, item.trendDate),
      ),
    )
    .limit(1);

  const values = {
    source: item.source ?? '',
    trendDate: item.trendDate,
    title: item.title,
    snippet: item.snippet ?? null,
    keywordsJson: item.keywords ? JSON.stringify(item.keywords) : null,
    imgUrl: item.imgUrl ?? null,
    url: item.url ?? null,
    popularity: typeof item.popularity === 'number' ? item.popularity : null,
    payloadJson: item.payload ? JSON.stringify(item.payload) : null,
  };

  if (exists.length) {
    await db
      .update(schema.trendIndex)
      .set({ ...values, updatedAt: nowSec() })
      .where(eq(schema.trendIndex.id, exists[0].id));
    return { inserted: false };
  }

  await db.insert(schema.trendIndex).values({
    topic: item.topic,
    ...values,
    createdAt: nowSec(),
    updatedAt: nowSec(),
  });
  return { inserted: true };
}

/** 新鲜度衰减查询：7 天内命中返回条目；miss → 触发增量（onMiss）并返回空 */
export async function getFreshTrend(
  db: MySql2Database<typeof schema>,
  topic: string,
  opts: TrendIndexRunOptions = {},
): Promise<TrendIndexItem[]> {
  const ttlDays = opts.ttlDays ?? 7;
  const cutoff = dateOnly(new Date(Date.now() - ttlDays * 86_400_000));

  const rows = await db
    .select()
    .from(schema.trendIndex)
    .where(and(eq(schema.trendIndex.topic, topic), gte(schema.trendIndex.trendDate, cutoff)))
    .orderBy(schema.trendIndex.updatedAt)
    .limit(50);

  const items = rows
    .map(fromTrendRow)
    .filter((it): it is TrendIndexItem => Boolean(it));

  if (items.length) return items;
  if (opts.onMiss) await opts.onMiss();
  return [];
}

// ===== 失败案例库 =====

/** 登记一条生成失败的案例，返回新行 id */
export async function registerFailCase(
  db: MySql2Database<typeof schema>,
  trace: FailCaseTrace,
  reasons: string[],
  opts: RegisterFailCaseOptions = {},
): Promise<number> {
  const now = nowSec();
  const res = await db.insert(schema.templateFailCases).values({
    templateId: opts.templateId ?? null,
    traceJson: JSON.stringify(trace),
    reasonsJson: JSON.stringify(reasons),
    failCount: 1,
    createdAt: now,
    updatedAt: now,
  });
  return Number(res[0]?.insertId ?? 0);
}

// ===== GoldenSetService（回归闸门）=====

export interface GoldenRunResult {
  id: string;
  pass: boolean;
  score: number;
  reasons: string[];
}

/** 汇集各用例的评分语义：缺省由 GoldenCase.desc 提供期望值，缺省回退文本脚手架 */
function scaffoldDesc(subject: string): ImageDescription {
  return {
    global: { subject, mood: '', season: '', timeOfDay: '', palette: { dominant: [], tone: '', brightness: '' }, light: {}, composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '3:4', negativeSpace: '', depthOfField: '' }, reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' } },
    people: [],
    scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
    cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
  };
}

function scaffoldSheet(mood: string): PoseRefSheet {
  return { shared: { outfit: '', scene: '', light: '', aspectRatio: '3:4', mood, palette: '' }, perPose: [] };
}

@Injectable()
export class GoldenSetService {
  constructor(
    private readonly db: MySql2Database<typeof schema>,
    private readonly orchestrator: AiOrchestratorService,
    private readonly imageScore: ImageScoreService,
  ) {}

  /** 回归跑批：遍历 GOLDEN_SET 用例，逐一 orchestrator + imageScore，汇总 pass/score/reasons */
  async run(): Promise<GoldenRunResult[]> {
    const results: GoldenRunResult[] = [];

    for (const g of GOLDEN_SET) {
      try {
        const input: OrchestratorInput = {
          text: g.intent,
          creationReq: g.creationReq,
          imageBase64: g.imageBase64,
          imageMime: g.imageMime,
          poseCount: g.poseCount,
        };
        const opts: OrchestratorRunOptions = { categories: g.categories };

        const out = await this.orchestrator.run(input, opts);
        const name =
          (out.draft as { meta?: { name?: unknown } } | undefined)?.meta?.name
          ?? out.draft?.name;
        const subject = typeof name === 'string' ? name : g.intent;

        const desc = g.desc ?? scaffoldDesc(subject);
        const poseSheet = g.poseSheet ?? scaffoldSheet(desc.global?.mood ?? '');

        const scored = await this.imageScore.score({
          desc,
          poseSheet,
          research: [],
          draft: out.draft,
        });

        results.push({
          id: g.id,
          pass: scored.verdict === 'pass',
          score: scored.score,
          reasons: scored.reasons,
        });
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        results.push({ id: g.id, pass: false, score: 0, reasons: [`用例执行异常：${msg}`] });
      }
    }

    return results;
  }
}