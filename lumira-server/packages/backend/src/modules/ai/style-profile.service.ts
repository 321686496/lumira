// 风格定位：判定本次创作的大类与风格取向档案（只判定一次，供全链路分流使用）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { textChatJson, LlmJsonError } from './llm-json';
import {
  defaultStyleProfile,
  normalizeStyleProfile,
  STYLE_ARCHETYPE_LABELS,
  type StyleProfile,
} from './style-profile.presets';

export interface StyleProfileInput {
  /** 用户文字描述（无参考图时的主输入） */
  text?: string;
  /** 创作要求（优先级高于 text） */
  creationReq?: string;
  /** 有参考图时的图像识别结果（可选，用于辅助风格判定） */
  desc?: unknown;
}

export interface StyleProfileResolveResult {
  profile: StyleProfile;
  source: 'llm' | 'fallback';
  /** 用于 trace 的一句话说明 */
  note: string;
}

const STYLE_RESOLVE_SYSTEM_PROMPT = `你是资深摄影/视觉总监，负责在创作开始前做一次「风格定位」。
你要判断本次创作属于哪个大类（category），以及应当采用哪一套风格取向档案（archetype）。

## category 取值（只能选一个）
portrait（人像）/ landscape（风景）/ food（美食）/ street（街拍）/ night（夜景）/ macro（微距）/ still-life（静物）

## archetype 取值（只能选一个）
fashion_editorial（时尚大片）/ photo_portrait（摄影写真）/ candid_lifestyle（随拍松弛）/
social_media_trendy（网感网红）/ documentary_street（纪实街拍）/ landscape_fine_art（风景意境）/ food_lifestyle（美食生活）

## retouchLevel 取值（只能选一个）
none（不做精修、自然随拍）/ light（轻精修、干净通透）/ polished（精致精修、大片调性）

## 判定原则
1. 以用户创作要求与文字描述为准；有图像识别结果时可参考其风格线索，但不得违背文字要求。
2. 不得为了「好看」而选择用户未要求的取向；用户没有明确取向时，选最贴近日常审美的一套。
3. 无论选哪一套，真实都是底线：不得输出反真实、反物理、反解剖的取向。

## 输出（严格 JSON，不要任何多余文字）
{
  "category": "portrait",
  "archetype": "fashion_editorial",
  "aestheticTarget": "一句话美学目标",
  "subjectStyling": "穿搭/妆造/材质/配饰要点（非人像可为空字符串）",
  "expressionMood": "表情与情绪（非人像可为空字符串）",
  "poseLanguage": "姿势语言（非人像可为空字符串）",
  "lightingSignature": "光比与光线特征",
  "compositionBias": "构图偏好",
  "paletteHint": "色调倾向",
  "retouchLevel": "polished",
  "extraNotes": "现场补充的个性细节，没有就空字符串"
}`;

@Injectable()
export class StyleProfileService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  async resolve(input: StyleProfileInput): Promise<StyleProfileResolveResult> {
    const request = (input.creationReq || '').trim() || (input.text || '').trim();
    const descBrief = input.desc ? JSON.stringify(input.desc).slice(0, 1500) : '';
    if (!request && !descBrief) {
      return {
        profile: defaultStyleProfile(),
        source: 'fallback',
        note: 'fail: 无创作要求与文字描述，使用默认档案（随拍松弛/人像）',
      };
    }

    const userText = [
      `创作要求：${(input.creationReq || '').trim() || '（未填写）'}`,
      `文字描述：${(input.text || '').trim() || '（未填写）'}`,
      descBrief ? `参考图识别结果（节选）：${descBrief}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      if (!cfg?.text) {
        return {
          profile: defaultStyleProfile(),
          source: 'fallback',
          note: 'fail: 未配置文本模型，使用默认档案（随拍松弛/人像）',
        };
      }
      const json = await textChatJson(
        cfg.text,
        { systemPrompt: STYLE_RESOLVE_SYSTEM_PROMPT, userText, temperature: 0.3 },
        cfg.runtime,
      );
      const profile = normalizeStyleProfile(json);
      return {
        profile,
        source: 'llm',
        note: `${STYLE_ARCHETYPE_LABELS[profile.archetype]}/${profile.category}/${profile.retouchLevel}`,
      };
    } catch (err) {
      const note = err instanceof LlmJsonError
        ? 'fail: 风格定位输出无法解析为 JSON（重试用尽），使用默认档案（随拍松弛/人像）'
        : `fail: 风格定位失败（${(err instanceof Error ? err.message : String(err)).slice(0, 120)}），使用默认档案（随拍松弛/人像）`;
      return { profile: defaultStyleProfile(), source: 'fallback', note };
    }
  }
}