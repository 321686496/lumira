// lumira-server/packages/backend/src/modules/ai/ai-generate-silhouette.service.ts
// 剪影生成端点编排：上传人物图 → 本地 RMBG 抠像 + sharp 线稿/纯色合成，
// 或 AI 生图引擎（engine='ai'）：专用/生图模型生成白底剪影图 → sharp 阈值二值化转透明底。
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
// 增强 spec：.trae/documents/ai-template-oneclick-enhance.md Phase 2
//
// engine='local'（缺省，向后兼容）：纯本地计算，不依赖 ai-config；模型未安装时抛出 503。
// engine='ai'：依赖 ai-config（未配置/未启用 → 503 引导）；模型 = silhouette_model ?? image_model。

import { Injectable, BadRequestException } from '@nestjs/common';
import sharp from 'sharp';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { generateImage, mapSize } from './image-client';
import { computeAlphaBbox, generateSilhouettePng } from './silhouette.pipeline';

export interface SilhouetteGenResult {
  image: string;
  mimeType: 'image/png';
}

const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_SIZE_BYTES = 8 * 1024 * 1024;

/** AI 引擎提示词：生图模型无法直接输出透明 PNG，要求纯白底 + 黑剪影/线稿，后端阈值二值化 */
const AI_SILHOUETTE_PROMPTS: Record<'sketch' | 'solid', string> = {
  solid:
    '纯白背景上的黑色实心人形剪影插画，完整保留参考图中人物的姿势、比例与画面位置，边缘干净利落，无背景细节无文字无阴影',
  sketch:
    '纯白背景上的单色人物线稿插画，干净细线条勾勒参考图中人物的姿势轮廓与衣物结构，保留姿势比例与画面位置，无底色无文字',
};

/** AI 生成图灰度阈值：≥ 阈值视为白底 → 透明；否则视为剪影/线条 → 纯黑不透明 */
const BINARIZE_THRESHOLD: Record<'sketch' | 'solid', number> = {
  solid: 235,
  sketch: 245,
};

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 宽高 → 最接近的厂商比例 key（mapSize 支持的 5 档） */
function closestAspectRatio(width: number, height: number): string {
  if (width <= 0 || height <= 0) return '1:1';
  const ratio = width / height;
  const candidates: Array<[string, number]> = [
    ['1:1', 1],
    ['3:4', 3 / 4],
    ['4:3', 4 / 3],
    ['9:16', 9 / 16],
    ['16:9', 16 / 9],
  ];
  let best = candidates[0];
  for (const c of candidates) {
    if (Math.abs(c[1] - ratio) < Math.abs(best[1] - ratio)) best = c;
  }
  return best[0];
}

@Injectable()
export class AiSilhouetteService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 生成剪影：校验图片（jpg/png/webp、≤8MB）→ 解析 meta（缺省 sketch + crop + local）→
   * 按 engine 分发 AI / 本地流水线 → 返回 base64 PNG。
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

    // meta 解析：缺省 { mode: 'sketch', crop: true, engine: 'local' }
    let mode: 'sketch' | 'solid' = 'sketch';
    let crop = true;
    let engine: 'local' | 'ai' = 'local';
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
      if (parsed.engine !== undefined) {
        if (parsed.engine !== 'local' && parsed.engine !== 'ai') {
          throw new BadRequestException(`engine 非法 "${String(parsed.engine)}"，仅支持 local/ai`);
        }
        engine = parsed.engine;
      }
    }

    const png =
      engine === 'ai'
        ? await this.generateWithAi(image.buffer, mode, crop)
        : await generateSilhouettePng(image.buffer, { mode, crop });
    return { image: png.toString('base64'), mimeType: 'image/png' };
  }

  /**
   * AI 引擎：取启用配置（未配置/未启用 → 503 透传，文案引导去 AI 设置）→
   * 白底剪影/线稿提示词 + 源图作参考图（doubao/openai 图生图保姿势；qwen/zhipu 内部忽略参考图）→
   * sharp 灰度阈值二值化转透明底 → 可选按内容包围盒裁剪。
   */
  private async generateWithAi(input: Buffer, mode: 'sketch' | 'solid', crop: boolean): Promise<Buffer> {
    const cfg = await this.aiConfigService.getActiveConfig();

    // 源图尺寸 → 最接近的厂商尺寸（生图比例尽量贴合源图，保持姿势画面位置）
    const meta = await sharp(input).metadata();
    const aspectRatio = closestAspectRatio(meta.width ?? 0, meta.height ?? 0);

    // 生图用剪影模型：getActiveConfig 已回退为 imageModel（未单独指定时）；平台走生图模态端点
    const gen = await generateImage(
      { ...cfg.image, model: cfg.silhouetteModel },
      {
        prompt: AI_SILHOUETTE_PROMPTS[mode],
        size: mapSize(cfg.image.provider, aspectRatio),
        referenceBase64: input.toString('base64'),
        referenceMime: meta.format === 'png' ? 'image/png' : 'image/jpeg',
      },
    );

    // 灰度 → 阈值二值化：< 阈值 = 剪影/线条（纯黑不透明）；≥ 阈值 = 白底（透明）
    const threshold = BINARIZE_THRESHOLD[mode];
    const aiBuf = Buffer.from(gen.base64, 'base64');
    const { data, info } = await sharp(aiBuf)
      .removeAlpha()
      .grayscale()
      .raw()
      .toBuffer({ resolveWithObject: true });

    const { width, height } = info;
    const rgba = Buffer.alloc(width * height * 4, 0);
    const alpha = new Uint8Array(width * height);
    for (let i = 0; i < data.length; i++) {
      if (data[i] < threshold) {
        rgba[i * 4] = 0;
        rgba[i * 4 + 1] = 0;
        rgba[i * 4 + 2] = 0;
        rgba[i * 4 + 3] = 255;
        alpha[i] = 255;
      }
    }
    let out = await sharp(rgba, { raw: { width, height, channels: 4 } }).png().toBuffer();

    // 可选按前景包围盒裁剪（复用本地管线的 bbox 语义）
    if (crop) {
      const bbox = computeAlphaBbox(alpha, width, height);
      if (bbox) {
        out = await sharp(out)
          .extract({ left: bbox.left, top: bbox.top, width: bbox.width, height: bbox.height })
          .png()
          .toBuffer();
      }
    }
    return out;
  }
}
