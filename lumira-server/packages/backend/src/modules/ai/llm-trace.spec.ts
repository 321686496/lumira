// lumira-server/packages/backend/src/modules/ai/llm-trace.spec.ts
// 实时流程采集单测：阶段事件（running/done/fail）、LLM 调用（提示词+响应）归属当前阶段、
// 无采集上下文时 no-op、超长文本截断标注。

import { runWithTrace, traceStep, traceNote, traceLlmCall, hasTrace, TRACE_TEXT_CAP } from './llm-trace';
import type { AiTraceEvent } from './llm-trace';
import { textChat } from './llm-client';

function collect(): { events: Omit<AiTraceEvent, 'seq' | 'ts'>[]; sink: (e: Omit<AiTraceEvent, 'seq' | 'ts'>) => void } {
  const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];
  return { events, sink: (e) => events.push(e) };
}

describe('llm-trace', () => {
  it('无采集上下文：traceStep/traceNote/traceLlmCall 均 no-op，业务照常执行', async () => {
    expect(hasTrace()).toBe(false);
    const value = await traceStep('step', '阶段', async () => 42);
    expect(value).toBe(42);
    expect(traceNote('step', '阶段', 'x')).toBeUndefined();
    expect(traceLlmCall({ model: 'm' })).toBeNull();
  });

  it('traceStep：记录 running → done（含 brief 与耗时）', async () => {
    const { events, sink } = collect();
    const value = await runWithTrace(sink, () => traceStep('research', '趋势研究', async () => ['a', 'b'], (v) => `${v.length} 条`));

    expect(value).toEqual(['a', 'b']);
    expect(events.map((e) => [e.type, e.step, e.title, e.status])).toEqual([
      ['step', 'research', '趋势研究', 'running'],
      ['step', 'research', '趋势研究', 'done'],
    ]);
    expect(events[1]!.resultBrief).toBe('2 条');
    expect(typeof events[1]!.durationMs).toBe('number');
  });

  it('traceStep：失败记录 fail + error 后原样抛出', async () => {
    const { events, sink } = collect();
    await expect(
      runWithTrace(sink, () => traceStep('describe', '示例图识别', async () => { throw new Error('识别超时'); })),
    ).rejects.toThrow('识别超时');
    expect(events[1]).toMatchObject({ status: 'fail', error: '识别超时' });
  });

  it('LLM 调用归属当前阶段：记录提示词与响应', async () => {
    const { events, sink } = collect();
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ choices: [{ message: { content: '模型回复' } }] }), { status: 200 }),
    );

    await runWithTrace(sink, () =>
      traceStep('analyze', '文字构思模板草稿', () =>
        textChat({ provider: 't', baseUrl: 'https://x/v1', apiKey: 'k', model: 'qwen-plus' }, {
          systemPrompt: '系统提示词',
          userText: '用户提示词',
        }),
      ),
    );
    fetchMock.mockRestore();

    const llmEvents = events.filter((e) => e.type === 'llm');
    expect(llmEvents).toHaveLength(2); // running（带提示词）+ done（带响应）
    expect(llmEvents[0]).toMatchObject({
      step: 'analyze', // 归属当前阶段，而非泛化 step
      status: 'running',
      model: 'qwen-plus',
      systemPrompt: '系统提示词',
      userPrompt: '用户提示词',
    });
    expect(llmEvents[1]).toMatchObject({ step: 'analyze', status: 'done', response: '模型回复' });
  });

  it('超长提示词/响应截断并标注原文长度', async () => {
    const { events, sink } = collect();
    const long = 'x'.repeat(TRACE_TEXT_CAP + 10);
    await runWithTrace(sink, async () => {
      const h = traceLlmCall({ model: 'm', systemPrompt: long })!;
      h.done(long);
    });
    expect(events[0]!.systemPrompt).toContain('已截断');
    expect(events[1]!.response).toContain(`原长 ${long.length} 字`);
  });
});