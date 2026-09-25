// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts
// 千问(Qwen)官方百炼联网搜索适配器：OpenAI 兼容 Chat Completions + enable_search + search_info
// 设计文档：docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md 3.1
// 参考：https://docs.bailian.console.aliyun.com/zh/model-studio/web-search
//
// 与三方 MaaS 适配器（web-search-qwen.ts）的三处差异：
// 1) 请求加 search_options.{forced_search,enable_source}：官方模型可能自行判断不检索，
//    研究管线每次都要真实检索且需要来源列表；
// 2) 请求去掉 response_format:{type:'json_object'}：官方联网返回「正文 + search_info」，
//    强 JSON 会丢掉带链接的正文综述；
// 3) 解析与三方适配器「分支 0a」行为对齐，正文综述绝不丢弃：
//    顶层 search_info.search_results[] 命中时，「正文综述」置首、结构化引用（title / url（缺省
//    回退 site_name）/ 摘要）随后；无 search_info 时仅「正文综述」兜底（2000 字上限）；
//    两者皆空 → 抛错（上层 allSettled 收进 sourceErrors，主流程不中断，绝不编造 URL）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceLlmCall } from '../llm-trace';
import {
  QWEN_SEARCH_DEFAULT_MODEL,
  toResearchItem,
  toSummaryItem,
} from './qwen-shared';

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

/** 取 message：root.message 或 choices[0].message */
function pickMessage(root: Record<string, unknown>): Record<string, unknown> | null {
  if (root.message && typeof root.message === 'object') return root.message as Record<string, unknown>;
  if (Array.isArray(root.choices) && root.choices.length) {
    const first = root.choices[0];
    if (first && typeof first === 'object') {
      const m = (first as Record<string, unknown>).message;
      if (m && typeof m === 'object') return m as Record<string, unknown>;
    }
  }
  return null;
}

/** 官方形态解析（与三方适配器「分支 0a」行为对齐，正文综述绝不丢弃）：
 *  1) 正文综述（content 为非 JSON 实质文本 → 「联网综述」，2000 字上限、keywords 留空）置首；
 *  2) search_info.search_results[] → 结构化引用（url 缺省回退 site_name）随后；
 *  3) 无 search_info 时仅返回综述兜底；两者皆空 → null（由调用方抛错）。 */
function extractOfficialItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;

  // 正文综述：真实联网场景官方会在正文给带链接的结论，必须保留（不能用引用条目顶替）
  const msg = pickMessage(root);
  const summary = msg ? toSummaryItem(msg, 'qwen-official') : null;

  // 结构化引用：site_name → site，借用 toResearchItem 的 url 回退链（url → site → caption）
  const si = root.search_info && typeof root.search_info === 'object' ? (root.search_info as Record<string, unknown>) : null;
  const results = Array.isArray(si?.search_results) ? (si?.search_results as Record<string, unknown>[]) : [];
  const refs = results
    .map((r) => toResearchItem(
      { title: r.title, url: r.url, site: r.site_name, snippet: r.snippet, content: r.content },
      'qwen-official',
    ))
    .filter((i) => i.title || i.url);

  const items: ResearchItem[] = [];
  if (summary) items.push(summary);
  items.push(...refs);
  return items.length ? items : null;
}

/** 创建千问官方百炼联网搜索适配器（provider 名 qwen-official） */
export function createQwenOfficialSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen-official',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 官方搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 官方搜索端点');
      if (!apiKey) throw new Error('Qwen 官方搜索未配置 API Key，请到后台「研究管线」填写');

      // 实时过程采集：本次既是检索也是大模型调用（enable_search），提示词与原始响应都要留痕
      const handle = traceLlmCall({
        model,
        systemPrompt: buildSystemPrompt(),
        userPrompt: q.query,
        title: '千问官方联网搜索 · 大模型调用',
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
            search_options: { forced_search: true, enable_source: true },
            temperature: 0.3,
            max_tokens: 4096,
            // 刻意不带 response_format：官方联网返回「正文 + search_info」，强 JSON 会丢掉带链接的正文综述
          }),
          signal: AbortSignal.timeout(180_000),
        });
      } catch (err) {
        const name = (err as { name?: string } | null | undefined)?.name;
        const message = name === 'AbortError' || name === 'TimeoutError'
          ? `Qwen 官方网上搜索超时（${q.query}）`
          : `Qwen 官方网上搜索无效连接（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }

      if (!res.ok) {
        const message = `Qwen 官方网上搜索上游错误（HTTP ${res.status}，${q.query}）`;
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
      const items = extractOfficialItems(data);
      if (!items) {
        const message = `Qwen 官方网上搜索本次未取到引用（${q.query}）`;
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
