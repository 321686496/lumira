// lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts
// 生图 prompt 润色：拼接 prompt → textChat 转写为专业摄影描述；失败静默回退（不阻塞生图）
// 设计文档：docs/specs/2026-09-10-ai-create-enhancement-design.md 第三节

import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';

const POLISH_SYSTEM_PROMPT = `你是专业摄影艺术指导。将给定的模板参数描述转写为一段高质量的中文生图提示词，融入光影氛围、镜头语言、色彩层次、景深质感等专业摄影表达。输出必须强调「真实相机随手抓拍」的实拍质感与自然可信度，抑制明显的 AI 合成与精修痕迹：人是真实普通人而非精修模特——皮肤手工保留真实的毛孔、纹理与轻微瑕疵，不做美颜磨皮、绝不塑料感；光影来自真实环境与自然光、明暗过渡自然，不做影棚式精修布光；眉毛/手部/肢体不畸变；光线、色彩、景深贴近真实相机直出。保留原有全部关键信息（主体、构图、风格、光线、背景、色调），只做表达升级，不新增与模板无关的元素。直接输出转写后的提示词，不要任何解释。`;

export interface PolishResult {
  prompt: string;
  polished: boolean;
}

/**
 * 润色生图 prompt。永不抛错：textChat 失败/超时/空白输出时返回原始 prompt。
 */
export async function polishPrompt(textEndpoint: LlmEndpoint, rawPrompt: string): Promise<PolishResult> {
  try {
    const out = await textChat(textEndpoint, {
      systemPrompt: POLISH_SYSTEM_PROMPT,
      userText: rawPrompt,
      temperature: 0.4,
      timeoutMs: 30_000,
    });
    const trimmed = out.trim();
    if (!trimmed) return { prompt: rawPrompt, polished: false };
    return { prompt: trimmed, polished: true };
  } catch {
    return { prompt: rawPrompt, polished: false };
  }
}
