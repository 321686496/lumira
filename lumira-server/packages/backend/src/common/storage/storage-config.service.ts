// lumira-server/packages/backend/src/common/storage/storage-config.service.ts
// 存储配置管理：从 DB 读写各厂商配置 / 当前激活存储 / 图片公网 URL，并刷新运行时状态。
// 启动后覆盖环境变量种子，实现「后台可视化配置」而无需改服务器 .env（.env 仅作首次兜底）。

import { BadRequestException, Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { eq, ne } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { storageConfigs } from '../../database/schema';
import { LocalStorageAdapter } from './local-storage.adapter';
import { S3StorageAdapter, S3Config } from './s3-storage.adapter';
import { StorageId, STORAGE_IDS } from './storage-registry';
import type { StorageAdapter } from './storage-adapter.interface';
import { seedAdapter, setRuntimeConfig } from './runtime-storage';

export interface StorageConfigPayload {
  endpoint?: string;
  accessKeyId?: string;
  secretAccessKey?: string;
  bucket?: string;
  region?: string;
  publicUrl?: string;
}

export interface StorageConfigView {
  id: StorageId;
  isActive: boolean;
  configured: boolean;
  endpoints: { endpoint?: string; bucket?: string; region?: string; publicUrl?: string };
  /** 密钥已加密显示，避免回显明文 */
  hasCredentials: boolean;
  secretMasked: string;
  updatedAt: number | null;
}

@Injectable()
export class StorageConfigService implements OnApplicationBootstrap {
  constructor(private readonly db: DatabaseService) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.loadFromDb();
  }

  private buildAdapter(id: StorageId, cfg: StorageConfigPayload): StorageAdapter {
    if (id === 'local') return new LocalStorageAdapter();
    const c: S3Config = {
      endpoint: cfg.endpoint ?? '',
      accessKeyId: cfg.accessKeyId ?? '',
      secretAccessKey: cfg.secretAccessKey ?? '',
      bucket: cfg.bucket ?? '',
      region: cfg.region || 'auto',
    };
    return new S3StorageAdapter(c);
  }

  /** 启动时从 DB 加载全部厂商配置 + 激活项 */
  async loadFromDb(): Promise<void> {
    const rows = await this.db.getDb().select().from(storageConfigs);
    for (const row of rows) {
      const cfg = parseCfg(row.configJson);
      try {
        seedAdapter(row.id as StorageId, this.buildAdapter(row.id as StorageId, cfg));
      } catch (e) {
        console.error(`[storage-config] 加载 ${row.id} 失败，忽略并回退 env：${(e as Error).message}`);
      }
    }
    const active = rows.find((r) => r.isActive);
    if (active) {
      setRuntimeConfig(active.id as StorageId, parseCfg(active.configJson).publicUrl || '');
    }
  }

  async list(): Promise<StorageConfigView[]> {
    const rows = await this.db.getDb().select().from(storageConfigs);
    return STORAGE_IDS.map((id) => {
      const row = rows.find((r) => r.id === id);
      const cfg = row ? parseCfg(row.configJson) : {};
      return {
        id,
        isActive: !!row?.isActive,
        configured: !!row,
        endpoints: { endpoint: cfg.endpoint, bucket: cfg.bucket, region: cfg.region, publicUrl: cfg.publicUrl },
        hasCredentials: !!(cfg.accessKeyId || cfg.secretAccessKey || id === 'local'),
        secretMasked: cfg.secretAccessKey ? mask(cfg.secretAccessKey) : '',
        updatedAt: row?.updatedAt ?? null,
      };
    });
  }

  /** 保存某厂商配置（local 只需 publicUrl）；active=true 时切换为当前激活存储 */
  async save(id: StorageId, payload: StorageConfigPayload, active: boolean): Promise<void> {
    if (!STORAGE_IDS.includes(id)) throw new BadRequestException(`未知存储厂商：${id}`);

    if (id === 'local') {
      await this.upsert(id, '{}', active);
      if (active) setRuntimeConfig('local', payload.publicUrl || '');
      return;
    }

    if (!payload.endpoint || !payload.accessKeyId || !payload.secretAccessKey || !payload.bucket) {
      throw new BadRequestException(`${id} 需填写 endpoint / accessKeyId / secretAccessKey / bucket`);
    }
    const adapter = this.buildAdapter(id, payload); // 先校验配置可用再落库
    try {
      await adapter.listKeys('__probe__');
    } catch (e) {
      throw new BadRequestException(`${id} 配置不可用：${(e as Error).message}`);
    }

    await this.upsert(id, JSON.stringify(payload), active);
    seedAdapter(id, adapter);
    if (active) setRuntimeConfig(id, payload.publicUrl || '');
  }

  private async upsert(id: string, configJson: string, active: boolean): Promise<void> {
    const db = this.db.getDb();
    const now = Math.floor(Date.now() / 1000);
    if (active) {
      // 先清掉其它行的激活标记
      await db.update(storageConfigs).set({ isActive: 0 }).where(ne(storageConfigs.id, id));
    }
    const existing = await db.select({ id: storageConfigs.id }).from(storageConfigs).where(eq(storageConfigs.id, id)).limit(1);
    if (existing.length > 0) {
      await db.update(storageConfigs).set({ configJson, isActive: active ? 1 : 0, updatedAt: now }).where(eq(storageConfigs.id, id));
    } else {
      await db.insert(storageConfigs).values({ id, configJson, isActive: active ? 1 : 0, updatedAt: now });
    }
  }
}

function parseCfg(json: string | null): StorageConfigPayload {
  if (!json) return {};
  try { return JSON.parse(json); } catch { return {}; }
}

function mask(s: string): string {
  if (!s) return '';
  return s.length <= 6 ? '******' : `${s.slice(0, 3)}****${s.slice(-3)}`;
}