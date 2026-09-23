// lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts
// T6 评分闭环：把评审 suggestions 喂回草稿做收敛修正（retry loop 的"改进步"）。
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T6 / 4.3
//
// 定位：imageScore 只"评"不改；本服务按评审建议修订一份新的模板草稿并返回。
// 收敛语义：只向着评审指出的方向调整 draft + 保证自洽，不推翻未涉及的创意锚点。
// 失败策略：解析失败/非对象 → 返回 null，由编排层决定（保留原稿，避免降质覆盖）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import { extractJson } from './normalize';
import { describeTodayUtc8 } from '../../common/utils/date.util';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import type { ResearchItem } from './trend-research/research-item';

/** 细化输入：当前草稿 + 评审建议 + 上下文锚点（保证随调不改创意） */
export interface DraftRefineInput {
  /** 当前候选模板草稿 */
  draft: Record<string, unknown>;
  /** 评审给出的可执行改进建议 */
  suggests: string[];
  desc: ImageDescription;
  poseSheet: PoseRefSheet;
  research: ResearchItem[];
  /** 独立评审/细化模型端点；缺省用 cfg.text */
  judgeModel?: LlmEndpoint;
}

function buildRefineSystemPrompt(): string {
  return [
    '你是资深摄影/时尚编辑，负责把评审反馈落实到模板草稿中得到一份改进稿（闭环收敛）。',
    describeTodayUtc8(),
    '## 守则',
    '1. 只按评审 suggested 指出的方向做调整；未涉及的字段尽量保留（不随意推翻创意锚点）。',
    '2. 情感/风格/姿势/场景等创意方向必须与参考描述、姿势面片自洽，不得凭空引入相冲突元素。',
    '3. 数值参数（camera/composition/postProcess）保持在 App 实拍域内，后续由 paramValidate 再夹取。',
    '4. 保持与当前草稿相同的 JSON 结构（模板契约），不增删关键业务字段。',
    '5. 涉及节日/时令/季节的表述必须以今天日期为准，并用「年份 + 节日名 + 公历日期」写具体；',
    '   不得凭记忆使用已过期的节日（如把近期节日写成端午）或无法核验的日期，草稿里没有依据的时效信息保持原样、不要新增。',
    '## 输出',
    '只输出 JSON：{"draft": {改进后的完整草稿对象}}，不要 markdown 或解释。',
  ].join('\n');
}

function buildRefineUserText(input: DraftRefineInput): string {
  const { draft, suggests, desc, poseSheet, research } = input;
  return [
    '## 评审建议（必须落实方向）',
    suggests.length ? suggests.join('\n') : '（无建议：保持现状即可）',
    '',
    '## 参考描述浓缩',
    JSON.stringify({ subject: desc.global.subject, mood: desc.global.mood, scene: desc.scene.location }),
    '',
    '## 姿势面片（共享锚点 + 姿势名）',
    JSON.stringify({ shared: poseSheet.shared, perPose: poseSheet.perPose.map((p) => ({ name: p.name, differentiationNote: p.differentiationNote })) }),
    '',
    '## 趋势关键词',
    JSON.stringify([...new Set(research.flatMap((r) => r.keywords ?? []))].slice(0, 30)),
    '',
    '## 当前草稿',
    JSON.stringify(draft),
  ].join('\n');
}

@Injectable()
export class DraftRefineService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /** 按评审建议修订草稿；解析失败/非对象 → null（编排层保留原稿） */
  async refine(input: DraftRefineInput): Promise<Record<string, unknown> | null> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const endpoint = input.judgeModel ?? cfg.text;

    let content: string;
    try {
      content = await textChat(endpoint, {
        systemPrompt: buildRefineSystemPrompt(),
        userText: buildRefineUserText(input),
        temperature: 0.5,
        jsonMode: true,
        timeoutMs: 120_000,
      });
    } catch {
      return null;
    }

    const json = extractJson(content);
    const inner = json?.draft;
    if (!inner || typeof inner !== 'object' || Array.isArray(inner)) return null;
    return inner as Record<string, unknown>;
  }
}