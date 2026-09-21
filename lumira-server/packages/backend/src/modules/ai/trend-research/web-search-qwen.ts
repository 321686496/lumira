// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts
// 千问(Qwen)模型自带联网搜索适配器：直连 Chat Completions + enable_search
// 设计文档：docs/superpowers/specs/2026-09-21-qwen-web-search-design.md 3.1
//
// 多形态宽松解析引用：tool_calls.web_search.search_info.search_results[] /
// message.content 数组引用块 / content 文本 JSON{results}。取不到引用 → 抛 Error
// （上层 allSettled 收集为 sourceErrors，绝不编造 URL）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

export const QWEN_SEARCH_DEFAULT_MODEL = 'qwen-plus';

const SYSTEM_PROMPT = '你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。';

/** 一条引用命中（松散字段） */
interface SearchHit {
  title?: unknown; url?: unknown; site?: unknown; caption?: unknown;
  snippet?: unknown; content?: unknown;
}

/** 宽松提取 JSON（对象/数组）：直接 parse，失败剥 markdown 代码块后再试，仍失败返回 null */
function extractJson(text: string): unknown | null {
  const candidates: string[] = [];
  // 设计意图“直接 parse”：原始文本优先；失败再剥 markdown 代码块/对象/数组片段
  candidates.push(text);
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fence) candidates.push(fence[1]);
  const brace = text.match(/\{[\s\S]*\}/);
  if (brace) candidates.push(brace[0]);
  const bracket = text.match(/\[[\s\S]*\]/);
  if (bracket) candidates.push(bracket[0]);
  for (const c of candidates) {
    try { return JSON.parse(c); } catch { /* try next */ }
  }
  return null;
}

/** 取首个非空字符串 */
function firstStr(...vals: unknown[]): string | undefined {
  for (const v of vals) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return undefined;
}

/** 摘要/标题 → 关键词数组（保留含字母/数字/中日韩字，排除纯符号，前 12） */
function tokenize(...texts: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  const hasContent = /[\p{L}\p{N}]/u;
  for (const text of texts) {
    if (!text) continue;
    for (const w of text.split(/\s+/)) {
      const t = w.trim();
      if (t && hasContent.test(t) && !seen.has(t)) { seen.add(t); out.push(t); }
    }
  }
  return out.slice(0, 12);
}

function toResearchItem(hit: SearchHit): ResearchItem {
  const title = firstStr(hit.title) ?? '';
  const snippet = firstStr(hit.snippet, hit.content) ?? '';
  const url = firstStr(hit.url, hit.site, hit.caption);
  return { source: 'qwen', title, snippet, keywords: tokenize(snippet, title), url };
}

/** 多形态提取引用 → ResearchItem[]；无引用返回 null */
function extractResearchItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;
  const msg = root.message && typeof root.message === 'object' ? (root.message as Record<string, unknown>) : null;
  if (!msg) return null;

  // 1) tool_calls[web_search] → arguments.search_info.search_results[]
  const calls = Array.isArray(msg.tool_calls) ? msg.tool_calls : [];
  for (const call of calls) {
    if (!call || typeof call !== 'object') continue;
    const fn = (call as Record<string, unknown>).function;
    if (!fn || typeof fn !== 'object') continue;
    const f = fn as Record<string, unknown>;
    if (f.name !== 'web_search') continue;
    const parsed = extractJson(typeof f.arguments === 'string' ? f.arguments : '');
    if (!parsed || typeof parsed !== 'object') continue;
    const args = parsed as Record<string, unknown>;
    const si = args.search_info && typeof args.search_info === 'object' ? (args.search_info as Record<string, unknown>) : null;
    const results = Array.isArray(si?.search_results) ? (si.search_results as SearchHit[]) : [];
    const items = results.map(toResearchItem);
    if (items.length) return items;
  }

  // 2) content 数组的 search_result/reference 内容块
  if (Array.isArray(msg.content)) {
    const items: ResearchItem[] = [];
    for (const block of msg.content) {
      if (!block || typeof block !== 'object') continue;
      const b = block as Record<string, unknown>;
      const type = typeof b.type === 'string' ? b.type : '';
      if (!/search_result|reference|citation|web_page/i.test(type)) continue;
      items.push(toResearchItem({ title: b.title, url: b.url ?? b.link, snippet: b.snippet ?? b.content }));
    }
    if (items.length) return items;
  }

  // 3) 结构化兜底：content 文本 → Array | { results:[{title,url,content}] }
  if (typeof msg.content === 'string' && msg.content.trim()) {
    const parsed = extractJson(msg.content);
    if (parsed && typeof parsed === 'object') {
      const p = parsed as Record<string, unknown>;
      const list = Array.isArray(parsed) ? (parsed as SearchHit[]) : Array.isArray(p.results) ? (p.results as SearchHit[]) : [];
      const items = list.map(toResearchItem);
      if (items.length) return items;
    }
  }

  return null;
}

/** 创建千问联网搜索适配器（provider 名 qwen） */
export function createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 搜索端点');
      if (!apiKey) throw new Error('Qwen 搜索未配置 API Key，请到后台「研究管线」填写');

      const res = await fetch(`${base}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: q.query },
          ],
          enable_search: true,
          temperature: 0.3,
          max_tokens: 4096,
          response_format: { type: 'json_object' },
        }),
        signal: AbortSignal.timeout(120_000),
      }).catch((err: unknown) => {
        const name = (err as { name?: string } | null | undefined)?.name;
        if (name === 'AbortError' || name === 'TimeoutError') throw new Error(`Qwen 网上搜索超时（${q.query}）`);
        throw new Error(`Qwen 网上搜索无效连接（${q.query}）`);
      });

      if (!res.ok) throw new Error(`Qwen 网上搜索上游错误（HTTP ${res.status}，${q.query}）`);
      const data = await res.json().catch(() => null);
      const items = extractResearchItems(data);
      if (!items) throw new Error(`Qwen 网上搜索本次未取到引用（${q.query}）`);
      return items;
    },
  };
}