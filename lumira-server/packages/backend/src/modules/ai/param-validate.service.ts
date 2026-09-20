// lumira-server/packages/backend/src/modules/ai/param-validate.service.ts
// T5 参数-App 效果校准器（Task 7，纯函数规则层）：补光/拉腿/构图/色彩 clamp → 实拍≈期望
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T5
//
// 规则（可测、无 I/O）：以 App 实拍控件为准（enums.ts + photo_template.dart）：
// 1. 暗部/夜景/室内 → 默认开启补光 fillLight（enabled 暖色 + 强度），并与 wbSuggestion 自洽
// 2. legStretch>0 仅允许全身/半身姿势；否则归位 0
// 3. 所有数值 clamp 回 enums 合法区间（clampNumber 语义，postProcess 色彩 ±100 等）

import { clampNumber } from './normalize';

export interface ParamValidationResult {
  corrected: Record<string, unknown>;
  /** 记录哪些字段被修正及原因（供 trace/后台展示） */
  adjustments: string[];
}

/** 判定是否为暗部/夜景/室内场景（扫描 draft 文本字段，命中任一个关键词即真） */
const DARK_HINTS = ['夜景', '夜晚', '暗', '室内', '夜', '傍晚', '隧道', '酒吧'];

function isDarkScene(draft: Record<string, unknown>): boolean {
  const pool: string[] = [];
  const collect = (v: unknown): void => {
    if (typeof v === 'string') pool.push(v);
    else if (Array.isArray(v)) v.forEach(collect);
    else if (v && typeof v === 'object') Object.values(v).forEach(collect);
  };
  collect(draft);
  return DARK_HINTS.some((h) => pool.some((s) => s.includes(h)));
}

/** 姿势是否适合拉腿（含全身/半身 关键词，且不含 特写/近景/大头/局部） */
function supportsLegStretch(draft: Record<string, unknown>): boolean {
  const fullBody = ['全身', '半身', '七分身', '四分身', '站', '坐', '蹲'].some((k) =>
    JSON.stringify(draft.pose ?? '').includes(k),
  );
  const excludes = ['特写', '近景', '大头', '局部', '肩部以上'].some((k) =>
    JSON.stringify(draft.pose ?? '').includes(k),
  );
  return fullBody && !excludes;
}

export class ParamValidateService {
  validate(draft: Record<string, unknown>): ParamValidationResult {
    const corrected: Record<string, unknown> = JSON.parse(JSON.stringify(draft));
    const adjustments: string[] = [];

    const postLocations = ['postProcess', 'composition.postProcess'] as const;
    const getPost = () => {
      for (const loc of postLocations) {
        const target = loc === 'postProcess' ? corrected : (corrected.composition as Record<string, unknown> | undefined);
        if (loc === 'postProcess' && corrected[loc] && typeof corrected[loc] === 'object') return corrected[loc] as Record<string, unknown>;
        if (loc === 'composition.postProcess' && target && target[loc.split('.')[1]] && typeof target[loc.split('.')[1]] === 'object') {
          return target[loc.split('.')[1]] as Record<string, unknown>;
        }
      }
      return null;
    };

    // 确保存在 postProcess 位置（优先 composition.postProcess）
    const comp = (corrected.composition && typeof corrected.composition === 'object' ? corrected.composition : {}) as Record<string, unknown>;
    if (!comp.postProcess || typeof comp.postProcess !== 'object') comp.postProcess = {};
    const post = comp.postProcess as Record<string, unknown>;
    corrected.composition = comp;

    // 1. 补光：暗部/夜景/室内 默认开
    if (isDarkScene(corrected)) {
      const existing = post.fillLight && typeof post.fillLight === 'object' ? (post.fillLight as Record<string, unknown>) : {};
      if (existing.enabled !== true) {
        existing.enabled = true;
        existing.color = typeof existing.color === 'string' ? existing.color : 'warm';
        existing.intensity = typeof existing.intensity === 'number' ? existing.intensity : 0.6;
        // 与 cameraLike.wbSuggestion 自洽：补暖光
        adjustments.push('暗部/夜景/室内场景默认开启补光 fillLight(warm,0.6)');
      }
      post.fillLight = existing;
    }

    // 2. legStretch：仅全身/半身姿势保留 >0，否则归位 0
    const rawLeg = post.legStretch;
    if (typeof rawLeg === 'number' && rawLeg > 0) {
      if (!supportsLegStretch(corrected)) {
        post.legStretch = 0;
        adjustments.push(`legStretch=${rawLeg} 仅适用于全身/半身姿势，当前姿势不适合拉腿，已归位为 0`);
      }
    }

    // 3. 数值 clamp：postProcess.color 各轴 ±100；smooth/sharpen/vignette/grain 0~100
    const color = post.color && typeof post.color === 'object' ? (post.color as Record<string, unknown>) : undefined;
    if (color) {
      for (const k of ['brightness', 'contrast', 'saturation', 'temperature', 'tint', 'highlights', 'shadows']) {
        const raw = color[k];
        if (typeof raw === 'number') {
          const clamped = Math.min(100, Math.max(-100, raw));
          if (clamped !== raw) {
            color[k] = clamped;
            adjustments.push(`postProcess.color.${k}=${raw} 越界，已夹取为 ${clamped}`);
          }
        }
      }
    }
    for (const k of ['smoothStrength', 'sharpen', 'vignette', 'grain']) {
      const raw = post[k];
      if (typeof raw === 'number') {
        const clamped = Math.min(100, Math.max(0, raw));
        if (clamped !== raw) {
          post[k] = clamped;
          adjustments.push(`postProcess.${k}=${raw} 越界，已夹取为 ${clamped}`);
        }
      }
    }
    // camera.iso 50~25600 / exposureCompensation -3~3（clampNumber 语义）
    const camera = corrected.camera && typeof corrected.camera === 'object' ? (corrected.camera as Record<string, unknown>) : undefined;
    if (camera) {
      for (const [k, min, max] of [['iso', 50, 25600], ['exposureCompensation', -3, 3]] as const) {
        if (typeof camera[k] === 'number') {
          const clamped = Math.min(max, Math.max(min, camera[k] as number));
          if (clamped !== camera[k]) {
            camera[k] = clamped;
            adjustments.push(`camera.${k}=${camera[k]} 越界，已夹取为 ${clamped}`);
          }
        }
      }
    }

    return { corrected, adjustments };
  }
}