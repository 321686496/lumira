// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
// 生图编排（Task 7）：草稿 JSON + 可选参考图 → buildImagePrompt → 文本模态润色（失败回退）→ generateImage（per-provider）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
//
// prompt 由后端统一构建（前端不拼 prompt）；qwen/zhipu 内部忽略参考图走文生图（image-client 分支处理）。

import { Injectable, BadRequestException } from '@nestjs/common';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { GenerateImageResult, generateImage, mapSize } from './image-client';
import { buildImagePrompt } from './image-prompt.builder';
import { polishPrompt } from './prompt-polisher';

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 草稿顶层 composition.aspectRatio 提取（缺失/非字符串 → undefined，mapSize 内兜底 1:1） */
function extractAspectRatio(draft: Record<string, unknown>): string | undefined {
  const composition = draft.composition;
  if (!isPlainObject(composition)) return undefined;
  const ratio = composition.aspectRatio;
  return typeof ratio === 'string' && ratio.trim() !== '' ? ratio.trim() : undefined;
}

@Injectable()
export class AiGenerateImageService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 生成模板效果图：取启用配置（未配置 503）→ 解析草稿 JSON（非法 400）→
   * 构建 prompt（可选附加用户额外要求）+ 厂商尺寸 → generateImage（有参考图时 doubao/openai 走图生图）
   */
  async generate(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
  ): Promise<GenerateImageResult> {
    // 1. 取启用配置（未配置/未启用 → 503 透传）
    const cfg = await this.aiConfigService.getActiveConfig();

    // 2. 解析草稿 JSON（非法/非对象 → 400 引导重传）
    let draft: Record<string, unknown> = {};
    if (metaJson !== null && metaJson !== undefined && metaJson !== '') {
      try {
        draft = JSON.parse(metaJson);
      } catch {
        throw new BadRequestException('meta 不是合法的 JSON，请检查草稿数据');
      }
      if (!isPlainObject(draft)) {
        throw new BadRequestException('meta 不是合法的 JSON，请检查草稿数据');
      }
    }

    // 3. 构建 prompt（extraPrompt = 用户附加提示词，拼在末尾；拼接 → 文本模态润色，失败回退拼接值）
    //    + 按厂商映射尺寸 → 生图（有参考图时 doubao/openai 走图生图）
    const rawPrompt = buildImagePrompt(draft, extraPrompt);
    const { prompt } = await polishPrompt(cfg.text, rawPrompt);
    return generateImage(cfg.image, {
      prompt,
      size: mapSize(cfg.image.provider, extractAspectRatio(draft)),
      referenceBase64: reference?.buffer.toString('base64'),
      referenceMime: reference?.mimetype,
    });
  }
}
