// lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.ts
// AI「识别 → 模板草稿」异步任务化（修复 Vercel/nginx 同步长请求被掐断）：
// 提交 → 立即返回 taskId，后台执行 analyze；前端轮询状态直到拿到 draft。
// 任务存内存 Map（单容器、结果瞬态；"任务不存在"由前端给出可重试提示），
// 与封面生图/剪影任务保持同一模式（见 ai-image-task.service.ts）。

import { BadRequestException, Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeService } from './ai-analyze.service';
import type { AiAnalyzeResult } from './ai-analyze.service';
import { runWithTrace, traceNote } from './llm-trace';
import type { AiTraceEvent } from './llm-trace';

export type AiAnalyzeTaskStatus = 'pending' | 'running' | 'done' | 'error';

export interface AiAnalyzeTask {
  id: string;
  status: AiAnalyzeTaskStatus;
  createdAt: number;
  /** 实时流程事件（追加式：阶段开始/结束 + 每步提示词与响应），后台轮询增量渲染 */
  events: AiTraceEvent[];
  /** 仅 done 时存在 */
  result?: AiAnalyzeResult;
  /** 仅 error 时存在 */
  error?: string;
}

/** 已完成/错误任务的保留时长（超时即清理，防草稿 JSON 占用内存） */
const RESULT_TTL_MS = 15 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;
/** 单任务事件上限（超出丢弃后续事件，兜住异常长流程的内存占用） */
const MAX_TRACE_EVENTS = 300;

@Injectable()
export class AiAnalyzeTaskService implements OnModuleDestroy {
  private readonly tasks = new Map<string, AiAnalyzeTask>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(private readonly aiAnalyzeService: AiAnalyzeService) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期任务 */
  private sweep(): void {
    const now = Date.now();
    for (const [id, task] of this.tasks) {
      if (now - task.createdAt > RESULT_TTL_MS) this.tasks.delete(id);
    }
  }

  /**
   * 提交识别任务：先快速失败（示例图与文字都缺 → 直接 400，避免用户空等），
   * 创建 pending 任务后后台执行并立即返回 taskId。
   */
  async submit(
    image: UploadFile | undefined,
    text: string | undefined,
    extra: { textDesc?: string | null; creationReq?: string | null; poseCount?: string | null } = {},
  ): Promise<{ taskId: string }> {
    if (!image && !(text ?? '').trim()) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    const id = `anl_${nanoid(16)}`;
    this.tasks.set(id, { id, status: 'pending', createdAt: Date.now(), events: [] });
    void this.run(id, image, text, extra);
    return { taskId: id };
  }

  /** 后台执行：置 running → analyze → 置 done 存 draft/warnings；异常置 error 写错误信息。
   *  analyze 全程在 trace 采集上下文内跑，各阶段/提示词/响应按发生顺序落到 task.events。 */
  private async run(
    id: string,
    image: UploadFile | undefined,
    text: string | undefined,
    extra: { textDesc?: string | null; creationReq?: string | null; poseCount?: string | null },
  ): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    const sink = (ev: Omit<AiTraceEvent, 'seq' | 'ts'>): void => {
      if (task.events.length >= MAX_TRACE_EVENTS) return;
      task.events.push({ ...ev, seq: task.events.length + 1, ts: Date.now() });
    };
    try {
      const result = await runWithTrace(sink, async () => {
        traceNote('task', '识别任务已提交', `输入：${image ? '示例图' : '无图'}${(text ?? '').trim() ? ' + 文字描述' : ''}`);
        return this.aiAnalyzeService.analyze(image, text, extra);
      });
      task.status = 'done';
      task.result = result;
      sink({ type: 'note', step: 'task', title: '识别完成', status: 'done', resultBrief: '草稿已生成，可进入下一步' });
    } catch (err) {
      const msg = (err as Error)?.message || '识别失败，请重试';
      task.status = 'error';
      task.error = msg;
      sink({ type: 'note', step: 'task', title: '识别失败', status: 'fail', error: msg });
    }
  }

  /** 查询任务；不存在返回 null（前端据此提示可重试） */
  get(taskId: string): AiAnalyzeTask | null {
    return this.tasks.get(taskId) ?? null;
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}