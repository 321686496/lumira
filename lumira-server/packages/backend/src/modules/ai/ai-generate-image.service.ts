// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
// 生图编排（Task 7）：草稿 JSON + 可选参考图 → buildImagePrompt → 文本模态润色（失败回退）→ generateImage（per-provider）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节
//
// prompt 由后端统一构建（前端不拼 prompt）；qwen/zhipu 内部忽略参考图走文生图（image-client 分支处理）。

import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { GenerateImageResult, generateImage, mapSize } from './image-client';
import { visionChatMulti } from './llm-client';
import { buildImagePrompt, isSelfieDraft, retouchLevelOfDraft } from './image-prompt.builder';
import type { RetouchLevel } from './style-profile.presets';
import { composeImagePrompt } from './image-prompt.composer';
import type { ResearchItem } from './trend-research/research-item';
import { normalizeBrief } from './trend-research/research-brief';
import type { ResearchBrief } from './trend-research/research-brief';
import { renderResearchVision } from './trend-research/research-vision';
import type { ResearchVision } from './trend-research/research-vision';

const logger = new Logger('AiGenerateImageService');

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 参考视觉要点归一：后端已渲染文本直接沿用；admin 透传的 ResearchVision 对象现场渲染为分节文本；其余为 null */
function resolveResearchVision(v: unknown): string | null {
  if (typeof v === 'string') {
    const s = v.trim();
    return s !== '' ? s : null;
  }
  if (isPlainObject(v)) {
    const text = renderResearchVision(v as unknown as ResearchVision).trim();
    return text !== '' ? text : null;
  }
  return null;
}

/**
 * 全局生图并发闸门：批量姿势图（锚点 + 最多 5 个依赖图）会被同时发起，
 * 而多数生图厂商对并发生图存在并发/速率限制（过量会 429/排队 → 表现为“生成两张后卡住”）。
 * 这里把对上游的实际生图请求收敛到并发 ≤ 3（原 2，排队等待耗时叠加到单图 10 分钟
 * 超时上，导致第 4 张因「已等 150s + 生成 60s ≥ 600s」误报超时），避免打爆上游而卡死。
 * 信号量由任务服务在 run() 中显式 acquire/release（见 AiGenerateImageService.acquireImageSlot），
 * 使得「排队等待」与「真正生成」可在前端过程面板分开展示，且排队不占用生成超时预算。
 */
const AI_IMAGE_CONCURRENCY = 3;

class Semaphore {
  private active = 0;
  private readonly waiters: Array<() => void> = [];
  constructor(private readonly limit: number) {}

  /** 获取一个执行额度；排队等待结束后 resolve。返回排队耗时可如实告知用户。 */
  async acquire(): Promise<number> {
    const queuedAt = Date.now();
    if (this.active < this.limit) {
      this.active += 1;
      return 0;
    }
    await new Promise<void>((resolve) => {
      this.waiters.push(() => {
        this.active += 1;
        resolve();
      });
    });
    return Date.now() - queuedAt;
  }

