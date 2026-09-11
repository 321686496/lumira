// lumira-server/packages/backend/src/modules/ai/ai-config.service.ts
// AI 服务商配置管理：单行（id=1）CRUD + apiKey 脱敏 + 连通性测试
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节

import { Injectable, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { aiProviderConfig } from '../../database/schema';
import { visionChat, textChat } from './llm-client';
import { generateImage, mapSize } from './image-client';
import { UpdateAiConfigDto } from './dto/update-ai-config.dto';

/** 脱敏后的配置视图（GET/PUT 返回；apiKey 永不回传明文） */
export interface AiConfigView {
  configured: true;
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
  visionModel: string;
  imageModel: string;
  /** 存储值（'' = 未配置独立文本模型） */
  textModel: string;
  /** 有效文本模型 = textModel || visionModel */
  effectiveTextModel: string;
  /** 文本模态独立平台（null = 跟随共享平台） */
  textPlatform: { provider: string; baseUrl: string; apiKeyMasked: string } | null;
  /** 生图模态独立平台（null = 跟随共享平台） */
  imagePlatform: { provider: string; baseUrl: string; apiKeyMasked: string } | null;
  /** 剪影专用模型：null = 与生图模型一致 */
  silhouetteModel: string | null;
  enabled: boolean;
}

/** 单模态运行时端点（含明文 apiKey） */
export interface AiModalityEndpoint {
  provider: string;
  baseUrl: string;
  apiKey: string;
  model: string;
}

/** getActiveConfig() 返回的可用配置（供 ai-analyze / 生图 / 剪影使用） */
export interface ActiveAiConfig {
  /** 共享平台（视觉模态） */
  vision: AiModalityEndpoint;
  /** 文本模态：独立平台 ?? 共享平台；model = textModel（跟随共享且未配置时回退 visionModel） */
  text: AiModalityEndpoint;
  /** 生图模态：独立平台 ?? 共享平台 */
  image: AiModalityEndpoint;
  /** 生效的剪影模型（未单独指定时已回退为 imageModel；平台走 image 模态端点，调用方直接使用） */
  silhouetteModel: string;
  /** 是否配置了独立文本模型（连通测试分支用） */
  hasCustomTextModel: boolean;
}

/** 连通性测试目标（text 永远测有效文本模型；silhouette 永远测有效剪影模型） */
export type AiConfigTestTarget = 'vision' | 'text' | 'image' | 'silhouette';

/** 单项模型连通性结果 */
type AiConfigTargetResult = { ok: boolean; latencyMs?: number; error?: string };

/** 连通性测试端点返回（只包含请求的目标） */
export interface AiConfigTestResult {
  vision?: AiConfigTargetResult;
  text?: AiConfigTargetResult;
  image?: AiConfigTargetResult;
  silhouette?: AiConfigTargetResult;
  note: string;
}

/** 32×32 纯色 PNG（连通性测试用最小合规图片；部分厂商要求图片边长 >10px，1×1 会被 400 拒绝） */
const TEST_IMAGE_PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAxSURBVFhH7c4hAQAACMRA+if7VuAJAObEzNRVkv6s9rgOAAAAAAAAAAAAAAAAAABgANYGXMSkdFBBAAAAAElFTkSuQmCC';

const TEST_NOTE = '生图 / 剪影为真实模型调用并按次计费；未选择的目标不测试';

const ALL_TEST_TARGETS: AiConfigTestTarget[] = ['vision', 'text', 'image', 'silhouette'];

/** apiKey 脱敏：空值返回空串（避免与脱敏后的 '****' 混淆）；≤8 位全遮蔽；否则前 3 + **** + 后 2 */
function maskKey(k: string): string {
  if (!k) return '';
  return k.length <= 8 ? '****' : `${k.slice(0, 3)}****${k.slice(-2)}`;
}

@Injectable()
export class AiConfigService {
  constructor(private readonly dbService: DatabaseService) {}

  /** 无配置返回 { configured: false }（200，前端显示空态） */
  async get(): Promise<AiConfigView | { configured: false }> {
    const db = this.dbService.getDb();
    const row = await db.query.aiProviderConfig.findFirst();
    if (!row) return { configured: false };
    return {
      configured: true,
      provider: row.provider,
      baseUrl: row.baseUrl,
      apiKeyMasked: maskKey(row.apiKey),
      visionModel: row.visionModel,
      imageModel: row.imageModel,
      textModel: row.textModel ?? '',
      effectiveTextModel: row.textModel?.trim() ? row.textModel : row.visionModel,
      textPlatform:
        row.textProvider && row.textBaseUrl
          ? { provider: row.textProvider, baseUrl: row.textBaseUrl, apiKeyMasked: maskKey(row.textApiKey ?? '') }
          : null,
      imagePlatform:
        row.imageProvider && row.imageBaseUrl
          ? { provider: row.imageProvider, baseUrl: row.imageBaseUrl, apiKeyMasked: maskKey(row.imageApiKey ?? '') }
          : null,
      silhouetteModel: row.silhouetteModel ?? null,
      enabled: row.enabled === 1,
    };
  }

  /** upsert id=1；apiKey 空串/缺省 = 保留原值；首次保存必须给 apiKey；silhouetteModel 空串归一为 null */
  async save(dto: UpdateAiConfigDto): Promise<AiConfigView> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const existing = await db.query.aiProviderConfig.findFirst();
    const silhouetteModel = dto.silhouetteModel?.trim() || null;

    // 文本模态独立平台组：textProvider 非空 = 启用（需 baseUrl + 独立文本模型 + apiKey）；空/缺省 = 清除（跟随共享平台）
    let textProvider: string | null = null;
    let textBaseUrl: string | null = null;
    let textApiKey: string | null = null;
    if (dto.textProvider?.trim()) {
      if (!dto.textBaseUrl?.trim()) {
        throw new BadRequestException('文本独立平台必须填写 baseUrl');
      }
      if (!(dto.textModel ?? '').trim()) {
        throw new BadRequestException('文本使用独立平台时必须填写文本模型（无法回退视觉模型）');
      }
      const resolvedTextApiKey = dto.textApiKey?.trim() || existing?.textApiKey;
      if (!resolvedTextApiKey) {
        throw new BadRequestException('首次配置独立平台必须填写 API Key');
      }
      textProvider = dto.textProvider;
      textBaseUrl = dto.textBaseUrl.trim();
      textApiKey = resolvedTextApiKey;
    }

    // 生图模态独立平台组：语义同文本组（imageModel 为必填列，无需单独校验模型）
    let imageProvider: string | null = null;
    let imageBaseUrl: string | null = null;
    let imageApiKey: string | null = null;
    if (dto.imageProvider?.trim()) {
      if (!dto.imageBaseUrl?.trim()) {
        throw new BadRequestException('生图独立平台必须填写 baseUrl');
      }
      const resolvedImageApiKey = dto.imageApiKey?.trim() || existing?.imageApiKey;
      if (!resolvedImageApiKey) {
        throw new BadRequestException('首次配置独立平台必须填写 API Key');
      }
      imageProvider = dto.imageProvider;
      imageBaseUrl = dto.imageBaseUrl.trim();
      imageApiKey = resolvedImageApiKey;
    }

    if (!existing) {
      if (!dto.apiKey) {
        throw new BadRequestException('首次配置必须填写 API Key');
      }
      await db.insert(aiProviderConfig).values({
        id: 1,
        provider: dto.provider,
        baseUrl: dto.baseUrl,
        apiKey: dto.apiKey,
        visionModel: dto.visionModel,
        imageModel: dto.imageModel,
        textModel: dto.textModel ?? '',
        textProvider,
        textBaseUrl,
        textApiKey,
        imageProvider,
        imageBaseUrl,
        imageApiKey,
        silhouetteModel,
        enabled: dto.enabled ? 1 : 0,
        createdAt: now,
        updatedAt: now,
      });
    } else {
      await db
        .update(aiProviderConfig)
        .set({
          provider: dto.provider,
          baseUrl: dto.baseUrl,
          visionModel: dto.visionModel,
          imageModel: dto.imageModel,
          textModel: dto.textModel ?? '',
          textProvider,
          textBaseUrl,
          textApiKey,
          imageProvider,
          imageBaseUrl,
          imageApiKey,
          silhouetteModel,
          enabled: dto.enabled ? 1 : 0,
          apiKey: dto.apiKey ? dto.apiKey : existing.apiKey, // 留空 = 不改
          updatedAt: now,
        })
        .where(eq(aiProviderConfig.id, 1));
    }

    const view = await this.get();
    if (view.configured !== true) {
      // save 后行必然存在，理论上不可达
      throw new ServiceUnavailableException('AI 配置保存失败，请重试');
    }
    return view;
  }

  /** 最小请求连通性测试：默认全测；显式 targets 只测所选目标（空、未知、重复均拒绝） */
  async test(targets?: AiConfigTestTarget[]): Promise<AiConfigTestResult> {
    const cfg = await this.getActiveConfig();

    const selected = targets ?? ALL_TEST_TARGETS;
    if (selected.length === 0 || new Set(selected).size !== selected.length || selected.some((t) => !ALL_TEST_TARGETS.includes(t))) {
      throw new BadRequestException('targets 必须是 vision/text/image/silhouette 的非空去重数组');
    }

    const result: AiConfigTestResult = { note: TEST_NOTE };
    const jobs = selected.map(async (target): Promise<[AiConfigTestTarget, AiConfigTargetResult]> => {
      const startedAt = Date.now();
      try {
        if (target === 'vision') {
          await visionChat(cfg.vision, {
            systemPrompt: 'You are a connectivity test.',
            userText: 'ping',
            imageBase64: TEST_IMAGE_PNG_B64,
            imageMime: 'image/png',
            temperature: 0,
            timeoutMs: 30_000,
          });
        } else if (target === 'text') {
          await textChat(cfg.text, {
            systemPrompt: 'You are a connectivity test.',
            userText: 'ping',
            temperature: 0,
            timeoutMs: 30_000,
          });
        } else {
          await generateImage(
            target === 'silhouette' ? { ...cfg.image, model: cfg.silhouetteModel } : cfg.image,
            {
              prompt: 'connectivity test',
              size: mapSize(cfg.image.provider, '1:1'),
              referenceBase64: target === 'silhouette' ? TEST_IMAGE_PNG_B64 : undefined,
              referenceMime: target === 'silhouette' ? 'image/png' : undefined,
            },
            { requestTimeoutMs: 30_000 },
          );
        }
        return [target, { ok: true, latencyMs: Date.now() - startedAt }];
      } catch (e) {
        return [target, { ok: false, error: (e as Error).message }];
      }
    });

    for (const [target, itemResult] of await Promise.all(jobs)) {
      result[target] = itemResult;
    }
    return result;
  }

  /** 未配置/未启用 → 503；供 ai-analyze 等业务端点复用 */
  async getActiveConfig(): Promise<ActiveAiConfig> {
    const db = this.dbService.getDb();
    const row = await db.query.aiProviderConfig.findFirst();
    if (!row || row.enabled !== 1) {
      throw new ServiceUnavailableException('AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用');
    }
    const hasCustomTextModel = (row.textModel ?? '').trim() !== '';
    // 独立平台「存在」= provider + baseUrl + apiKey 三者齐全（任缺其一视为未配置，防止手工 SQL 缺 key 时把 null 直达上游客户端）
    const hasTextPlatform = Boolean(row.textProvider?.trim() && row.textBaseUrl?.trim() && row.textApiKey?.trim());
    const hasImagePlatform = Boolean(row.imageProvider?.trim() && row.imageBaseUrl?.trim() && row.imageApiKey?.trim());
    const shared = { provider: row.provider, baseUrl: row.baseUrl, apiKey: row.apiKey };
    return {
      vision: { ...shared, model: row.visionModel },
      text: hasTextPlatform
        ? { provider: row.textProvider as string, baseUrl: row.textBaseUrl as string, apiKey: row.textApiKey as string, model: row.textModel as string }
        : { ...shared, model: hasCustomTextModel ? (row.textModel as string) : row.visionModel },
      image: hasImagePlatform
        ? { provider: row.imageProvider as string, baseUrl: row.imageBaseUrl as string, apiKey: row.imageApiKey as string, model: row.imageModel }
        : { ...shared, model: row.imageModel },
      silhouetteModel: row.silhouetteModel?.trim() || row.imageModel,
      hasCustomTextModel,
    };
  }
}
