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
import type { ResearchResult } from './trend-research/trend-research.service';
import { ImageDescribeService } from './image-describe.service';
import type { ImageDescription } from './image-describe.service';
import { PoseRefSheetService } from './pose-ref-sheet.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import { ParamValidateService } from './param-validate.service';
import { ImageScoreService } from './image-score.service';
import type { ImageScoreInput } from './image-score.service';
import { DraftRefineService } from './draft-refine.service';
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

/** run 可选依赖：categories 供 normalizeDraft；draft 为调用方（ai-analyze）已产出的初始草稿；research 为识别前置已搜出的结果（避免重复搜索） */
export interface OrchestratorRunOptions {
  categories: CategoryNode[];
  draft?: Record<string, unknown>;
  /** 识别阶段前置搜索的结果；数组（含空数组）= 已预计算，orchestrator 直接复用不再搜索 */
  research?: ResearchItem[];
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
    private readonly draftRefine: DraftRefineService,
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
    if (Array.isArray(opts.research)) {
      // 识别前置已搜出（ai-analyze 先搜后写草稿）→ 直接复用，trace 记录条数不重复搜索
      research = opts.research;
      trace.push({ step: 'research', tool: 'trend-research', resultBrief: `${research.length} 条（识别前置）` });
    } else if (!researchEnabled) {
      trace.push({ step: 'research', tool: 'trend-research', resultBrief: 'skip-research' });
    } else {
      const result = (await this.wrapStep<ResearchResult>('research', 'trend-research', trace, () =>
        this.trendResearch.research(topic, { limitPerSource: 5 }),
      ));
      if (result) {
        research = result.items;
        const errText = (result.sourceErrors?.length
          ? result.sourceErrors.map((e) => `${e.name}: ${e.error}`).join('; ')
          : '');
        const last = trace[trace.length - 1];
        if (last && last.step === 'research') {
          // 有命中：条数 + 失败来源详情；全部无命中：research-0（绝不误写 skip-research）
          last.resultBrief = result.items.length > 0
            ? `${result.items.length} 条` + (errText ? `；来源失败: ${errText}` : '')
            : `research-0: 来源无命中 (${errText || '全部来源为空'})`;
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
    // 收敛两件事同时做：retry 时把评审 suggests 喂回草稿细化（draft-refine）；历史最高分草稿兜底（bestDraft）。
    let workingDraft = initialDraft;
    let bestDraft = initialDraft;
    let bestScore = -1;
    for (let i = 0; i < MAX_SCORE_ITERATIONS; i++) {
      // 5 参数校准（规则裁剪；幂等——已合规则不改）
      const validated = await this.wrapStep('paramValidate', 'param-validate', trace, () =>
        this.paramValidate.validate(workingDraft),
      );
      if (validated) {
        workingDraft = validated.corrected;
        warnings.push(...validated.adjustments);
      }

      // 6 评分闸门
      const hasRefImage = Boolean(input.imageBase64 && input.imageMime);
      const scoreInput: ImageScoreInput = {
        desc: desc as ImageDescription,
        poseSheet,
        research,
        draft: workingDraft,
      };
      // 无参考图时无可评审的"图"，跳过 LLM 评分（避免对空 draft 硬调文本模型导致超时/504），直接收束为通过。
      let result: { score: number; verdict: 'pass' | 'retry'; suggests?: string[] };
      if (!hasRefImage) {
        trace.push({ step: 'imageScore', tool: 'image-score', resultBrief: 'skip-imageScore（无参考图）' });
        result = { score: 1, verdict: 'pass', suggests: [] };
        bestScore = 1;
        bestDraft = workingDraft; // 无图 break 前把已 paramValidate 的草稿写为最佳候选
        break; // 无图无需评审迭代，直接定稿
      }
      const scored = await this.wrapStep<{ score: number; verdict: 'pass' | 'retry'; suggests?: string[] }>(
        'imageScore', 'image-score', trace, () => this.imageScore.score(scoreInput),
      );
      result = scored ?? { score: 0, verdict: 'retry' as const };
      const last = trace[trace.length - 1];
      if (last && last.step === 'imageScore') last.score = result.score;

      // 保留历史最高分候选（避免最后取的却是更低分版本）
      if (result.score > bestScore) {
        bestScore = result.score;
        bestDraft = workingDraft;
      }
      if (result.verdict === 'pass') break;
      warnings.push(`评分 ${result.score} 低于闸门，进行第 ${i + 2} 次再校验`);

      // 6.5 retry 时按评审建议细化草稿（收敛），下一圈 paramValidate 再裁剪
      if (i < MAX_SCORE_ITERATIONS - 1) {
        const before = JSON.stringify(workingDraft);
        const refined = (await this.wrapStep<Record<string, unknown> | null>(
          'draftRefine', 'draft-refine', trace,
          () => this.draftRefine.refine({ draft: workingDraft, suggests: result.suggests ?? [], desc: desc as ImageDescription, poseSheet, research }),
        )) ?? null;
        if (refined && JSON.stringify(refined) !== before) {
          workingDraft = refined;
        } else {
          // 无法产生有效改进 → 停止空转，用已有最佳候选收束
          warnings.push(`评分 ${result.score} 低于闸门但无法生成有效改进，沿用最佳候选`);
          break;
        }
      }
    }

    // (6.5) 姿势参考面片写入最佳候选并定稿（此前仅用于评分；供 normalize 透传下发）
    workingDraft = { ...bestDraft, poseRefSheet: poseSheet };

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