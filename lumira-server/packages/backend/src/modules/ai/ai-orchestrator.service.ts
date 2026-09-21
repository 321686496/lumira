// lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts
// Task 9 AiOrchestratorService 中枢 + Agent Loop：把 T1~T6 工具按「固定顺序带判断」编排成产草稿管线。
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md
//
// 流程：(1) 组装 context → (2) research（若研究开启且主题非空）→ (3) 有图→describe 收集 ImageDescription；
// (4) poseRefSheet(desc, poseCount) → (5) paramValidate(draft) → (6) imageScore 闸门（低于阈值再判，迭代上限≤3）
// → 定稿 normalizeDraft → {draft,warnings,trace}。
// 工程约束：工具失败 wrap 降级继续（不中断整体跑批）；迭代有预算护栏；契约只扩展不破坏既有。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { TrendResearchService } from './trend-research/trend-research.service';
import type { ResearchItem } from './trend-research/research-item';
import { ImageDescribeService } from './image-describe.service';
import type { ImageDescription } from './image-describe.service';
import { PoseRefSheetService } from './pose-ref-sheet.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import { ParamValidateService } from './param-validate.service';
import { ImageScoreService } from './image-score.service';
import type { ImageScoreInput } from './image-score.service';
import { normalizeDraft } from './normalize';
import type { CategoryNode } from './normalize';

/** 单条 trace：记录各阶段发生了什么（供后台展示/调试） */
export interface OrchestratorTraceEntry {
  step: string;
  tool?: string;
  resultBrief: string;
  score?: number;
}

export interface OrchestratorInput {
  imageBase64?: string;
  imageMime?: string;
  text?: string;
  creationReq?: string;
  poseCount?: number;
}

/** run 可选依赖：categories 供 normalizeDraft；draft 为调用方（ai-analyze）已产出的初始草稿 */
export interface OrchestratorRunOptions {
  categories: CategoryNode[];
  draft?: Record<string, unknown>;
}

export interface OrchestratorResult {
  draft: Record<string, unknown>;
  warnings: string[];
  trace: OrchestratorTraceEntry[];
  /** 趋势研究阶段命中的来源（含 url），未启用/无主题时为空数组 */
  research: ResearchItem[];
}

/** 评分闸门 / 再判迭代预算上限 */
const MAX_SCORE_ITERATIONS = 3;

@Injectable()
export class AiOrchestratorService {
  constructor(
    private readonly aiConfigService: AiConfigService,
    private readonly trendResearch: TrendResearchService,
    private readonly imageDescribe: ImageDescribeService,
    private readonly poseRefSheet: PoseRefSheetService,
    private readonly paramValidate: ParamValidateService,
    private readonly imageScore: ImageScoreService,
  ) {}

