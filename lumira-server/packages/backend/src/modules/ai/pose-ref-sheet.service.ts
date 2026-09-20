// lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts
// T3 姿势参考面片服务（Task 6）：textChat 生成「shared 共享锚点 + perPose 差异项」姿势参考面片
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T3
//
// 跨姿势一致性铁律：同模板多姿势共享 shared.outfit/scene/light/aspectRatio/mood/palette，
// 仅动作/机位/框位可变，且每姿势必须有 differentiationNote（避免雷同）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { textChat } from './llm-client';
import { extractJson } from './normalize';
import type { ImageDescription } from './image-describe.service';

// ===== PoseRefSheet 契约 =====

export interface PosePerPose {
  name: string;
  subjectPose: Record<string, unknown>;
  camera: Record<string, unknown>;
  frame: Record<string, unknown>;
  lightOnPose: Record<string, unknown>;
  /** ★ 本姿势与其他姿势的差异说明（必须非空，保证不一致） */
  differentiationNote: string;
}

export interface PoseRefSheet {
  /** 跨姿势共享锚点（同一模板所有姿势必须一致） */
  shared: {
    outfit: string;
    scene: string;
    light: string;
    aspectRatio: string;
    mood: string;
    palette: string;
  };
  perPose: PosePerPose[];
}

const SHARED_KEYS = ['outfit', 'scene', 'light', 'aspectRatio', 'mood', 'palette'] as const;

function str(v: unknown): string {
  return typeof v === 'string' && v.trim() ? v.trim() : '';
}

/** 归一化：shared 锚点兜底、perPose 截断到 poseCount、diffNote 保证非空或补默认 */
export function normalizePoseRefSheet(raw: unknown, poseCount: number): PoseRefSheet {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const rawShared = (o.shared && typeof o.shared === 'object' ? o.shared : {}) as Record<string, unknown>;
  const shared: PoseRefSheet['shared'] = {} as PoseRefSheet['shared'];
  for (const k of SHARED_KEYS) shared[k] = str(rawShared[k]);

  const perPose: PosePerPose[] = Array.isArray(o.perPose)
    ? o.perPose.map((p) => {
        const pp = p && typeof p === 'object' ? (p as Record<string, unknown>) : {};
        return {
          name: str(pp.name),
          subjectPose: pp.subjectPose && typeof pp.subjectPose === 'object' ? (pp.subjectPose as Record<string, unknown>) : {},
          camera: pp.camera && typeof pp.camera === 'object' ? (pp.camera as Record<string, unknown>) : {},
          frame: pp.frame && typeof pp.frame === 'object' ? (pp.frame as Record<string, unknown>) : {},
          lightOnPose: pp.lightOnPose && typeof pp.lightOnPose === 'object' ? (pp.lightOnPose as Record<string, unknown>) : {},
          differentiationNote: str(pp.differentiationNote),
        };
      })
    : [];

  // 硬护栏：不同姿势必须有差异说明
  for (const p of perPose) {
    if (!p.differentiationNote) p.differentiationNote = `姿势「${p.name || '未命名'}」在动作/机位上与其他姿势不同`;
  }

  // 长度对齐：截断到 poseCount（不足时保持原样，不编造姿势）
  const bounded = perPose.slice(0, Math.max(1, poseCount));

  return { shared, perPose: bounded };
}

@Injectable()
export class PoseRefSheetService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 基于穷尽识别描述 + 用户姿势要求，生成 poseCount 个姿势的参考面片。
   * textChat(jsonMode) → extractJson → normalizePoseRefSheet。
   */
  async generate(desc: ImageDescription, poseCount: number, userReq?: string): Promise<PoseRefSheet> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const systemPrompt = [
      '你是资深人像摄影引导师。基于给出的「图像穷尽描述」，为该模板生成一张姿势参考面片（poseRefSheet）。',
      '## 共享锚点铁律',
      '同一模板内的多个姿势必须共享同一套递增锚点：shared.outfit(统一穿搭) / shared.scene(统一场景) /',
      'shared.light(统一光线) / shared.aspectRatio(统一比例) / shared.mood(统一氛围) / shared.palette(统一色板)。',
      '只允许在 perPose 里变动作、机位、框位；不得改变人物长相、服装、发型、体型、场景、道具、光线或整体风格。',
      '## 差异度要求',
      '每个姿势必须有与其它姿势不同的 differentiationNote（动作/机位/框位差异），保证多姿势不雷同。',
      '## 可复现约束',
      '面片只允许出现手机实拍能呈现的姿势/光线/构图；与 fillLight/subjectFrame/aspectRatio 数值自洽。',
      '只输出 JSON，不要 markdown 或解释。',
    ].join('\n');
    const userText = [
      `需要生成 ${poseCount} 个姿势的参考面片。`,
      `图像穷尽描述摘要：${JSON.stringify({ global: desc.global, people: desc.people.map((p) => ({ role: p.role, outfit: p.outfit })), scene: desc.scene, cameraLike: desc.cameraLike })}`,
      userReq ? `用户姿势要求：${userReq}` : '',
      '请按系统提示的 PoseRefSheet 结构输出，每姿势含不同 differentiationNote。',
    ].filter(Boolean).join('\n');

    const content = await textChat(cfg.text, {
      systemPrompt,
      userText,
      temperature: 0.4,
      jsonMode: true,
      timeoutMs: 120_000,
    });
    const json = extractJson(content);
    if (!json) {
      throw new Error('姿势参考面片无法解析为 JSON，请重试');
    }
    return normalizePoseRefSheet(json, poseCount);
  }
}