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
import { renderStyleProfileBlock, type StyleProfile } from './style-profile.presets';

// ===== PoseRefSheet 契约 =====

/** 单张姿势的字段级契约（全部字符串，缺失补齐默认值） */
export interface SubjectPose {
  /** 下巴高低与视线方向 */
  headFraming: string;
  /** 躯干朝向与转动角度 */
  torsoTwist: string;
  /** 肩胯错位 */
  shoulderHipOffset: string;
  /** 左右手分别的动作与落点 */
  armAndHand: string;
  /** 重心与支撑腿 */
  legStance: string;
  /** 本张表情 */
  expression: string;
}

export const SUBJECT_POSE_KEYS: (keyof SubjectPose)[] = [
  'headFraming',
  'torsoTwist',
  'shoulderHipOffset',
  'armAndHand',
  'legStance',
  'expression',
];

const SUBJECT_POSE_FALLBACK: SubjectPose = {
  headFraming: '下巴略收，视线看向侧前方，颈部线舒展',
  torsoTwist: '躯干侧转约 1/4 朝向镜头',
  shoulderHipOffset: '肩线与胯线错开，靠近镜头一侧肩略低',
  armAndHand: '左手自然下垂或轻搭身侧，右手抬起有明确落点',
  legStance: '重心落在后侧腿，前腿放松伸出',
  expression: '表情放松自然，嘴角微松，眼神有明确落点',
};

/** 归一化单张姿势：缺失键补齐默认值（无论原值有无都保证 6 键齐全） */
export function normalizeSubjectPose(raw: unknown): Partial<SubjectPose> {
  const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
  const src = isObj(raw) ? raw : {};
  const out: Partial<SubjectPose> = {};
  for (const key of SUBJECT_POSE_KEYS) {
    const v = src[key];
    out[key] = typeof v === 'string' && v.trim() ? v.trim() : SUBJECT_POSE_FALLBACK[key];
  }
  return out;
}

export interface PosePerPose {
  name: string;
  subjectPose: Partial<SubjectPose>;
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
    /** 统一妆造/穿搭（跨姿势一致） */
    styling: string;
    /** 统一表情与情绪（跨姿势一致） */
    expressionMood: string;
  };
  perPose: PosePerPose[];
}

const SHARED_KEYS = ['outfit', 'scene', 'light', 'aspectRatio', 'mood', 'palette', 'styling', 'expressionMood'] as const;

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
          subjectPose: normalizeSubjectPose(pp.subjectPose),
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
  async generate(desc: ImageDescription, poseCount: number, userReq?: string, styleProfile?: StyleProfile): Promise<PoseRefSheet> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const systemPrompt = [
      '你是资深人像摄影引导师。基于给出的「图像穷尽描述」，为该模板生成一张姿势参考面片（poseRefSheet）。',
      '## 共享锚点铁律',
      '同一模板内的多个姿势必须共享同一套递增锚点：shared.outfit(统一穿搭) / shared.scene(统一场景) /',
      'shared.light(统一光线) / shared.aspectRatio(统一比例) / shared.mood(统一氛围) / shared.palette(统一色板) /',
      'shared.styling(统一妆造与穿搭细节) / shared.expressionMood(统一表情与情绪)。',
      '只允许在 perPose 里变动作、机位、框位；不得改变人物长相、服装、发型、体型、场景、道具、光线或整体风格。',
      '## 差异度要求',
      '每个姿势必须有与其它姿势不同的 differentiationNote（动作/机位/框位差异），保证多姿势不雷同。',
      '## 姿势线条要求（强制）',
      '姿势必须"有设计感的线条"：避免正面僵直、双手对称、关节正对镜头、手臂紧贴身体。',
      '每个姿势的 subjectPose 必须逐项写全 headFraming（下巴高低/视线方向）、torsoTwist（躯干朝向与转动角度）、' +
        'shoulderHipOffset（肩胯错位）、armAndHand（左右手分别的动作与落点）、legStance（重心与支撑腿）、expression（本张表情）。',
      'shared 中的 styling 与 expressionMood 用于保证跨姿势一致。',
      '## 可复现约束',
      '面片只允许出现手机实拍能呈现的姿势/光线/构图；与 fillLight/subjectFrame/aspectRatio 数值自洽。',
      '只输出 JSON，不要 markdown 或解释。',
      styleProfile ? renderStyleProfileBlock(styleProfile) : '',
      '## 输出 JSON 结构示例',
      '{"shared":{"outfit":"","scene":"","light":"","aspectRatio":"","mood":"","palette":"","styling":"","expressionMood":""},',
      '"perPose":[{"name":"","differentiationNote":"","subjectPose":{"headFraming":"","torsoTwist":"","shoulderHipOffset":"","armAndHand":"","legStance":"","expression":""},"camera":{},"frame":{},"lightOnPose":{}}]}',
    ].filter(Boolean).join('\n');
    const userText = [
      `需要生成 ${poseCount} 个姿势的参考面片。`,
      `图像穷尽描述摘要：${JSON.stringify({ global: desc.global, people: desc.people.map((p) => ({ role: p.role, expression: p.expression, styling: p.styling, outfit: p.outfit })), scene: desc.scene, cameraLike: desc.cameraLike })}`,
      userReq ? `用户姿势要求：${userReq}` : '',
      '请按系统提示的 PoseRefSheet 结构输出，每姿势含不同 differentiationNote，且 subjectPose 六项写全。',
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