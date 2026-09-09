// lumira-server/packages/backend/src/modules/ai/ai-config.service.ts
// AI 服务商配置管理：单行（id=1）CRUD + apiKey 脱敏 + 连通性测试
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节

import { Injectable, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { aiProviderConfig } from '../../database/schema';
import { visionChat } from './llm-client';
import { UpdateAiConfigDto } from './dto/update-ai-config.dto';

/** 脱敏后的配置视图（GET/PUT 返回；apiKey 永不回传明文） */
export interface AiConfigView {
  configured: true;
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
  visionModel: string;
  imageModel: string;
  enabled: boolean;
}

/** getActiveConfig() 返回的可用配置（供 ai-analyze / 生图使用，含明文 apiKey） */
export interface ActiveAiConfig {
  provider: string;
  baseUrl: string;
  apiKey: string;
  visionModel: string;
  imageModel: string;
}

/** 连通性测试端点返回 */
export interface AiConfigTestResult {
  vision: { ok: boolean; latencyMs?: number; error?: string };
  note: string;
}

/** 1x1 透明 PNG（连通性测试用最小图片） */
const TINY_1PX_PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const TEST_NOTE = '生图模型与视觉模型使用同一 apiKey，可用性以首次生图为准';

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
      enabled: row.enabled === 1,
    };
  }

  /** upsert id=1；apiKey 空串/缺省 = 保留原值；首次保存必须给 apiKey */
  async save(dto: UpdateAiConfigDto): Promise<AiConfigView> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const existing = await db.query.aiProviderConfig.findFirst();

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

  /** 最小 vision 请求（1px PNG + 'ping'）连通性测试 */
  async test(): Promise<AiConfigTestResult> {
    const cfg = await this.getActiveConfig();
    const t0 = Date.now();
    try {
      await visionChat(
        { provider: cfg.provider, baseUrl: cfg.baseUrl, apiKey: cfg.apiKey, visionModel: cfg.visionModel },
        {
          systemPrompt: 'You are a connectivity test.',
          userText: 'ping',
          imageBase64: TINY_1PX_PNG_B64,
          imageMime: 'image/png',
          temperature: 0,
          timeoutMs: 30_000,
        },
      );
      return { vision: { ok: true, latencyMs: Date.now() - t0 }, note: TEST_NOTE };
    } catch (e) {
      return { vision: { ok: false, error: (e as Error).message }, note: TEST_NOTE };
    }
  }

  /** 未配置/未启用 → 503；供 ai-analyze 等业务端点复用 */
  async getActiveConfig(): Promise<ActiveAiConfig> {
    const db = this.dbService.getDb();
    const row = await db.query.aiProviderConfig.findFirst();
    if (!row || row.enabled !== 1) {
      throw new ServiceUnavailableException('AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用');
    }
    return {
      provider: row.provider,
      baseUrl: row.baseUrl,
      apiKey: row.apiKey,
      visionModel: row.visionModel,
      imageModel: row.imageModel,
    };
  }
}
