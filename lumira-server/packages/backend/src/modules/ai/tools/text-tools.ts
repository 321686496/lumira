// lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts
// 文本模型可用工具的注册表：首个工具 crawl_website。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第二节
//
// resolveTextTools(cfg) 是唯一的开关入口：未开启返回 undefined → 调用方行为与旧版一致。

import type { ToolDef } from '../llm-client';
import { traceCrawlCall } from '../llm-trace';
import { crawlUrl } from './crawl-url';
import type { TextToolContext } from './text-tool-loop';

export interface CrawlToolConfig {
  enabled: boolean;
  maxPerSession: number;
}

export const CRAWL_TOOL_NAME = 'crawl_website';

const MAX_TOOL_CALLS_LOWER = 1;
const MAX_TOOL_CALLS_UPPER = 6;

/** crawl_website 工具定义 */
export function buildCrawlToolDef(): ToolDef {
  return {
    name: CRAWL_TOOL_NAME,
    description:
      '抓取指定网页的正文纯文本（用于读取搜索结果或用户提供链接的完整内容）。仅当标题/摘要不足以支撑判断时调用；同一链接不要重复抓取。',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: '要抓取的网页绝对地址（http/https）' },
      },
      required: ['url'],
    },
  };
}

/** 解析工具入参 JSON；非法时抛可读错误 */
function parseArgs(argsJson: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(argsJson || '{}');
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {};
  } catch {
    throw new Error('工具参数解析失败（非合法 JSON）');
  }
}

/** 工具执行器：把 crawlUrl 的异常留给循环层回填为 error 文本 */
export function createToolExecutor(): TextToolContext['execute'] {
  return async (name: string, argsJson: string): Promise<string> => {
    if (name !== CRAWL_TOOL_NAME) throw new Error(`未知工具：${name}`);
    const args = parseArgs(argsJson);
    const url = typeof args.url === 'string' ? args.url.trim() : '';
    if (!url) throw new Error('缺少 url 参数');

    const handle = traceCrawlCall({ url });
    try {
      const r = await crawlUrl(url);
      handle?.done(r.text.slice(0, 200), {
        resultBrief: `抓取 ${r.chars} 字${r.truncated ? '（已截断）' : ''}`,
      });
      return JSON.stringify({ url: r.url, text: r.text, truncated: r.truncated });
    } catch (err) {
      handle?.fail(err);
      throw err;
    }
  };
}

/**
 * 开关入口：cfg.crawl.enabled !== true → undefined（文本调用退回旧行为）。
 * maxPerSession 夹紧到 1~6，防止后台异常值。
 */
export function resolveTextTools(cfg: { crawl?: CrawlToolConfig } | undefined | null): TextToolContext | undefined {
  const crawl = cfg?.crawl;
  if (!crawl?.enabled) return undefined;
  const raw = Math.floor(Number(crawl.maxPerSession));
  const maxToolCalls = Math.min(Math.max(Number.isFinite(raw) ? raw : MAX_TOOL_CALLS_LOWER, MAX_TOOL_CALLS_LOWER), MAX_TOOL_CALLS_UPPER);
  return { tools: [buildCrawlToolDef()], execute: createToolExecutor(), maxToolCalls };
}