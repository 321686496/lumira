// lumira-server/packages/backend/src/modules/ai/ai-generate-silhouette.service.ts
// 剪影生成端点编排（Task 9）：上传人物图 → 本地 RMBG 抠像 + sharp 线稿/纯色合成
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
//
// 本服务完全不依赖 ai-config（纯本地计算），未配置/未启用 AI 也能用；模型未安装时抛出 503。

import { Injectable, BadRequestException } from '@nestjs/common';
import { UploadFile } from '../templates/admin-templates.service';
import { generateSilhouettePng } from './silhouette.pipeline';

export interface SilhouetteGenResult {
  image: string;
  mimeType: 'image/png';
}

const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_SIZE_BYTES = 8 * 1024 * 1024;

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

@Injectable()
export class AiSilhouetteService {
  /**
   * 生成剪影：校验图片（jpg/png/webp、≤8MB）→ 解析 meta（缺省 sketch + crop）→
   * 调用本地流水线 → 返回 base64 PNG。
   */
  async generate(image: UploadFile, metaJson: string | null): Promise<SilhouetteGenResult> {
    if (!ALLOWED_MIME.has(image.mimetype)) {
      throw new BadRequestException(
        `不支持的图片类型 "${image.mimetype}"，仅支持 jpg/png/webp`,
      );
    }
    if (image.buffer.length > MAX_SIZE_BYTES) {
      throw new BadRequestException('图片超过 8MB 上限，请压缩后再试');
    }

    // meta 解析：缺省 { mode: 'sketch', crop: true }
    let mode: 'sketch' | 'solid' = 'sketch';
    let crop = true;
    if (metaJson !== null && metaJson !== undefined && metaJson !== '') {
      let parsed: unknown;
      try {
        parsed = JSON.parse(metaJson);
      } catch {
        throw new BadRequestException('meta 不是合法的 JSON，请检查草稿数据');
      }
      if (!isPlainObject(parsed)) {
        throw new BadRequestException('meta 不是合法的 JSON，请检查草稿数据');
      }
      if (parsed.mode !== undefined) {
        if (parsed.mode !== 'sketch' && parsed.mode !== 'solid') {
          throw new BadRequestException(`mode 非法 "${String(parsed.mode)}"，仅支持 sketch/solid`);
        }
        mode = parsed.mode;
      }
      if (typeof parsed.crop === 'boolean') {
        crop = parsed.crop;
      }
    }

    const png = await generateSilhouettePng(image.buffer, { mode, crop });
    return { image: png.toString('base64'), mimeType: 'image/png' };
  }
}