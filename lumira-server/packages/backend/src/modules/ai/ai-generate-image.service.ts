// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
// 生图编排（Task 7）：草稿 JSON + 可选参考图 → buildImagePrompt → 文本模态润色（失败回退）→ generateImage（per-provider）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
//
// prompt 由后端统一构建（前端不拼 prompt）；qwen/zhipu 内部忽略参考图走文生图（image-client 分支处理）。

import { Injectable, BadRequestException } from '@nestjs/common';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { GenerateImageResult, generateImage, mapSize } from './image-client';
import { buildImagePrompt, isSelfieDraft, retouchLevelOfDraft } from './image-prompt.builder';
import type { RetouchLevel } from './style-profile.presets';
import { composeImagePrompt } from './image-prompt.composer';
import type { ResearchItem } from './trend-research/research-item';

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/**
 * 全局生图并发闸门：批量姿势图（锚点 + 最多 5 个依赖图）会被同时发起，
 * 而多数生图厂商对并发生图存在并发/速率限制（过量会 429/排队 → 表现为“生成两张后卡住”）。
 * 这里把对上游的实际生图请求收敛到并发 ≤ 2，避免打爆上游而卡死。
 */
const AI_IMAGE_CONCURRENCY = 2;

class Semaphore {
  private active = 0;
  private readonly waiters: Array<() => void> = [];
  constructor(private readonly limit: number) {}

  async run<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }

  private acquire(): Promise<void> {
    if (this.active < this.limit) {
      this.active += 1;
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      this.waiters.push(() => {
        this.active += 1;
        resolve();
      });
    });
  }

  private release(): void {
    const next = this.waiters.shift();
    if (next) {
      next();
    } else {
      this.active -= 1;
    }
  }
}

const imageSemaphore = new Semaphore(AI_IMAGE_CONCURRENCY);

/** 草稿顶层 composition.aspectRatio 提取（缺失/非字符串 → undefined，mapSize 内兜底 1:1） */
function extractAspectRatio(draft: Record<string, unknown>): string | undefined {
  const composition = draft.composition;
  if (!isPlainObject(composition)) return undefined;
  const ratio = composition.aspectRatio;
  return typeof ratio === 'string' && ratio.trim() !== '' ? ratio.trim() : undefined;
}

/**
 * 照片写实最终加固：组织器/拼接器产出的提示词在送厂商前统一包裹，全厂商生效。
 * 中文生图模型对「少女 / 新中式 / 夜景 / 氛围感」等关键词有强烈的动漫插画先验
 * （塑料皮肤、绘画化场景、假光线），仅靠素材里的真实感条款不足以压制——
 * 出口处强制声明照片媒介 + 真实材质细节 + 反动漫负面清单，保证无论上游提示词
 * 整理得好坏，进入生图 API 的永远是「实拍照片」语境。
 */
const PHOTO_REALISM_PREFIX = '一张真实相机直出的实拍照片：';
/** 恒定保留的真实底线（与风格档案无关）：媒介真实 + 解剖真实 + 可实拍 + 真实材质 */
export const PHOTO_REALISM_BASELINE_SUFFIX =
  '真实照片媒介，不是动漫、二次元、漫画、插画、赛璐璐、厚涂、CG、3D 渲染、油画或游戏立绘；' +
  '真实人体结构与解剖，无肢体、手指与面部畸变；可实拍复现，无无源光、无不可能透视与姿势；' +
  '真实材质，皮肤有毛孔与绒毛、布料有纹理、环境光有衰减与阴影过渡。' +
  '禁止：动漫、二次元、漫画、插画；禁止无源光与不可能透视；禁止肢体与面部畸变。';
/** 按精修档追加的质感句（不再把写真/大片当贬义） */
export const RETOUCH_REALISM_SUFFIX: Record<RetouchLevel, string> = {
  none: '自然环境光与生活化瞬间感，保留真实的环境明暗关系。',
  light: '干净通透，光比克制，皮肤保留真实毛孔与绒毛，不磨皮。',
  polished: '布光精致考究、调色讲究、明暗层次分明，但皮肤、布料与道具仍是真实材质纹理。',
};
/** 自拍（前置）专属负面清单：第一人称自拍里拍摄设备就是镜头本身，绝不能出现在画面里 */
const SELFIE_DEVICE_SUFFIX =
  '本张为第一人称前置摄像头自拍：镜头即人物本人视点、距面部约一臂之内、只呈现上半身或近景，人物视线看向镜头。画面中不出现手机、相机、三脚架、自拍杆等拍摄设备，不出现举着设备的手臂，也不出现镜中反射的拍摄者。';

export interface HardenOptions {
  selfie?: boolean;
  retouchLevel?: RetouchLevel;
}

export function hardenPhotoRealism(prompt: string, opts: HardenOptions = {}): string {
  const { selfie = false, retouchLevel = 'none' } = opts;
  const parts = [
    `${PHOTO_REALISM_PREFIX}${prompt}`,
    RETOUCH_REALISM_SUFFIX[retouchLevel],
    PHOTO_REALISM_BASELINE_SUFFIX,
  ];
  if (selfie) parts.push(SELFIE_DEVICE_SUFFIX);
  return parts.join(' ');
}

@Injectable()
export class AiGenerateImageService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 生成模板效果图：取启用配置（未配置 503）→ 解析草稿 JSON（非法 400）→
   * 结构化素材（草稿 + 姿势 + 研究结果 + 照片参数 + 生图要求）交文本模型整理为生图提示词
   * （失败回退机械拼接）+ 厂商尺寸 → generateImage（有参考图时 doubao/openai 走图生图）
   */
  async generate(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    researchJson?: string | null,
  ): Promise<GenerateImageResult & { prompt: string; model: string }> {
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

    // 2.5 解析研究结果 JSON（识别阶段透传；非法/非数组静默降级为空，不阻断生图）
    let research: ResearchItem[] = [];
    if (researchJson) {
      try {
        const parsed = JSON.parse(researchJson);
        if (Array.isArray(parsed)) research = parsed as ResearchItem[];
      } catch {
        // 非法 JSON → 无研究参考，走纯草稿素材
      }
    }

    // 3. 机械拼接 prompt 作为兜底；结构化素材交文本模型整理为最终生图提示词（失败回退拼接值）
    //    + 按厂商映射尺寸 → 生图（有参考图时 doubao/openai 走图生图）
    const fallbackPrompt = buildImagePrompt(draft, extraPrompt);
    const { prompt } = await composeImagePrompt(
      cfg.text,
      { draft, research, extraPrompt },
      fallbackPrompt,
    );
    // 网络生图（含 qwen 异步轮询/结果下载）纳入全局并发闸门，避免并发打爆上游厂商
    // prompt 出口统一照片写实加固（媒介声明 + 真实材质 + 反动漫负面清单；自拍追加第一人称视角与设备负面清单）
    const hardenedPrompt = hardenPhotoRealism(prompt, {
      selfie: isSelfieDraft(draft),
      retouchLevel: retouchLevelOfDraft(draft),
    });
    const imageResult = await imageSemaphore.run(() => generateImage(cfg.image, {
      prompt: hardenedPrompt,
      size: mapSize(cfg.image.provider, extractAspectRatio(draft)),
      referenceBase64: reference?.buffer.toString('base64'),
      referenceMime: reference?.mimetype,
    }));
    return { ...imageResult, prompt: hardenedPrompt, model: cfg.image.model };
  }
}
