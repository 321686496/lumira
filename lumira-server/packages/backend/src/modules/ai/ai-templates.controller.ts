// lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts
// AI 模板制作端点（Task 5：ai-analyze 识别；Task 7/9 再并入生图 / 剪影端点）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节

import { Controller, Post, Req, UseGuards, BadRequestException } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeService } from './ai-analyze.service';

@Controller('admin/templates')
@UseGuards(AdminAuthGuard)
export class AiTemplatesController {
  constructor(private readonly aiAnalyzeService: AiAnalyzeService) {}

  /** AI 识别示例图 → 模板草稿（multipart：image 文件必填） */
  @Post('ai-analyze')
  async analyze(@Req() req: FastifyRequest) {
    const { image } = await parseAiMultipart(req);
    if (!image) {
      throw new BadRequestException('Missing "image" file');
    }
    return this.aiAnalyzeService.analyze(image);
  }
}

// ===== 模块内小型 multipart 助手 =====
// 不复用 admin-templates.controller 的专用解析器（其字段名固定 cover/silhouette/pptpl/icon/images）；
// AI 端点解析：meta（文本）+ image / reference（文件）。

/** AI 端点 multipart 解析结果 */
export interface ParsedAiMultipart {
  meta: string | null;
  image?: UploadFile;
  reference?: UploadFile;
}

/**
 * 解析 AI 端点 multipart 请求，提取 `meta` 文本字段和 `image` / `reference` 文件字段。
 * 使用 @fastify/multipart 的 request.parts() 异步迭代器（同 admin-templates.controller）。
 */
export async function parseAiMultipart(req: FastifyRequest): Promise<ParsedAiMultipart> {
  const result: ParsedAiMultipart = { meta: null };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }

  for await (const part of reqAny.parts()) {
    if (part.type === 'field') {
      if (part.fieldname === 'meta') {
        result.meta = part.value as string;
      }
    } else if (part.type === 'file') {
      const fieldname = part.fieldname as string;
      const buffer = await part.toBuffer();
      const file: UploadFile = {
        buffer,
        filename: part.filename || '',
        mimetype: part.mimetype || '',
      };
      if (fieldname === 'image') {
        result.image = file;
      } else if (fieldname === 'reference') {
        result.reference = file;
      }
      // 其他字段名忽略
    }
  }

  return result;
}
