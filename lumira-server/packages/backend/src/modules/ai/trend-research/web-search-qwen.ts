// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts
// 千问(Qwen)模型自带联网搜索适配器——三方 MaaS 网关形态：直连 Chat Completions + enable_search
// 设计文档：docs/superpowers/specs/2026-09-21-qwen-web-search-design.md 3.1
//          docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md（双通道拆分）
//
// 多形态宽松解析引用：顶层 sources[] / tool_calls.web_search.search_info.search_results[] /
// message.content 数组引用块 / content 文本 JSON{results}。仍取不到任何引用时，
// 退化为保留「联网综述」正文（提示词已要求正文标注来源链接），只有正文也为空才抛 Error
// （上层 allSettled 收集为 sourceErrors，绝不编造 URL）。
//
// 纯函数（extractJson / toResearchItem / toSummaryItem 等）已抽到 ./qwen-shared 与官方适配器共用；
// 本文件保留「三方 MaaS」形态的解析优先级，运行行为与抽取前完全一致（由 web-search-qwen.spec.ts 回归保证）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceLlmCall } from '../llm-trace';
import {
  QWEN_SEARCH_DEFAULT_MODEL,
  extractJson,
  toResearchItem,
  toSummaryItem,
} from './qwen-shared';
import type { SearchHit } from './qwen-shared';

// 保持既有导出面（历史上由本文件导出默认模型名）
export { QWEN_SEARCH_DEFAULT_MODEL } from './qwen-shared';

/** 系统提示词按次构造（注入当天日期）：模块级常量会跨天变旧，导致节日/时效类判断错乱。 */
function buildSystemPrompt(): string {
  return [
    '你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。',
    describeTodayUtc8(),
    '## 硬性要求',
    '1. 凡涉及时效信息（节日、近期热点、季节时令、最新流行趋势），必须以上面的今天日期为基准，并且只采用联网检索到的结果；',
    '   严禁凭训练记忆猜测节日名称或日期（例如把近期节日说成端午）。检索不到的时效信息，直接说明未检索到，不要编造。',
    '2. 主题要求「最近的节日」时，先列出今天之后最近的 1~3 个节日及其公历日期与距今天数，再围绕其中最近的节日给灵感。',
    '3. 输出的每条关键结论都要带可核验的来源链接（markdown 链接或裸 URL）；没有来源支撑的信息不要写。',
  ].join('\n');
}

/** 多形态提取引用 → ResearchItem[]；无引用返回 null */
function extractResearchItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;

  // 0) 解析 message（root.message 或 choices[0].message），供综述捕获与各分支复用
  let msg = root.message && typeof root.message === 'object' ? (root.message as Record<string, unknown>) : null;
  if (!msg && Array.isArray(root.choices) && root.choices.length) {
    const first = root.choices[0];
    if (first && typeof first === 'object' && (first as Record<string, unknown>).message && typeof (first as Record<string, unknown>).message === 'object') {
      msg = (first as Record<string, unknown>).message as Record<string, unknown>;
    }
  }
  if (!msg) return null;

  // 0a) 三方中转站 OpenAI 兼容格式：顶层 sources[]({title,url}) + choices[0].message.content
  //    （如 qwen3.7-max 直连 enable_search 时由网关把引用放到顶层 sources，而非 tool_calls）。
  //    message.content 的正文综述（节日日历/趋势清单类长文本）是最有价值的时效信息，
  //    作为首条「联网综述」条目带出，顶层引用排其后 —— 不再因早返回丢弃正文。
  const topSources = Array.isArray(root.sources) ? (root.sources as SearchHit[]) : [];
  if (topSources.length) {
    const items: ResearchItem[] = [];
    const summary = toSummaryItem(msg, 'qwen');
    if (summary) items.push(summary);
    items.push(...topSources.map((hit) => toResearchItem(hit, 'qwen')).filter((i) => i.title || i.url));
    if (items.length) return items;
  }

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
    const items = results.map((hit) => toResearchItem(hit, 'qwen'));
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
      items.push(toResearchItem({ title: b.title, url: b.url ?? b.link, snippet: b.snippet ?? b.content }, 'qwen'));
    }
    if (items.length) return items;
  }

  // 3) 结构化兜底：content 文本 → Array | { results:[{title,url,content}] }
  if (typeof msg.content === 'string' && msg.content.trim()) {
    const parsed = extractJson(msg.content);
    if (parsed && typeof parsed === 'object') {
      const p = parsed as Record<string, unknown>;
      const list = Array.isArray(parsed) ? (parsed as SearchHit[]) : Array.isArray(p.results) ? (p.results as SearchHit[]) : [];
      const items = list.map((hit) => toResearchItem(hit, 'qwen'));
      if (items.length) return items;
    }
  }

  // 4) 兜底：正文有实质文本但未命中任何结构化引用形态（网关只返正文综述、无顶层 sources）
  //    → 仍作为「联网综述」带出，不再整体丢弃；正文为空/纯 JSON 时才判为未取到引用。
  const fallbackSummary = toSummaryItem(msg, 'qwen');
  if (fallbackSummary) return [fallbackSummary];

  return null;
}

/** 创建千问联网搜索适配器（provider 名 qwen，三方 MaaS 网关形态） */
export function createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 搜索端点');
      if (!apiKey) throw new Error('Qwen 搜索未配置 API Key，请到后台「研究管线」填写');

      // 实时过程采集：本次既是检索也是大模型调用（enable_search），提示词与原始响应都要留痕
      const handle = traceLlmCall({
        model,
        systemPrompt: buildSystemPrompt(),
        userPrompt: q.query,
        title: '千问联网搜索 · 大模型调用',
      });

      let res: Response;
      try {
        res = await fetch(`${base}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: buildSystemPrompt() },
              { role: 'user', content: q.query },
            ],
            enable_search: true,
            temperature: 0.3,
            max_tokens: 4096,
            response_format: { type: 'json_object' },
          }),
          signal: AbortSignal.timeout(180_000),
        });
      } catch (err) {
        const name = (err as { name?: string } | null | undefined)?.name;
        const message = name === 'AbortError' || name === 'TimeoutError'
          ? `Qwen 网上搜索超时（${q.query}）`
          : `Qwen 网上搜索无效连接（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }

      if (!res.ok) {
        const message = `Qwen 网上搜索上游错误（HTTP ${res.status}，${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      const rawText = await res.text();
      let data: unknown = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        data = null;
      }
      const items = extractResearchItems(data);
      if (!items) {
        const message = `Qwen 网上搜索本次未取到引用（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      handle?.done(items[0]?.title === '联网综述' ? items[0].snippet : items.map((i) => i.title).filter(Boolean).join('、'), {
        rawResponse: rawText,
        resultBrief: `${items.length} 条`,
      });
      return items;
    },
  };
}