  async run(input: OrchestratorInput, opts: OrchestratorRunOptions): Promise<OrchestratorResult> {
    const { categories, draft: initialDraft = {} } = opts;
    const trace: OrchestratorTraceEntry[] = [];
    const warnings: string[] = [];

    trace.push({ step: 'assemble', resultBrief: 'context 就绪（角色+契约+进度）' });

    // 研究主题：创作要求 ?? 文字描述；空 → 跳过研究
    const topic = (input.creationReq ?? input.text ?? '').trim();

    // (2) 趋势研究（可开关、失败降级；关闭/无主题 → skip-research）
    let research: ResearchItem[] = [];
    // getSearchConfig 由 Task 10 接线才会出现在 AiConfigService；此处可选探测，未实现即研究关闭
    const searchCfg = (await (
      (this.aiConfigService as { getSearchConfig?: () => Promise<unknown> | unknown | undefined }).getSearchConfig?.()
    )) as { enabled?: boolean; sources?: unknown[] } | undefined;
    const researchEnabled = Boolean(searchCfg?.enabled && Array.isArray(searchCfg.sources) && searchCfg.sources.length && topic);
    if (!researchEnabled) {
      trace.push({ step: 'research', tool: 'trend-research', resultBrief: 'skip-research' });
    } else {
      research = (await this.wrapStep<ResearchItem[]>('research', 'trend-research', trace, () =>
        this.trendResearch.research(topic, { limitPerSource: 5 }),
      )) ?? [];
      if (!research.length) {
        const last = trace[trace.length - 1];
        if (last && last.step === 'research' && !last.resultBrief.includes('fail')) {
          last.resultBrief = 'skip-research'; // 命中为空视为跳过
        }
      }
    }

    // (3) 有图 → 穷尽识别；无图 → 跳过
    let desc: ImageDescription | undefined;
    if (input.imageBase64 && input.imageMime) {
      desc = await this.wrapStep<ImageDescription>('describe', 'image-describe', trace, () =>
        this.imageDescribe.describe({ base64: input.imageBase64 as string, mime: input.imageMime as string }),
      );
    } else {
      trace.push({ step: 'describe', resultBrief: 'skip-describe（无图）' });
    }
    if (!desc) {
      // 无参考描述时构造最简占位（供 poseRefSheet 骨架，避免崩溃）
      desc = {
        global: { subject: topic || '未知', mood: '', season: '', timeOfDay: '', palette: { dominant: [], tone: '', brightness: '' }, light: {}, composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '', negativeSpace: '', depthOfField: '' }, reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' } },
        people: [],
        scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
        cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
      };
    }

    // (4) 姿势参考面片
    const poseSheet = (await this.wrapStep<PoseRefSheet>('poseRefSheet', 'pose-ref-sheet', trace, () =>
      this.poseRefSheet.generate(desc as ImageDescription, Math.max(1, input.poseCount ?? 1), input.creationReq),
    )) ?? { shared: {} as PoseRefSheet['shared'], perPose: [] };

    // (5)+(6) 参数校准 + 评分闸门（再判 ≤ MAX_SCORE_ITERATIONS）
    let workingDraft = initialDraft;
    for (let i = 0; i < MAX_SCORE_ITERATIONS; i++) {
      const validated = await this.wrapStep('paramValidate', 'param-validate', trace, () =>
        this.paramValidate.validate(workingDraft),
      );
      if (validated) {
        workingDraft = validated.corrected;
        warnings.push(...validated.adjustments);
      }

      const scoreInput: ImageScoreInput = {
        desc: desc as ImageDescription,
        poseSheet,
        research,
        draft: workingDraft,
      };
      const scored = await this.wrapStep<{ score: number; verdict: 'pass' | 'retry' }>(
        'imageScore', 'image-score', trace, () => this.imageScore.score(scoreInput),
      );
      const result = scored ?? { score: 0, verdict: 'retry' as const };
      const last = trace[trace.length - 1];
      if (last && last.step === 'imageScore') last.score = result.score;
      if (result.verdict === 'pass') break;
      warnings.push(`评分 ${result.score} 低于闸门，进行第 ${i + 2} 次再校验`);
    }

    // (6.5) 姿势参考面片写入草稿定稿（此前仅用于评分；供 normalize 透传下发）
    workingDraft = { ...workingDraft, poseRefSheet: poseSheet };

    // (7) 定稿归一化（fail-safe：categories 必传，输入为 object）
    const normalized = normalizeDraft(workingDraft, categories);
    return { draft: normalized.draft, warnings: [...normalized.warnings, ...warnings], trace, research };
  }

  /** wrap 工具调用：成功返回其值，失败记录 trace 并返回 undefined（降级继续） */
  private async wrapStep<T>(
    step: string,
    tool: string,
    trace: OrchestratorTraceEntry[],
    fn: () => T | Promise<T>,
  ): Promise<T | undefined> {
    try {
      const value = await fn();
      const brief = this.brief(value);
      trace.push({ step, tool, resultBrief: brief });
      return value;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      trace.push({ step, tool, resultBrief: `fail: ${msg}` });
      return undefined;
    }
  }

  private brief(v: unknown): string {
    if (Array.isArray(v)) return `${v.length} 条目`;
    if (v && typeof v === 'object') {
      const keys = Object.keys(v);
      return keys.length ? `${keys.join(',')} 字段` : '对象';
    }
    return String(v);
  }
}