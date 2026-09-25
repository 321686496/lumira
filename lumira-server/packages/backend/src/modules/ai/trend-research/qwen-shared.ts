// lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts
// Qwen 联网搜索公共纯函数：三方 MaaS（web-search-qwen）与官方百炼（web-search-qwen-official）共用。
// 设计文档：docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md 3.2
//
// 只放与「响应形态」无关的纯工具：JSON 宽松提取 / 字段清洗 / 分词 / 引用条目映射 / 正文「联网综述」兜底。
// 各适配器自己的解析优先级（顶层 sources[] vs search_info.search_results[]）留在各自文件内。

import type { ResearchItem } from './research-item';

/** 两个适配器的缺省模型名（后台留空时回退） */
export const QWEN_SEARCH_DEFAULT_MODEL = 'qwen-plus';

/** 一条引用命中（松散字段；官方 search_info.search_results[] 的 site_name 由调用方映射到 site） */
export interface SearchHit {
  title?: unknown; url?: unknown; site?: unknown; caption?: unknown;
  snippet?: unknown; content?: unknown;
}

/** 宽松提取 JSON（对象/数组）：直接 parse，失败剥 markdown 代码块后再试，仍失败返回 null */
export function extractJson(text: string): unknown | null {
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
export function firstStr(...vals: unknown[]): string | undefined {
  for (const v of vals) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return undefined;
}

/** 摘要/标题 → 关键词数组（保留含字母/数字/中日韩字，排除纯符号，前 12） */
export function tokenize(...texts: string[]): string[] {
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

/** 清洗引用字段：去掉 markdown 代码反引号、加粗星号、两端空白，返回干净字符串 */
export function clean(field: string): string {
  return field.replace(/`+|[*_~]+/g, '').trim();
}

/** 引用命中 → ResearchItem（source 由调用方传入，用于区分 qwen / qwen-official） */
export function toResearchItem(hit: SearchHit, source: string): ResearchItem {
  const title = clean(firstStr(hit.title) ?? '');
  const snippet = clean(firstStr(hit.snippet, hit.content) ?? '');
  const url = clean(firstStr(hit.url, hit.site, hit.caption) ?? '');
  return { source, title, snippet, keywords: tokenize(snippet, title), url };
}

/** 正文综述捕获上限：保住节日日历/趋势清单核心信息，同时约束透传载荷 */
export const SUMMARY_SNIPPET_CAP = 2000;

/** message.content 正文综述 → 首条 ResearchItem（title=联网综述）。
 *  仅捕获非 JSON 的实质性文本（结构化 {results} 引用走各适配器的正式解析分支）；
 *  keywords 留空——长综述无分词意义，避免污染下游 keywords 汇集。 */
export function toSummaryItem(msg: Record<string, unknown>, source: string): ResearchItem | null {
  if (typeof msg.content !== 'string') return null;
  const text = msg.content.trim();
  if (!text || extractJson(text)) return null;
  return { source, title: '联网综述', snippet: text.slice(0, SUMMARY_SNIPPET_CAP), keywords: [] };
}
