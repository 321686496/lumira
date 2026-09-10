// lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts
// AI 识别编排（Task 5，Task 3 多输入增强）：示例图（可选）+ 文字描述（可选）→
// 有图走 visionChat（文字作补充要求）/ 仅文字走 textChat → extractJson → normalizeDraft
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节

import { Injectable, BadRequestException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { MAX_IMAGE_BYTES, UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { visionChat, textChat } from './llm-client';
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  buildTextOnlySystemPrompt,
  buildTextOnlyUserPrompt,
} from './analyze.prompt';
import { extractJson, normalizeDraft, CategoryNode } from './normalize';

/** 允许的示例图 mimetype */
const ALLOWED_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

@Injectable()
export class AiAnalyzeService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly aiConfigService: AiConfigService,
  ) {}

  /**
   * 示例图（可选）+ 文字描述（可选）→ 模板草稿：
   * 校验（至少一项；text ≤ 500 字）→ 读活跃分类树 → 取启用配置 →
   * 图存在走 visionChat（文字作补充要求）/ 仅文字走 textChat → JSON 容错提取 → 归一化
   */
  async analyze(
    image: UploadFile | undefined,
    text: string | undefined,
  ): Promise<{ draft: Record<string, unknown>; warnings: string[] }> {
    // 1. 输入校验：至少一项；text 长度
    const trimmedText = (text ?? '').trim();
    if (!image && !trimmedText) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    if (trimmedText.length > 500) {
      throw new BadRequestException('文字描述不能超过 500 字');
    }
    if (image) {
      if (!ALLOWED_IMAGE_MIMES.includes(image.mimetype)) {
        throw new BadRequestException('仅支持 jpg/png/webp 图片');
      }
      if (image.buffer.byteLength > MAX_IMAGE_BYTES) {
        const mb = (MAX_IMAGE_BYTES / 1024 / 1024).toFixed(0);
        throw new BadRequestException(`示例图不能超过 ${mb}MB（当前${(image.buffer.byteLength / 1024 / 1024).toFixed(2)}MB）`);
      }
    }

    // 2. 读 DB 活跃分类树（行结构直接匹配 CategoryNode）
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories).where(eq(templateCategories.isActive, 1));
    const categories: CategoryNode[] = rows.map((r) => ({
      key: r.key,
      name: r.name,
      parentKey: r.parentKey,
      level: r.level,
    }));

    // 3. 取启用配置（未配置/未启用 → 503 透传）
    const cfg = await this.aiConfigService.getActiveConfig();

    // 4. 按输入组合分叉：有图走视觉模型（文字作补充要求），仅文字走文本模型
    let content: string;
    if (image) {
      content = await visionChat(cfg.vision, {
        systemPrompt: buildAnalyzeSystemPrompt(categories),
        userText: buildAnalyzeUserPrompt(trimmedText || undefined),
        imageBase64: image.buffer.toString('base64'),
        imageMime: image.mimetype,
        temperature: 0.3,
        jsonMode: true,
      });
    } else {
      content = await textChat(cfg.text, {
        systemPrompt: buildTextOnlySystemPrompt(categories),
        userText: buildTextOnlyUserPrompt(trimmedText),
        temperature: 0.3,
        jsonMode: true,
      });
    }

    // 5. 容错提取 JSON（失败 → 400 引导重试识别）
    const json = extractJson(content);
    if (!json) {
      throw new BadRequestException('模型输出无法解析为 JSON，请重试识别');
    }

    // 6. 归一化（枚举校验 / 分类链校验 / 数值夹取，非法值丢弃并收集 warnings）
    return normalizeDraft(json, categories);
  }
}
