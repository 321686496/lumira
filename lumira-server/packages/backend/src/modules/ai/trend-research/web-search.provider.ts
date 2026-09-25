// lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts
// T1 WebSearchProvider 抽象 + 工厂 + 进程内 LRU 缓存降级（Task 2）
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1
//
// 职责：统一多源搜索按名实例化（searxng/baidu/vendor），并把单源请求包一层 LRU 缓存
// （key=name|query|limit）+ 8s 超时；失败抛可读错误（上层 Promise.allSettled 降级跳过）。

import { createSearxngSearchProvider } from './web-search-searxng';
import { createQwenSearchProvider } from './web-search-qwen';
import { createQwenOfficialSearchProvider } from './web-search-qwen-official';
import { createVendorSearchProvider } from './web-search-vendor';
import type { ResearchItem } from './research-item';
import type { LlmEndpoint } from '../llm-client';
import { traceSearchCall } from '../llm-trace';
import { LruCache } from './lru-cache';

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
 * 按名称创建搜索适配器：searxng / qwen / qwen-official / baidu / vendor；未知名称 → 抛错。
 * vendor 需要额外 LlmEndpoint（联网检索模型）；未提供时抛可读错误。
 */
export function createWebSearchProvider(
  providerName: string,
  cfg: { baseUrl?: string; apiKey?: string; model?: string; site?: string; vendorEndpoint?: LlmEndpoint },
): WebSearchProvider {
  const name = (providerName || '').trim().toLowerCase();
  switch (name) {
    case 'searxng':
      return createSearxngSearchProvider(cfg);
    case 'qwen':
      return createQwenSearchProvider(cfg);
    case 'qwen-official':
      return createQwenOfficialSearchProvider(cfg);
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

const searchCache = new LruCache<ResearchItem[]>(200);

/** 清空进程内搜索缓存（测试隔离 / 维护用） */
export function clearWebSearchCache(): void {
  searchCache.clear();
}

/**
 * 包一层 LRU 缓存（name|query|limit）按需搜索：命中直接返回缓存，
 * 未命中调 provider.search 并写入；provider 失败抛错（不缓存失败）。
 * 识别流程采集中会记录本次检索的查询词与命中摘要（供后台实时展示）。
 */
export async function cacheableSearch(provider: WebSearchProvider, q: WebSearchQuery): Promise<ResearchItem[]> {
  const key = `${provider.name}|${q.query}|${q.limit ?? 10}`;
  const hit = searchCache.get(key);
  if (hit) return hit;
  const handle = traceSearchCall({ title: `联网检索 · ${provider.name}`, model: provider.name, query: q.query });
  try {
    const items = await provider.search(q);
    handle?.done(
      items.map((it) => [it.title, it.snippet].filter(Boolean).join('：')).join('\n'),
      { resultBrief: `${items.length} 条` },
    );
    searchCache.set(key, items);
    return items;
  } catch (err) {
    handle?.fail(err);
    throw err;
  }
}

// re-export，便于统一入口
export { createSearxngSearchProvider };
export { createQwenSearchProvider };
export { createQwenOfficialSearchProvider };