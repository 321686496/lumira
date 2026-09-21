// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.ts
// SearXNG 元搜索适配器：GET {baseUrl}/search?q=...&format=json（无 API Key，免费自建）
// 设计文档：docs/superpowers/specs/2026-09-21-searxng-search-provider-design.md
//
// site 可选：拼接 site: 前缀做站点限定搜索（如 site:xiaohongshu.com），
// 用于把小红书/抖音等被搜索引擎收录的公开页面作为趋势信号源。
// 失败抛可读错误（上层 allSettled 降级跳过）；无结果返回 []。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

/** searxng 结果条目最小字段 */
interface SearxngResult {
  title?: unknown;
  url?: unknown;
  content?: unknown;
}

/** 摘要 → 关键词：按空白分词，保留含字母/数字/中日韩字的词（排除纯符号） */
function tokenizeKeywords(snippet: string, title: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  const hasContent = /[\p{L}\p{N}]/u;
  for (const text of [snippet, title]) {
    if (!text) continue;
    for (const w of text.split(/\s+/)) {
      const t = w.trim();
      if (t && hasContent.test(t) && !seen.has(t)) {
        seen.add(t);
        out.push(t);
      }
    }
  }
  return out.slice(0, 12);
}

/** 创建 searxng 适配器（site 可选：拼接 site: 前缀做站点限定搜索） */
export function createSearxngSearchProvider(cfg: { baseUrl?: string; apiKey?: string; site?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || 'http://lumira-searxng:8080').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const site = (cfg.site || '').trim();

  return {
    name: 'searxng',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      const query = site ? `site:${site} ${q.query}` : q.query;
      const params = new URLSearchParams({ q: query, format: 'json', language: 'zh-CN' });
      const headers: Record<string, string> = {};
      if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
      const res = await fetch(`${base}/search?${params.toString()}`, {
        headers,
        signal: AbortSignal.timeout(8000),
      }).catch((err: unknown) => {
        const name = (err as { name?: string } | null | undefined)?.name;
        if (name === 'AbortError' || name === 'TimeoutError') {
          throw new Error(`搜索服务超时（${q.query}）`);
        }
        throw new Error(`搜索服务无法连接（${q.query}）`);
      });
      if (!res.ok) {
        throw new Error(`搜索服务上游错误（HTTP ${res.status}，${q.query}）`);
      }
      const data = (await res.json()) as { results?: unknown } | null;
      const list = Array.isArray(data?.results) ? (data.results as SearxngResult[]) : [];
      return list.map((it): ResearchItem => {
        const title = typeof it.title === 'string' ? it.title.slice(0, 120) : '';
        const snippet = typeof it.content === 'string' ? it.content.slice(0, 300) : '';
        return {
          source: 'searxng',
          title,
          snippet,
          url: typeof it.url === 'string' ? it.url : undefined,
          keywords: tokenizeKeywords(snippet, title),
        };
      });
    },
  };
}
