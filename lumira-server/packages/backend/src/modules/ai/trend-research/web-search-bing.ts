// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-bing.ts
// T1 通用搜索 API 适配器（Task 2）：微软 Bing Web Search v7（GET {baseUrl}/v7.0/search）
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1
//
// 遵守 ToS/限速：单次请求带 AbortSignal.timeout；无结果返回 []；网络失败抛可读错误（由上层降级跳过）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

/** bing 结果条目最小字段 */
interface BingWebPage {
  name?: unknown;
  url?: unknown;
  snippet?: unknown;
}

/** 摘要 → 关键词：按空白分词，保留含字母/数字/中日韩字的词（排除纯符号） */
function tokenizeKeywords(snippet: string, title: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  // 含字母/数字/中日韩字（\p{L}\p{N}\p{Script=Han}）的最低要求，排除纯标点符号
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

/** 创建 bing 适配器（URL 拼 /v7.0/search，Bearer 鉴权，解析 webPages.value[]） */
export function createBingSearchProvider(cfg: { baseUrl?: string; apiKey?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || 'https://api.bing.microsoft.com').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';

  return {
    name: 'bing',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      const params = new URLSearchParams({ q: q.query, count: String(q.limit ?? 10) });
      if (q.source) params.set('mkt', q.source);
      const res = await fetch(`${base}/v7.0/search?${params.toString()}`, {
        headers: { Authorization: `Bearer ${apiKey}` },
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
      const data = (await res.json()) as { webPages?: { value?: unknown } } | null;
      const list = Array.isArray(data?.webPages?.value) ? (data.webPages.value as BingWebPage[]) : [];
      return list.map((it): ResearchItem => {
        const title = typeof it.name === 'string' ? it.name.slice(0, 120) : '';
        const snippet = typeof it.snippet === 'string' ? it.snippet.slice(0, 300) : '';
        return {
          source: 'bing',
          title,
          snippet,
          url: typeof it.url === 'string' ? it.url : undefined,
          keywords: tokenizeKeywords(snippet, title),
        };
      });
    },
  };
}