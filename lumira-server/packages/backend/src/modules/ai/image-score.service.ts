// lumira-server/packages/backend/src/modules/ai/image-score.service.ts
// T6 LLM-as-Judge 评分闸门（Task 8）：对封面/姿势/最终模板打分并给可执行反馈，驱动 retry loop
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T6
//
// 评分维度：与参考/意图逐项一致性、风格成熟度、审美、物理合理性、参数与图像自洽、
// 可实拍复现度、姿势间区分度、元数据质量。textChat(jsonMode:true) 解析 → 分数 clamp [0,1]。
// 低分/非法 JSON → 保守 retry（不抛），闸门阈值见 SCORE_PASS_THRESHOLD。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import { extractJson, clampNumber } from './normalize';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import type { ResearchItem } from './trend-research/research-item';

/** 通过闸门：score >= 该值 → pass，否则 retry */
export const SCORE_PASS_THRESHOLD = 0.85;

export interface ScoreResult {
  /** 综合质量分 0~1 */
  score: number;
  /** 闸门结论：pass（>=阈值）| retry（低于阈值或解析失败） */
  verdict: 'pass' | 'retry';
  /** 未达标的高优先级差异/问题清单 */
  reasons: string[];
  /** 可执行的改进建议（供决策层微调后重跑） */
  suggests: string[];
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
}

/** 评分 rubric 系统提示 */
function buildScoreSystemPrompt(): string {
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
    '{"score": 0~1, "reasons": ["差异/问题清单"], "suggests": ["可执行改进建议"]}',
    'score<0.85 时必须在 reasons 列出未达标的具体项，并在 suggests 给出决策层可执行的微调方向。',
  ].join('\n');
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

  /** 逐项一致性 + 多维质量评分；低分/解析失败 → 保守 retry 不抛 */
  async score(input: ImageScoreInput): Promise<ScoreResult> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const endpoint = input.judgeModel ?? cfg.text;

    const content = await textChat(endpoint, {
      systemPrompt: buildScoreSystemPrompt(),
      userText: buildScoreUserText(input),
      temperature: 0.3,
      jsonMode: true,
      timeoutMs: 120_000,
    });

    const json = extractJson(content);
    if (!json) {
      return { score: 0, verdict: 'retry', reasons: ['评分为空'], suggests: [] };
    }

    const rawScore =
      typeof json.score === 'number' && Number.isFinite(json.score)
        ? clampNumber(json.score, 0, 1) ?? 0
        : 0;
    const reasons = Array.isArray(json.reasons)
      ? json.reasons.filter((s): s is string => typeof s === 'string')
      : [];
    const suggests = Array.isArray(json.suggests)
      ? json.suggests.filter((s): s is string => typeof s === 'string')
      : [];

    return {
      score: rawScore,
      verdict: rawScore >= SCORE_PASS_THRESHOLD ? 'pass' : 'retry',
      reasons,
      suggests,
    };
  }
}