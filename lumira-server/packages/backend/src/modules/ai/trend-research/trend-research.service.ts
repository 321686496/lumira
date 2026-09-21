// lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts
// T1 趋势研究服务编排（Task 4）：读取 search 配置 → 并行跑启用来源 → allSettled 聚合 → source+title 去重
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1
//
// 依赖注入：aiConfigService 提供 search 配置（getSearchConfig？）；providerFactory 便于测试注入。
// 工程约束：单源失败跳过、进程内 LRU 缓存、可开关、可降级。图片副产物保留 imgUrl（不在此下载）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import { cacheableSearch, createWebSearchProvider } from './web-search.provider';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
import type { ResearchItem } from './research-item';

/** 单个启用搜索来源的配置 */
export interface SearchSourceConfig {
  /** 来源标识（bing / vendor / baidu） */
  name: string;
  /** 适配器名（未知抛错） */
  provider: string;
  baseUrl?: string;
  apiKey?: string;
  /** 厂商联网检索端点（provider=vendor 时必填） */
  vendorEndpoint?: unknown;
}

/** search 运行时配置（由 ai-config.service 提供；Task 10 接线 read） */
export interface SearchConfig {
  enabled: boolean;
  sources: SearchSourceConfig[];
}

/** 工厂类型：按来源配置创建搜索适配器 */
export type SearchProviderFactory = (name: string, cfg: SearchSourceConfig) => WebSearchProvider;

const defaultProviderFactory: SearchProviderFactory = (name, cfg) =>
  createWebSearchProvider(cfg.provider || name, {
    baseUrl: cfg.baseUrl,
    apiKey: cfg.apiKey,
    vendorEndpoint: cfg.vendorEndpoint as never,
  });

@Injectable()
export class TrendResearchService {
  /** 搜索工厂（测试注入用；生产缺省走 defaultProviderFactory） */
  factory: SearchProviderFactory = defaultProviderFactory;

  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 并行跑启用的来源，allSettled 聚合：失败来源跳过；相同 source+title 去重（保留先出现者）。
   * 研究关闭或配置缺失 → []。每条限数 limitPerSource（默认 10）。
   */
  async research(topic: string, opts: { limitPerSource?: number } = {}): Promise<ResearchItem[]> {
    const cfg = await this.aiConfigService.getSearchConfig?.();
    if (!cfg || !cfg.enabled || !cfg.sources.length) return [];

    const limit = opts.limitPerSource ?? 10;
    const jobs = cfg.sources.map(async (src): Promise<ResearchItem[]> => {
      const provider = this.factory(src.name, src);
      return cacheableSearch(provider, { query: topic, limit } as WebSearchQuery);
    });

    const settled = await Promise.allSettled(jobs);
    const merged: ResearchItem[] = [];
    for (const r of settled) {
      if (r.status === 'fulfilled') merged.push(...r.value);
      // rejected 来源跳过（日志由上层/编排追踪）
    }

    const seen = new Set<string>();
    const out: ResearchItem[] = [];
    for (const it of merged) {
      const key = `${it.source}|${it.title}`;
      if (!seen.has(key)) {
        seen.add(key);
        out.push(it);
      }
    }
    return out;
  }
}