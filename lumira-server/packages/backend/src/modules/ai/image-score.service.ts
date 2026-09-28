// lumira-server/packages/backend/src/modules/ai/image-score.service.ts
// T6 LLM-as-Judge 评分闸门（Task 8）：对封面/姿势/最终模板打分并给可执行反馈，驱动 retry loop
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T6
//
// 评分维度：与参考/意图逐项一致性、风格成熟度、审美、物理合理性、参数与图像自洽、
// 可实拍复现度、姿势间区分度、元数据质量。textChatJson（jsonMode + 有界重试）解析 → 分数 clamp [0,1]。
// 低分/非法 JSON → 保守 retry（不抛），闸门阈值见 SCORE_PASS_THRESHOLD。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import type { LlmEndpoint } from './llm-client';
import { textChatJson, LlmJsonError } from './llm-json';
import { resolveTextTools } from './tools/text-tools';
import { clampNumber } from './normalize';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import type { ResearchItem } from './trend-research/research-item';
import { renderStyleProfileBlock, normalizeStyleProfile, type StyleProfile } from './style-profile.presets';

/** 通过闸门：score >= 该值 → pass，否则 retry */
export const SCORE_PASS_THRESHOLD = 0.85;

/** 审美分项：画面是否「好看且命中档案取向」 */
export interface AestheticsScores {
  composition: number; // 构图
  pose: number; // 姿势线条与设计感
  styling: number; // 穿搭/妆造
  expression: number; // 表情与情绪
  lighting: number; // 光线层次
  styleHit: number; // 是否命中风格档案取向
}

/** 真实分项：不可突破的底线 */
export interface RealismScores {
  anatomy: number; // 人体/结构解剖
  material: number; // 材质（皮肤/布料/道具）
  physical: number; // 物理合理性（光/透视/可实拍）
}

export const AESTHETICS_KEYS: (keyof AestheticsScores)[] = [
  'composition',
  'pose',
  'styling',
  'expression',
  'lighting',
  'styleHit',
];
export const REALISM_KEYS: (keyof RealismScores)[] = ['anatomy', 'material', 'physical'];

/** 解析分项：任一键缺失/非数值 → undefined（视为未达标，保守 retry） */
export function parseScoreGroup<T extends string>(raw: unknown, keys: readonly T[]): Record<T, number> | undefined {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return undefined;
  const src = raw as Record<string, unknown>;
  const out = {} as Record<T, number>;
  for (const k of keys) {
    const v = src[k];
    if (typeof v !== 'number' || !Number.isFinite(v)) return undefined;
    out[k] = Math.max(0, Math.min(1, v));
  }
  return out;
}

export interface GateInput {
  score: number;
  aesthetics?: AestheticsScores;
  realism?: RealismScores;
  textOnly?: boolean;
}

/** 三段闸门：总分 + 审美分项 + 真实分项；无图路径放宽审美与总分，真实底线不变 */
export function evaluateGate(input: GateInput): { pass: boolean; fails: string[] } {
  const fails: string[] = [];
  const scoreThreshold = input.textOnly ? 0.8 : SCORE_PASS_THRESHOLD;
  const aestheticsMin = input.textOnly ? 0.7 : 0.75;
  const realismMin = 0.85;

  if (input.score < scoreThreshold) fails.push(`总分 ${input.score.toFixed(2)} < ${scoreThreshold}`);
  if (!input.aesthetics) fails.push('审美分项缺失');
  else {
    for (const k of AESTHETICS_KEYS) {
      if (input.aesthetics[k] < aestheticsMin) {
        fails.push(`审美维度 ${k}=${input.aesthetics[k].toFixed(2)} < ${aestheticsMin}`);
      }
    }
  }
  if (!input.realism) fails.push('真实分项缺失');
  else {
    for (const k of REALISM_KEYS) {
      if (input.realism[k] < realismMin) {
        fails.push(`真实底线 ${k}=${input.realism[k].toFixed(2)} < ${realismMin}`);
      }
    }
  }
  return { pass: fails.length === 0, fails };
}

export interface ScoreResult {
  /** 综合质量分 0~1 */
  score: number;
  /** 闸门结论：pass（三段闸门全过）| retry（任一段不达标或解析失败） */
  verdict: 'pass' | 'retry';
  /** 未达标的高优先级差异/问题清单（LLM reasons + 闸门 fails） */
  reasons: string[];
  /** 可执行的改进建议（供决策层微调后重跑） */
  suggests: string[];
  /** 审美分项（供 trace 与后台时间线展示） */
  aesthetics?: AestheticsScores;
  /** 真实分项（供 trace 与后台时间线展示） */
  realism?: RealismScores;
}

export interface ImageScoreInput {
  /** T2 参考图穷尽描述（期望值） */
  desc: ImageDescription;
  /** T3 姿势参考面片 */
  poseSheet: PoseRefSheet;
  /** T1 趋势研究条目 */
  research: ResearchItem[];
  /** 当前候选模板草稿 */
  draft: Record<string, unknown>;
  /** 生成图再走一次 T2 的识别结果（可选；有则做逐项一致性差异） */
  imageDescOfGenerated?: Record<string, unknown>;
  /** 独立的评审模型端点（避免同源偏好）；缺省用 cfg.text */
  judgeModel?: LlmEndpoint;
  /** 本次风格档案（可选；有则注入档案约束块并核对 styleHit） */
  styleProfile?: StyleProfile;
  /** 无参考图路径（纯草稿评审）：放宽审美与总分阈值，真实底线不变 */
  textOnly?: boolean;
}

