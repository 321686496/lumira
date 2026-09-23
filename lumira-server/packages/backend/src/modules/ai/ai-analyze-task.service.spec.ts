// lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.spec.ts
// 识别任务实时流程事件单测：submit 快速失败 / 后台 done 且事件流按序追加 /
// 服务内阶段与 LLM 调用归属到任务事件流 / 失败落 fail 事件 / get 不存在 null。

import { BadRequestException } from '@nestjs/common';
import { AiAnalyzeTaskService } from './ai-analyze-task.service';
import { AiAnalyzeService } from './ai-analyze.service';
import { traceNote, traceStep } from './llm-trace';
import { textChat } from './llm-client';

describe('AiAnalyzeTaskService', () => {
  let service: AiAnalyzeTaskService;
  let analyzeMock: jest.Mock;

  beforeEach(() => {
    analyzeMock = jest.fn();
    service = new AiAnalyzeTaskService({ analyze: analyzeMock } as unknown as AiAnalyzeService);
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.restoreAllMocks();
  });

  async function waitStatus(id: string, status: string): Promise<void> {
    for (let i = 0; i < 12000; i++) {
      if (service.get(id)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for status ${status}`);
  }

  it('submit 快速失败：示例图与文字都缺 → 400，且不调用识别服务', async () => {
    await expect(service.submit(undefined, '   ')).rejects.toThrow(BadRequestException);
    expect(analyzeMock).not.toHaveBeenCalled();
  });

  it('后台执行完成：done + 结果，事件流首尾为「任务已提交」「识别完成」', async () => {
    analyzeMock.mockResolvedValue({ draft: { title: '草稿' }, warnings: [] });

    const { taskId } = await service.submit(undefined, '文字描述');
    expect(taskId).toMatch(/^anl_/);

    await waitStatus(taskId, 'done');
    const task = service.get(taskId);
    expect(task?.status).toBe('done');
    expect(task?.result).toEqual({ draft: { title: '草稿' }, warnings: [] });

    const titles = task?.events.map((e) => e.title) ?? [];
    expect(titles[0]).toBe('识别任务已提交');
    expect(titles[titles.length - 1]).toBe('识别完成');
    // seq 严格递增 1..n（前端据此 since 增量拉取）
    expect(task?.events.map((e) => e.seq)).toEqual(task?.events.map((_, i) => i + 1));
  });

  it('识别服务内的阶段与 LLM 调用按发生顺序落入任务事件流（含提示词与响应）', async () => {
    analyzeMock.mockImplementation(async () => {
      traceNote('research', '趋势研究', '2 条参考来源');
      // 真实 llm-client 在采集上下文内会记录提示词与响应
      await traceStep('analyze', '文字构思模板草稿', () =>
        textChat(
          { provider: 't', baseUrl: 'https://x/v1', apiKey: 'k', model: 'qwen-plus' },
          { systemPrompt: '系统提示词', userText: '用户提示词' },
        ),
      );
      return { draft: {}, warnings: [] };
    });
    jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ choices: [{ message: { content: '模型回复' } }] }), { status: 200 }),
    );

    const { taskId } = await service.submit(undefined, '文字描述');
    await waitStatus(taskId, 'done');
    const events = service.get(taskId)?.events ?? [];

    const llm = events.filter((e) => e.type === 'llm');
    expect(llm[0]).toMatchObject({ step: 'analyze', status: 'running', systemPrompt: '系统提示词' });
    expect(llm[1]).toMatchObject({ step: 'analyze', status: 'done', response: '模型回复' });
    // 阶段事件带 running/done 两条，且 done 带耗时
    const stepEvents = events.filter((e) => e.type === 'step' && e.step === 'analyze');
    expect(stepEvents.map((e) => e.status)).toEqual(['running', 'done']);
    expect(typeof stepEvents[1]!.durationMs).toBe('number');
  });

  it('识别失败：状态 error，错误可读，且补一条 fail 事件', async () => {
    analyzeMock.mockRejectedValue(new Error('AI 上游错误（HTTP 500）：boom'));

    const { taskId } = await service.submit(undefined, '文字描述');
    await waitStatus(taskId, 'error');
    const task = service.get(taskId);
    expect(task?.error).toBe('AI 上游错误（HTTP 500）：boom');
    expect(task?.result).toBeUndefined();
    expect(task?.events[task.events.length - 1]).toMatchObject({
      title: '识别失败',
      status: 'fail',
      error: 'AI 上游错误（HTTP 500）：boom',
    });
  });

  it('get 不存在的 taskId 返回 null', () => {
    expect(service.get('anl_nope')).toBeNull();
  });
});