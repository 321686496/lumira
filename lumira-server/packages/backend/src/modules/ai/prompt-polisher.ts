// lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts
// 生图 prompt 润色：拼接 prompt → textChat 转写为专业摄影描述；失败静默回退（不阻塞生图）
// 设计文档：docs/specs/2026-09-10-ai-create-enhancement-design.md 第三节

import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';

const POLISH_SYSTEM_PROMPT = `你是专业摄影艺术指导。将给定的模板参数描述转写为一段高质量的中文生图提示词，融入光影氛围、镜头语言、色彩层次、景深质感等专业摄影表达。保留原有全部关键信息（主体、构图、风格、光线、背景、色调），只做表达升级，不新增与模板无关的元素。直接输出转写后的提示词，不要任何解释。`;

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
