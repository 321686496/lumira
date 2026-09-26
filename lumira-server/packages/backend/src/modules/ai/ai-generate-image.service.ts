// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
// 生图编排（Task 7）：草稿 JSON + 可选参考图 → buildImagePrompt → 文本模态润色（失败回退）→ generateImage（per-provider）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
//
// prompt 由后端统一构建（前端不拼 prompt）；qwen/zhipu 内部忽略参考图走文生图（image-client 分支处理）。

import { Injectable, BadRequestException } from '@nestjs/common';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { GenerateImageResult, generateImage, mapSize } from './image-client';
import { buildImagePrompt, isSelfieDraft } from './image-prompt.builder';
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
const PHOTO_REALISM_SUFFIX =
  '。真实摄影质感：皮肤为真实人类皮肤材质——可见毛孔、细小绒毛、轻微油光与肤色不均，绝不磨皮、绝不过度光滑发亮；布料、道具、街景均为真实材质纹理；光线来自真实环境光源，有自然的衰减、散射与阴影过渡；画面带轻微噪点与白平衡偏差，像随手抓拍的实拍照片。禁止：动漫、二次元、漫画、插画、赛璐璐、厚涂、CG、3D 渲染、油画、游戏立绘、影楼写真、网红精修风。';
/** 自拍（前置）专属负面清单：第一人称自拍里拍摄设备就是镜头本身，绝不能出现在画面里 */
const SELFIE_DEVICE_SUFFIX =
  '本张为第一人称前置摄像头自拍：镜头即人物本人视点、距面部约一臂之内、只呈现上半身或近景，人物视线看向镜头。画面中不出现手机、相机、三脚架、自拍杆等拍摄设备，不出现举着设备的手臂，也不出现镜中反射的拍摄者。';

export function hardenPhotoRealism(prompt: string, selfie = false): string {
  const suffix = selfie ? `${PHOTO_REALISM_SUFFIX}${SELFIE_DEVICE_SUFFIX}` : PHOTO_REALISM_SUFFIX;
  return `${PHOTO_REALISM_PREFIX}${prompt}${suffix}`;
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
    const hardenedPrompt = hardenPhotoRealism(prompt, isSelfieDraft(draft));
    const imageResult = await imageSemaphore.run(() => generateImage(cfg.image, {
      prompt: hardenedPrompt,
      size: mapSize(cfg.image.provider, extractAspectRatio(draft)),
      referenceBase64: reference?.buffer.toString('base64'),
      referenceMime: reference?.mimetype,
    }));
    return { ...imageResult, prompt: hardenedPrompt, model: cfg.image.model };
  }
}
