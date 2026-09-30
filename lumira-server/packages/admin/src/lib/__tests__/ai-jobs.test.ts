// 任务队列前端纯函数单测：状态映射 / 进度文案 / 耗时格式化 / URL→File
import { describe, expect, it, vi } from 'vitest';
import { JOB_STATUS_META, formatJobElapsed, jobStageProgressText, fetchJobFile } from '@/lib/ai-jobs';
import type { AiJobListItem } from '@/lib/ai-jobs';

function item(over: Partial<AiJobListItem> = {}): AiJobListItem {
  return {
    id: 'job_1', title: 't', status: 'running', currentStage: 'image',
    progress: { poseTotal: 3, poseDone: 1, silTotal: 3, silDone: 0 },
    queuePos: 0, errorCode: null, errorMessage: null,
    createdAt: 1, startedAt: 1, finishedAt: null, ...over,
  };
}

describe('JOB_STATUS_META', () => {
  it('六种状态都有中文标签', () => {
    expect(JOB_STATUS_META.queued.label).toBe('排队中');
    expect(JOB_STATUS_META.running.label).toBe('进行中');
    expect(JOB_STATUS_META.done.label).toBe('已完成');
    expect(JOB_STATUS_META.error.label).toBe('失败');
    expect(JOB_STATUS_META.stopped.label).toBe('已停止');
    expect(JOB_STATUS_META.interrupted.label).toBe('已中断');
  });
});

describe('jobStageProgressText', () => {
  it('排队中显示排位', () => {
    expect(jobStageProgressText(item({ status: 'queued', queuePos: 2 }))).toBe('排队中 · 第 2 位');
  });

  it('姿势图阶段显示第 x/y 张', () => {
    expect(jobStageProgressText(item())).toBe('姿势图 2/3');
  });

  it('已完成显示剪影产出', () => {
    expect(jobStageProgressText(item({ status: 'done', currentStage: null, progress: { poseTotal: 3, poseDone: 3, silTotal: 3, silDone: 3 } })))
      .toBe('已完成 · 3 张姿势图 / 3 张剪影');
  });
});

describe('formatJobElapsed', () => {
  it('结束后按 finishedAt 定格', () => {
    expect(formatJobElapsed(100, 165)).toBe('1分5秒');
  });

  it('未开始返回短横线', () => {
    expect(formatJobElapsed(null, null)).toBe('—');
  });
});

describe('fetchJobFile', () => {
  it('按 URL 取回并包装为 File', async () => {
    const blob = new Blob(['x'], { type: 'image/png' });
    vi.stubGlobal('fetch', vi.fn(async () => new Response(blob, { status: 200, headers: { 'content-type': 'image/png' } })) as never);
    const file = await fetchJobFile('/uploads/ai-jobs/job_1/pose-0.png', 'pose-0.png');
    expect(file.name).toBe('pose-0.png');
    expect(file.type).toBe('image/png');
    vi.unstubAllGlobals();
  });
});