  release(): void {
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
  '真实人体结构与解剖，无肢体、手指与面部畸变，手部五根手指比例正确、指节清晰、指间自然开合；' +
  '单一主光源方向：人物与背景由画面内同一方向可见的真实光源照亮，受光面、投影与高光方向一致，无无源光、无多光源打架、无不可能透视与姿势；' +
  '五官真实：眼睛有自然眼神光、眉毛睫毛轮廓可辨、嘴唇有真实唇纹，面部不做无瑕疵陶瓷化、不完美对称、无漫画式大眼与锥形脸；' +
  '面料物理真实：衣物按重力自然垂坠，蕾丝镂空连续不凭空断裂，亮片珠饰按重力排布，褶皱纹理符合面料质地；' +
  '空间真实：背景与道具是可到达的真实空间与实体，道具边缘轮廓清晰、透视正确，不是漂浮的符号化元素；' +
  '高清干净、细节清晰（皮肤纹理与布料纤维可辨，皮肤保留真实毛孔与细微瑕疵、不磨皮不水光肌），环境光有方向与衰减层次、阴影过渡自然。' +
  '禁止：动漫、二次元、漫画、插画；禁止无源光、多光源打架与不可能透视；禁止肢体与面部畸变；禁止颗粒与噪点；禁止磨皮过度均匀与水光肌。';
/** 按精修档追加的质感句（不再把写真/大片当贬义） */
export const RETOUCH_REALISM_SUFFIX: Record<RetouchLevel, string> = {
  none: '自然环境光与生活化瞬间感，保留真实的环境明暗关系，画面干净无颗粒；人物是普通真实的人（皮肤有毛孔与瑕疵、五官不完美对称、表情自然松弛），衣着与道具都是真实的物理材质。',
  light: '干净通透，光比克制，皮肤保留真实毛孔与绒毛、自然油脂反光不均匀（不磨皮、不水光肌），单一主光源方向统一不乱打光，面料与道具为真实材质（衣物按重力垂坠、褶皱自然），手部结构清晰完整。',
  polished: '布光精致考究、调色讲究、明暗层次分明，但皮肤、布料与道具仍是真实材质纹理，单一主光源方向统一，高光只来自实际光源。',
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

  /** 生图并发额度（排队等待不计入生成耗时）：调用方拿到额度前可以如实展示「排队中」。 */
  async acquireImageSlot(): Promise<number> {
    return imageSemaphore.acquire();
  }

  /** 释放一个生图并发额度（成功/失败后都须调用，与 acquireImageSlot 成对）。 */
  releaseImageSlot(): void {
    imageSemaphore.release();
  }

  /**
   * 生成模板效果图：取启用配置（未配置 503）→ 解析草稿 JSON（非法 400）→
   * 结构化素材（草稿 + 姿势 + 研究结果 + 照片参数 + 生图要求 + 用户参考图识别结论）交文本模型整理为生图提示词
   * （失败回退机械拼接）+ 厂商尺寸 → generateImage（有参考图时 doubao/openai 走图生图）。
   * references 支持多张：第一张作为图生图直接锚点（保底不回归），全部参考图另交由图片识别大模型
   * 识别并把结论注入提示词组织素材（仅 >1 张时触发识别，单张保持原快速路径）。
   * opts.anchor=false：参考图仅交视觉识别注入提示词、不作图生图底图（多格拼图 / 多主体示例图作底图会被照抄）。
   */
  async generate(
    references: UploadFile[] | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    researchJson?: string | null,
    opts?: { anchor?: boolean },
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

    // 2.5 解析研究结果 JSON：兼容旧前端（数组）与新前端（{ items, brief, vision }）；
    //     vision 可能是后端已渲染文本，也可能是 admin 直接透传的 ResearchVision 对象；非法静默降级，不阻断生图
    let research: ResearchItem[] = [];
    let researchBrief: ResearchBrief | null = null;
    let researchVision: string | null = null;
    if (researchJson) {
      try {
        const parsed: unknown = JSON.parse(researchJson);
        if (Array.isArray(parsed)) {
          research = parsed as ResearchItem[];
        } else if (isPlainObject(parsed)) {
          if (Array.isArray(parsed.items)) research = parsed.items as ResearchItem[];
          researchBrief = normalizeBrief(parsed.brief);
          researchVision = resolveResearchVision(parsed.vision);
        }
      } catch {
        // 非法 JSON → 无研究参考，走纯草稿素材
      }
    }

    // 3. 机械拼接 prompt 作为兜底；结构化素材交文本模型整理为最终生图提示词（失败回退拼接值）
    //    + 按厂商映射尺寸 → 生图（有参考图时 doubao/openai 走图生图）
    const fallbackPrompt = buildImagePrompt(draft, extraPrompt);
    // 3.5 用户上传多张参考图：全部交给图片识别大模型识别，识别结论注入提示词组织素材；
    //     第一张仍作为图生图直接锚点。识别失败/超时静默降级（referenceDesc=null），不阻断生图。
    const refs = references ?? [];
    // anchor=false：不作图生图底图；此时单张参考图也必须走视觉识别，否则参考图对提示词毫无贡献
    const useAnchor = opts?.anchor !== false;
    const anchor = useAnchor ? refs[0] : undefined;
    let referenceDesc: string | null = null;
    if (refs.length >= 1 && (refs.length > 1 || !useAnchor)) {
      referenceDesc = await this.describeReferences(refs);
    }
    const { prompt, composed } = await composeImagePrompt(
      cfg.text,
      { draft, research, brief: researchBrief, vision: researchVision, extraPrompt, referenceDesc },
      fallbackPrompt,
    );
    // 组织器失败/超时/空白输出时静默回退机械拼接（趋势要点与风格素材未注入）——留痕以便排查
    if (!composed) {
      logger.warn('生图提示词组织回退机械拼接 prompt（文本模型整理失败/超时/空白输出，趋势要点与风格素材未注入）');
    }
    // prompt 出口统一照片写实加固（媒介声明 + 真实材质 + 反动漫负面清单；自拍追加第一人称视角与设备负面清单）
    const hardenedPrompt = hardenPhotoRealism(prompt, {
      selfie: isSelfieDraft(draft),
      retouchLevel: retouchLevelOfDraft(draft),
    });
    // 上游生图请求（含 qwen 异步轮询/结果下载）。并发闸门由任务服务在调用 generate 前
    // acquireImageSlot() 显式持有（拿到额度那一刻即「真正开始生成」，排队阶段不计入生成耗时）；
    // 调用方在 generate 返回（成功或抛错）后必须 releaseImageSlot()。
    const imageResult = await generateImage(cfg.image, {
      prompt: hardenedPrompt,
      size: mapSize(cfg.image.provider, extractAspectRatio(draft)),
      referenceBase64: anchor?.buffer.toString('base64'),
      referenceMime: anchor?.mimetype,
    });
    return { ...imageResult, prompt: hardenedPrompt, model: cfg.image.model };
  }

  /** 多张姿势参考图识别：全部图片交给图片识别大模型逐张识别并总结共同点，返回文本结论；失败返回 null（静默降级） */
  async describeReferences(references: UploadFile[]): Promise<string | null> {
    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      const content = await visionChatMulti(cfg.vision, {
        systemPrompt:
          '你是资深人像摄影助理。用户上传了多张参考图，请逐一识别每张图中的：人物形象（长相/发型/服装/体型）、' +
          '场景与道具、光线与色调、摄影风格与构图；最后总结这些参考图的共同点。输出中文，按「图1/图2…」分节，末尾附「共同点」小节。' +
          '注意：识别结论只用于描述人物形象、场景、光线与风格，不得据此推断或声明最终画面人数；' +
          '画面人数与产出形态由创作要求决定（若参考图是多格拼图，同一个人出现在多个格子里只算同一主体，禁止按格子数累加人数）。',
        userText: `请逐一识别以下 ${references.length} 张参考图，输出结构化要点。`,
        images: references.map((r) => ({ base64: r.buffer.toString('base64'), mime: r.mimetype })),
        temperature: 0.3,
      });
      const text = content.trim();
      return text !== '' ? text : null;
    } catch {
      // 识别失败/超时：静默降级，不阻断生图
      return null;
    }
  }
}
