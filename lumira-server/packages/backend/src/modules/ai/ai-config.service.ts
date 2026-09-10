// lumira-server/packages/backend/src/modules/ai/ai-config.service.ts
// AI 服务商配置管理：单行（id=1）CRUD + apiKey 脱敏 + 连通性测试
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节

import { Injectable, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { aiProviderConfig } from '../../database/schema';
import { visionChat, textChat } from './llm-client';
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
  enabled: boolean;
}

/** 单模态运行时端点（含明文 apiKey） */
export interface AiModalityEndpoint {
  provider: string;
  baseUrl: string;
  apiKey: string;
  model: string;
}

/** getActiveConfig() 返回的可用配置（供 ai-analyze / 生图使用） */
export interface ActiveAiConfig {
  /** 共享平台（视觉模态） */
  vision: AiModalityEndpoint;
  /** 文本模态：独立平台 ?? 共享平台；model = textModel（跟随共享且未配置时回退 visionModel） */
  text: AiModalityEndpoint;
  /** 生图模态：独立平台 ?? 共享平台 */
  image: AiModalityEndpoint;
  /** 是否配置了独立文本模型（连通测试分支用） */
  hasCustomTextModel: boolean;
}

/** 连通性测试端点返回 */
export interface AiConfigTestResult {
  vision: { ok: boolean; latencyMs?: number; error?: string };
  /** 配置了独立文本模型时才有此字段 */
  text?: { ok: boolean; latencyMs?: number; error?: string };
  note: string;
}

/** 32×32 纯色 PNG（连通性测试用最小合规图片；部分厂商要求图片边长 >10px，1×1 会被 400 拒绝） */
const TEST_IMAGE_PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAxSURBVFhH7c4hAQAACMRA+if7VuAJAObEzNRVkv6s9rgOAAAAAAAAAAAAAAAAAABgANYGXMSkdFBBAAAAAElFTkSuQmCC';

const TEST_NOTE = '生图模型按次计费，未做连通测试，可用性以首次生图为准';

/** apiKey 脱敏：≤8 位全遮蔽；否则前 3 + **** + 后 2 */
function maskKey(k: string): string {
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
      enabled: row.enabled === 1,
    };
  }

  /** upsert id=1；apiKey 空串/缺省 = 保留原值；首次保存必须给 apiKey */
  async save(dto: UpdateAiConfigDto): Promise<AiConfigView> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const existing = await db.query.aiProviderConfig.findFirst();

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

  /** 最小请求连通性测试：vision（32×32 PNG + ping）；配置独立 textModel 时追加纯文本测试 */
  async test(): Promise<AiConfigTestResult> {
    const cfg = await this.getActiveConfig();
    const t0 = Date.now();
    let vision: AiConfigTestResult['vision'];
    try {
      await visionChat(cfg.vision, {
        systemPrompt: 'You are a connectivity test.',
        userText: 'ping',
        imageBase64: TEST_IMAGE_PNG_B64,
        imageMime: 'image/png',
        temperature: 0,
        timeoutMs: 30_000,
      });
      vision = { ok: true, latencyMs: Date.now() - t0 };
    } catch (e) {
      vision = { ok: false, error: (e as Error).message };
    }

    let text: AiConfigTestResult['text'];
    if (cfg.hasCustomTextModel) {
      const t1 = Date.now();
      try {
        await textChat(cfg.text, {
          systemPrompt: 'You are a connectivity test.',
          userText: 'ping',
          temperature: 0,
          timeoutMs: 30_000,
        });
        text = { ok: true, latencyMs: Date.now() - t1 };
      } catch (e) {
        text = { ok: false, error: (e as Error).message };
      }
    }

    return text ? { vision, text, note: TEST_NOTE } : { vision, note: TEST_NOTE };
  }

  /** 未配置/未启用 → 503；供 ai-analyze 等业务端点复用 */
  async getActiveConfig(): Promise<ActiveAiConfig> {
    const db = this.dbService.getDb();
    const row = await db.query.aiProviderConfig.findFirst();
    if (!row || row.enabled !== 1) {
      throw new ServiceUnavailableException('AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用');
    }
    const hasCustomTextModel = (row.textModel ?? '').trim() !== '';
    const hasTextPlatform = Boolean(row.textProvider?.trim() && row.textBaseUrl?.trim());
    const hasImagePlatform = Boolean(row.imageProvider?.trim() && row.imageBaseUrl?.trim());
    const shared = { provider: row.provider, baseUrl: row.baseUrl, apiKey: row.apiKey };
    return {
      vision: { ...shared, model: row.visionModel },
      text: hasTextPlatform
        ? { provider: row.textProvider as string, baseUrl: row.textBaseUrl as string, apiKey: row.textApiKey as string, model: row.textModel as string }
        : { ...shared, model: hasCustomTextModel ? (row.textModel as string) : row.visionModel },
      image: hasImagePlatform
        ? { provider: row.imageProvider as string, baseUrl: row.imageBaseUrl as string, apiKey: row.imageApiKey as string, model: row.imageModel }
        : { ...shared, model: row.imageModel },
      hasCustomTextModel,
    };
  }
}
