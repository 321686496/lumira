// lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts
// 通用「文本模型工具循环」原语：ctx 缺省 = 旧行为（单次 textChat）。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第一节
//
// 循环：带 tools 多轮 → 执行工具 → 回填 role:'tool' → 再决定；
// 轮次/次数用尽后以 tool_choice:'none' 收尾，逼模型输出最终内容。

import { textChat, toolChatOnce, type LlmEndpoint, type ToolDef } from '../llm-client';

export interface TextToolContext {
  tools: ToolDef[];
  /** 执行工具，返回回填给模型的字符串（内部自行把异常转成 error 文本） */
  execute(name: string, argsJson: string): Promise<string>;
  /** 单次会话允许的工具调用总次数上限 */
  maxToolCalls: number;
}

export interface ChatWithToolsInput {
  systemPrompt: string;
  userText: string;
  jsonMode?: boolean;
  temperature?: number;
  timeoutMs?: number;
  maxTokens?: number;
}

/** 带工具的最大轮次（不含收尾轮） */
export const TOOL_LOOP_MAX_ROUNDS = 3;

const DEFAULT_TEMPERATURE = 0.3;
const DEFAULT_TIMEOUT_MS = 300_000;

/**
 * 文本模型对话（可带工具）。ctx 缺省或 tools 为空 → 等价 textChat（行为零变化）。
 */
export async function chatWithTools(cfg: LlmEndpoint, input: ChatWithToolsInput, ctx?: TextToolContext): Promise<string> {
  if (!ctx || ctx.tools.length === 0) {
    return textChat(cfg, input);
  }

  const temperature = input.temperature ?? DEFAULT_TEMPERATURE;
  const timeoutMs = input.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const trace = { title: '工具调用 · LLM', systemPrompt: input.systemPrompt, userPrompt: input.userText };

  let messages: unknown[] = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  let used = 0;

  try {
    for (let round = 0; round < TOOL_LOOP_MAX_ROUNDS; round += 1) {
      const reachedLimit = used >= ctx.maxToolCalls;
      const res = await toolChatOnce(cfg, {
        messages,
        tools: ctx.tools,
        toolChoice: reachedLimit ? 'none' : 'auto',
        temperature,
        timeoutMs,
        maxTokens: input.maxTokens,
        ...trace,
      });
      messages = res.messages;

      if (reachedLimit) {
        if (res.content && res.content.trim()) return res.content;
        break;
      }
      if (res.toolCalls.length === 0) {
        if (res.content && res.content.trim()) return res.content;
        break;
      }

      for (const call of res.toolCalls) {
        for (const tc of call.tool_calls) {
          let resultText: string;
          if (used >= ctx.maxToolCalls) {
            resultText = '{"error":"已达本次会话的网页抓取上限，请基于已有信息直接输出最终结果"}';
          } else {
            used += 1;
            try {
              resultText = await ctx.execute(tc.function.name, tc.function.arguments);
            } catch (err) {
              const message = err instanceof Error ? err.message : String(err);
              resultText = JSON.stringify({ error: message.slice(0, 200) });
            }
          }
          messages = [...messages, { role: 'tool', tool_call_id: tc.id, content: resultText }];
        }
      }
    }

    // 收尾轮：强制无工具调用，逼模型输出最终 JSON / 正文。
    // 仍带 tools 数组，为规避「tools + response_format: json_object」不同厂商兼容性风险，不带 jsonMode，
    // 最终结果由调用方经 extractJson 解析（见设计文档第一节）。
    const finalRes = await toolChatOnce(cfg, {
      messages,
      tools: ctx.tools,
      toolChoice: 'none',
      temperature,
      timeoutMs,
      maxTokens: input.maxTokens,
      ...trace,
    });
    if (finalRes.content && finalRes.content.trim()) return finalRes.content;
    throw new Error('AI 服务返回内容为空');
  } catch {
    // 工具轮整体异常 → 回退一次无工具调用（保底，保证链路仍能产出结果）
    return textChat(cfg, { ...input });
  }
}
