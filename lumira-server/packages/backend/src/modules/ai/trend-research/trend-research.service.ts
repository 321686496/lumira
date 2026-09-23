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
import { textChat } from '../llm-client';
import { extractJson } from '../normalize';

/** 把重组后的长关键词串按空格拆成多组短查询（默认 ≤3 词/组，最多 4 组），避免单请求载荷过大超时。 */
export function splitQueries(query: string, groupSize = 3, maxGroups = 4): string[] {
  const tokens = (query || '').split(/\s+/).map((t) => t.trim()).filter(Boolean);
  if (!tokens.length) return [''];
  const groups: string[] = [];
  for (let i = 0; i < tokens.length && groups.length < maxGroups; i += groupSize) {
    groups.push(tokens.slice(i, i + groupSize).join(' '));
  }
  return groups;
}

/** 单个启用搜索来源的配置 */
export interface SearchSourceConfig {
  /** 来源标识（bing / vendor / baidu） */
  name: string;
  /** 适配器名（未知抛错） */
  provider: string;
  baseUrl?: string;
  apiKey?: string;
  /** SearXNG 站点限定（provider=searxng 时可选，拼接 site: 前缀） */
  site?: string;
  /** Qwen 模型自带联网搜索模型（provider=qwen 时使用，缺省回退 qwen-plus） */
  model?: string;
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
    model: cfg.model,
    site: cfg.site,
    vendorEndpoint: cfg.vendorEndpoint as never,
  });

/** research 执行结果：命中条目 + 单个来源失败原因（供编排层透传到 trace / 弹窗） */
export interface ResearchResult {
  items: ResearchItem[];
  /** 失败来源及其错误信息；全部成功则缺省为空数组 */
  sourceErrors?: { name: string; error: string }[];
}

@Injectable()
export class TrendResearchService {
  /** 搜索工厂（测试注入用；生产缺省走 defaultProviderFactory） */
  factory: SearchProviderFactory = defaultProviderFactory;

  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 用文本模型把「创作意图 / 口语化描述」重组成适合搜索引擎的关键词查询。
   * AI 未配置 / 调用失败 / 解析失败 → 返回原 topic（降级，不阻断研究）。
   */
  async reorganizeQuery(topic: string): Promise<string> {
    const trimmed = (topic || '').trim();
    if (!trimmed) return topic;
    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      const content = await textChat(cfg.text, {
        systemPrompt: [
          '你负责把"照片模板创作的意图描述"改写成搜索引擎上能命中优质摄影/人像/姿势灵感的关键词查询。',
          '## 规则',
          '1. 提取可检索的核心名词短语：风格、场景、光线、机位、姿势、氛围、模特类型等，最多 6 个关键词组。',
          '2. 保留创作者明确的硬约束（如竖构图/横构图、16:9、三种姿势、他拍/自拍），用通俗、SEO 可命中的说法表达。',
          '3. 去掉废话、口语连接词、感叹词；不要编造事实，不要加入原意图没有的卖点。',
          '4. 一份创作意图只需输出一组查询。',
          '## 输出',
          '只输出 JSON：{"query": "空格分隔的关键词串"}，不要 markdown 或解释；无法改写时返回 {"query": null}。',
        ].join('\n'),
        userText: `创作意图：${trimmed}`,
        temperature: 0.3,
        jsonMode: true,
        timeoutMs: 30_000,
      });
      const json = extractJson(content);
      const q = typeof json?.query === 'string' ? json.query.trim() : '';
      return q || trimmed;
    } catch {
      return trimmed;
    }
  }

  /**
   * 并行跑启用的来源，allSettled 聚合：失败来源跳过并收集原因；相同 source+title 去重（保留先出现者）。
   * 研究关闭或配置缺失 → { items: [] }。每条限数 limitPerSource（默认 10）。
   */
  async research(topic: string, opts: { limitPerSource?: number } = {}): Promise<ResearchResult> {
    const cfg = await this.aiConfigService.getSearchConfig?.();
    if (!cfg || !cfg.enabled || !cfg.sources.length) return { items: [] };

    const limit = opts.limitPerSource ?? 10;
    // 查询词重组：避免把整段口语意图直接丢给搜索引擎（失败自动回退原 topic）
    const query = await this.reorganizeQuery(topic);
    // 把长关键词串拆成多组短查询（≤3 词/组），避免单请求载荷过大导致模型侧超时；
    // 拆词后逐组搜索，缩短每次单请求的处理时长，也利于搜索引擎命中率。
    const queries = splitQueries(query);
    const sourceErrors: { name: string; error: string }[] = [];
    const settled = await Promise.allSettled(
      cfg.sources.map(async (src): Promise<ResearchItem[]> => {
        const provider = this.factory(src.name, src);
        const batch = await Promise.allSettled(
          queries.map((q) => cacheableSearch(provider, { query: q, limit } as WebSearchQuery)),
        );
        // 聚合该来源所有短查询结果；有任一成功即算该来源成功
        const items: ResearchItem[] = [];
        const errs: string[] = [];
        batch.forEach((b) => {
          if (b.status === 'fulfilled') items.push(...b.value);
          else errs.push(b.reason instanceof Error ? b.reason.message : String(b.reason));
        });
        if (!items.length && errs.length) {
          throw new Error(errs[0]);
        }
        return items;
      }),
    );

    const merged: ResearchItem[] = [];
    settled.forEach((r, i) => {
      const src = cfg.sources[i];
      if (r.status === 'fulfilled') {
        merged.push(...r.value);
      } else {
        // rejected 来源跳过，但记录原因供上层透传（含 baidu 未接入 / bing 缺 key 等）
        sourceErrors.push({ name: src.name, error: r.reason instanceof Error ? r.reason.message : String(r.reason) });
      }
    });

    const seen = new Set<string>();
    const out: ResearchItem[] = [];
    for (const it of merged) {
      const key = `${it.source}|${it.title}`;
      if (!seen.has(key)) {
        seen.add(key);
        out.push(it);
      }
    }
    return { items: out, sourceErrors };
  }
}