/** 评分 rubric 系统提示；有档案时追加档案约束块 */
function buildScoreSystemPrompt(styleProfile?: StyleProfile): string {
  return [
    '你是资深摄影/时尚编辑，负责为生成的摄影模板做质量与一致性评审（LLM-as-Judge）。',
    '## 评分维度',
    '1. 逐项一致性：生成图识别结果 vs 参考图描述的差异（人物动作/表情/穿搭、光线/色温、构图锚点、场景逐层）',
    '   给出 itemByItem 差异清单（在有 imageDescOfGenerated 时重点核对）。',
    '2. 风格成熟度：模板名/描述/关键词/场景引导/难度分级的可读性与可搜索性。',
    '3. 审美与构图：主体框位、比例、留白、色调是否协调。',
    '4. 物理合理性：肢体/光影/纹理是否自然，无畸形。',
    '5. 参数与图像自洽：composition/camera/postProcess 参数能否复现画面。',
    '6. 可实拍复现度：画面是否包含手机拍不出的东西（无源光、不可能的透视/姿势）。',
    '7. 姿势间区分度：多姿势是否雷同（应借助 poseSheet.differentiationNote 判断）。',
    '8. 元数据质量：命名、关键词、sceneGuide、难度是否给用户可操作。',
    '## 输出',
    '只输出 JSON，不要 markdown 或解释：',
    '{"aesthetics":{"composition":0~1,"pose":0~1,"styling":0~1,"expression":0~1,"lighting":0~1,"styleHit":0~1},' +
      '"realism":{"anatomy":0~1,"material":0~1,"physical":0~1},' +
      '"score":0~1,"reasons":["差异/问题清单"],"suggests":["可执行改进建议"]}',
    'AestheticsScores 与 RealismScores 的每个分项都必须给出数值，不得省略。',
    '`suggests` 必须落到具体字段与具体补法，例如「pose[0].description 缺表情与左手落点，补：嘴角放松上提、左手扶帽檐」；禁止「提升美感」「优化构图」这类空话。',
    '审查时按【风格档案】核对 styleHit：画面是否命中该档案取向；retouchLevel=none 时若出现影棚布光感，styleHit 记不达标。',
    '真实底线分项（anatomy/material/physical）不因任何风格取向放宽。',
    styleProfile ? renderStyleProfileBlock(styleProfile) : '',
  ]
    .filter(Boolean)
    .join('\n');
}

/** 组装用户输入：提取对评审有意义的浓缩信息（不塞整图进文本循环） */
function buildScoreUserText(input: ImageScoreInput): string {
  const { desc, poseSheet, research, draft, imageDescOfGenerated } = input;

  return [
    '## 参考图穷尽描述（期望值）',
    JSON.stringify({
      global: desc.global,
      people: desc.people.map((p) => ({ role: p.role, face: p.face, body: p.body, outfit: p.outfit, anchors: p.anchors })),
      scene: desc.scene,
      cameraLike: desc.cameraLike,
    }),
    '',
    '## 姿势参考面片',
    JSON.stringify({ shared: poseSheet.shared, perPose: poseSheet.perPose.map((p) => ({ name: p.name, differentiationNote: p.differentiationNote })) }),
    '',
    '## 趋势研究摘要',
    JSON.stringify(research.map((r) => ({ source: r.source, title: r.title, snippet: r.snippet, keywords: r.keywords }))),
    '',
    '## 候选模板草稿',
    JSON.stringify(draft),
    imageDescOfGenerated ? `## 生成图二次识别（用于逐项一致性核对）\n${JSON.stringify(imageDescOfGenerated)}` : '',
  ].filter(Boolean).join('\n');
}

@Injectable()
export class ImageScoreService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /** 逐项一致性 + 总分/审美分项/真实分项三段闸门；不达标或解析失败 → 保守 retry 不抛 */
  async score(input: ImageScoreInput): Promise<ScoreResult> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const endpoint = input.judgeModel ?? cfg.text;
    const profile = input.styleProfile ? normalizeStyleProfile(input.styleProfile) : undefined;

    let json: Record<string, unknown> | null = null;
    try {
      json = await textChatJson(
        endpoint,
        {
          systemPrompt: buildScoreSystemPrompt(profile),
          userText: buildScoreUserText(input),
          temperature: 0.3,
          ctx: resolveTextTools(cfg),
        },
        cfg.runtime,
      );
    } catch (err) {
      // 仅「解析失败/重试用尽」走保守回退；鉴权等硬错误原样上抛（与 style-profile 对齐），
      // 交由编排层 wrapStep 记为 fail，trace 可见。
      if (err instanceof LlmJsonError) json = null;
      else throw err;
    }
    if (!json) {
      return { score: 0, verdict: 'retry', reasons: ['评分为空'], suggests: [] };
    }

    const rawScore =
      typeof json.score === 'number' && Number.isFinite(json.score)
        ? clampNumber(json.score, 0, 1) ?? 0
        : 0;
    const aesthetics = parseScoreGroup(json.aesthetics, AESTHETICS_KEYS);
    const realism = parseScoreGroup(json.realism, REALISM_KEYS);
    const reasons = Array.isArray(json.reasons)
      ? json.reasons.filter((s): s is string => typeof s === 'string')
      : [];
    const suggests = Array.isArray(json.suggests)
      ? json.suggests.filter((s): s is string => typeof s === 'string')
      : [];

    const gate = evaluateGate({ score: rawScore, aesthetics, realism, textOnly: input.textOnly });
    return {
      score: rawScore,
      verdict: gate.pass ? 'pass' : 'retry',
      reasons: [...reasons, ...gate.fails],
      suggests,
      ...(aesthetics ? { aesthetics } : {}),
      ...(realism ? { realism } : {}),
    };
  }
}