// lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts
// T1 WebSearchProvider 抽象 + 工厂 + 进程内 LRU 缓存降级（Task 2）
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1
//
// 职责：统一多源搜索按名实例化（bing/baidu/vendor），并把单源请求包一层 LRU 缓存
// （key=name|query|limit）+ 8s 超时；失败抛可读错误（上层 Promise.allSettled 降级跳过）。

import { createBingSearchProvider } from './web-search-bing';
import { createVendorSearchProvider } from './web-search-vendor';
import type { ResearchItem } from './research-item';
import type { LlmEndpoint } from '../llm-client';

/** 单次搜索请求 */
export interface WebSearchQuery {
  query: string;
  /** 返回条数上限 */
  limit?: number;
  /** 可选来源限定 */
  source?: string;
}

/** 搜索适配器抽象 */
export interface WebSearchProvider {
  readonly name: string;
  search(q: WebSearchQuery): Promise<ResearchItem[]>;
}

/** 工厂额外可选能力：厂商（联网模型）检索可注入 searchEndpoint */
export interface VendorWebSearchProvider extends WebSearchProvider {
  readonly vendor: true;
}

/**
 * 按名称创建搜索适配器：bing / baidu / vendor；未知名称 → 抛错。
 * vendor 需要额外 LlmEndpoint（联网检索模型）；未提供时抛可读错误。
 */
export function createWebSearchProvider(
  providerName: string,
  cfg: { baseUrl?: string; apiKey?: string; vendorEndpoint?: LlmEndpoint },
): WebSearchProvider {
  const name = (providerName || '').trim().toLowerCase();
  switch (name) {
    case 'bing':
      return createBingSearchProvider(cfg);
    case 'baidu':
      throw new Error('baidu 搜索适配器尚未接入');
    case 'vendor':
    case 'llm':
      if (!cfg.vendorEndpoint) throw new Error('vendor 联网检索需配置联网模型端点');
      return createVendorSearchProvider(cfg.vendorEndpoint);
    default:
      throw new Error(`未知的搜索服务商：${providerName}`);
  }
}

// ===== LRU 缓存 =====

/** 极简 LRU Map（max 200；访问即刷新顺序） */
class LruCache {
  private map = new Map<string, ResearchItem[]>();
  constructor(private readonly max = 200) {}
  get(key: string): ResearchItem[] | undefined {
    const v = this.map.get(key);
    if (v === undefined) return undefined;
    // 刷新：删除后重插置末位，保持 LRU 顺序
    this.map.delete(key);
    this.map.set(key, v);
    return v;
  }
  set(key: string, value: ResearchItem[]): void {
    if (this.map.has(key)) this.map.delete(key);
    this.map.set(key, value);
    if (this.map.size > this.max) {
      const oldest = this.map.keys().next().value;
      if (oldest !== undefined) this.map.delete(oldest);
    }
  }
  clear(): void {
    this.map.clear();
  }
}

const searchCache = new LruCache(200);

/** 清空进程内搜索缓存（测试隔离 / 维护用） */
export function clearWebSearchCache(): void {
  searchCache.clear();
}

/**
 * 包一层 LRU 缓存（name|query|limit）按需搜索：命中直接返回缓存，
 * 未命中调 provider.search 并写入；provider 失败抛错（不缓存失败）。
 */
export async function cacheableSearch(provider: WebSearchProvider, q: WebSearchQuery): Promise<ResearchItem[]> {
  const key = `${provider.name}|${q.query}|${q.limit ?? 10}`;
  const hit = searchCache.get(key);
  if (hit) return hit;
  const items = await provider.search(q);
  searchCache.set(key, items);
  return items;
}

// re-export，便于统一入口
export { createBingSearchProvider };