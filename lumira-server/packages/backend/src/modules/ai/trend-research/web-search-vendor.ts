// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-vendor.ts
// T1 厂商联网检索适配器（Task 3）：用文本模型（联网模型）把 query 转 ResearchItem[]
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1
//
// 提示「只输出 JSON 数组」，jsonMode:true 经 textChat；解析失败/异常 → 返回 []（优雅降级，单源失败不阻断）。

import { textChat } from '../llm-client';
import type { LlmEndpoint } from '../llm-client';
import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

/** 宽松提取 JSON 数组：直接 JSON.parse；失败剥 markdown 后再试；仍失败返回 null */
function extractJsonArray(text: string): unknown {
  const candidates = [text];
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fence) candidates.unshift(fence[1]);
  const bracket = text.match(/\[[\s\S]*\]/);
  if (bracket) candidates.unshift(bracket[0]);
  for (const c of candidates) {
    try {
      const parsed = JSON.parse(c);
      if (Array.isArray(parsed)) return parsed;
    } catch {
      /* try next */
    }
  }
  return null;
}

/** 归一化一条厂商返回项 → ResearchItem；字段缺失以 unknown 兜底不丢条目 */
function toResearchItem(raw: unknown): ResearchItem {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const str = (v: unknown): string | undefined => (typeof v === 'string' && v.trim() ? v.trim() : undefined);
  const arr = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
  return {
    source: 'vendor',
    title: str(o.title) ?? str(o.name) ?? '',
    snippet: str(o.snippet) ?? str(o.description) ?? '',
    keywords: arr(o.keywords).length ? arr(o.keywords) : [],
    imgUrl: str(o.imgUrl),
    url: str(o.url),
    date: str(o.date),
    popularity: typeof o.popularity === 'number' && Number.isFinite(o.popularity) ? o.popularity : undefined,
  };
}

/** 创建厂商（联网模型）检索适配器 */
export function createVendorSearchProvider(searchEndpoint: LlmEndpoint): WebSearchProvider {
  return {
    name: 'vendor',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      const systemPrompt = [
        '你是专业的摄影/穿搭趋势检索助手。根据用户的检索词，返回客观、可溯源的研究条目。',
        '只输出一个 JSON 数组，不要任何 markdown、代码块标记或额外文字。',
        '数组元素字段：source(来源，如 小红书/站酷/500px/VOGUE)、title(标题)、snippet(50字内摘要)、',
        'keywords(3~8 个关键词数组)、imgUrl(如有配图)、date(发布时间)、url(链接)。',
        '检索不到真实信息时返回空数组 []，不要编造。',
      ].join('\n');

      try {
        const content = await textChat(searchEndpoint, {
          systemPrompt,
          userText: `请检索摄影/穿搭趋势：${q.query}`,  // query 透传
          jsonMode: true,
          temperature: 0.3,
          timeoutMs: 60_000,
        });
        const parsed = extractJsonArray(content);
        if (!parsed) return [];
        return parsed.map(toResearchItem);
      } catch {
        return [];
      }
    },
  };
}