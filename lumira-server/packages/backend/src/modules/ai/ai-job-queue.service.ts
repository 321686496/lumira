// lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.ts
// 调度层：FIFO 队列 + 并发闸门（并发数实时读 AI 设置）+ 停止 + 重启恢复。
// DB 为真相源，内存队列只保存「待执行的 jobId 顺序」。
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { AiJobStoreService, type AiJobStatus } from './ai-job.store';
import { AiPipelineJobService } from './ai-pipeline-job.service';

@Injectable()
export class AiJobQueueService implements OnModuleInit {
  private readonly logger = new Logger(AiJobQueueService.name);
  /** 待执行 jobId（FIFO，按 created_at 升序） */
  private readonly waiting: string[] = [];
  /** 正在执行的 jobId 集合 */
  private readonly running = new Set<string>();
  private draining = false;

  constructor(
    private readonly store: AiJobStoreService,
    private readonly aiConfigService: AiConfigService,
    private readonly pipeline: AiPipelineJobService,
  ) {}

  /** 重启恢复：queued 重新入队；running → interrupted（内存产物已丢） */
  async onModuleInit(): Promise<void> {
    await this.markInterrupted('running');
    const queued = await this.store.listQueued();
    for (const r of queued) if (!this.waiting.includes(r.id)) this.waiting.push(r.id);
    await this.store.setQueuePositions(this.waiting);
    if (queued.length) this.logger.log(`重启恢复：${queued.length} 个排队任务重新入队`);
    await this.drain();
  }

  /** 把残留的指定状态任务标记为 interrupted */
  private async markInterrupted(status: AiJobStatus): Promise<void> {
    const runningRows = await this.store.listJobs({ status, limit: 200, offset: 0 });
    for (const r of runningRows.items) {
      await this.store.updateJob(r.id, {
        status: 'interrupted',
        errorCode: 'interrupted',
        errorMessage: '后端重启导致任务中断，可点「继续」从当前阶段续跑',
        finishedAt: Math.floor(Date.now() / 1000),
      });
    }
  }

  /** 入队：仅当无人排队且有空位时才立即开跑；否则排到队尾，由 FIFO 出队决定何时开跑 */
  async enqueue(jobId: string): Promise<{ status: AiJobStatus; queuePos: number }> {
    const limit = await this.concurrency();
    if (this.running.size < limit && this.waiting.length === 0) {
      void this.run(jobId);
      return { status: 'running', queuePos: 0 };
    }
    if (!this.waiting.includes(jobId)) this.waiting.push(jobId);
    await this.store.setQueuePositions(this.waiting);
    const pos = this.waiting.indexOf(jobId) + 1;
    await this.store.updateJob(jobId, { status: 'queued', queuePos: pos });
    // 出队填充统一走 FIFO 的 drain；若本次 drain 恰好把它拉起，需如实回报 running/0
    await this.drain();
    if (this.running.has(jobId)) return { status: 'running', queuePos: 0 };
    const idx = this.waiting.indexOf(jobId);
    return { status: 'queued', queuePos: idx >= 0 ? idx + 1 : 0 };
  }

  /** 停止：running → 置停止标记（停在检查点）；queued → 取消排队 */
  async stop(jobId: string): Promise<{ stopped: boolean; status: AiJobStatus }> {
    if (this.running.has(jobId) && this.pipeline.requestStop(jobId)) {
      // 协作式停止：置停止标记，DB 行在 pipeline 的下一个检查点落库
      return { stopped: true, status: 'stopped' };
    }
    const idx = this.waiting.indexOf(jobId);
    if (idx >= 0) {
      this.waiting.splice(idx, 1);
      await this.store.setQueuePositions(this.waiting);
      await this.store.updateJob(jobId, {
        status: 'stopped',
        queuePos: 0,
        errorCode: 'aborted',
        errorMessage: '已取消排队',
        finishedAt: Math.floor(Date.now() / 1000),
      });
      return { stopped: true, status: 'stopped' };
    }
    return { stopped: false, status: (await this.store.findJob(jobId))?.status ?? 'done' };
  }

  /** 继续：从存储恢复内存态后重新入队（queued/running 无需继续） */
  async resume(jobId: string): Promise<{ resumed: boolean; status: AiJobStatus } | null> {
    const row = await this.store.findJob(jobId);
    if (!row) return null;
    if (row.status === 'running') return { resumed: false, status: 'running' };
    if (row.status === 'queued') return { resumed: false, status: 'queued' };
    if (row.status === 'done') return { resumed: false, status: 'done' };
    await this.pipeline.hydrate(jobId);
    const plan = await this.pipeline.prepareResume(jobId);
    if (!plan) return { resumed: false, status: row.status };
    const { status, queuePos } = await this.enqueue(jobId);
    return { resumed: true, status: queuePos > 0 ? 'queued' : status };
  }

  /** 出队填充空位 */
  private async drain(): Promise<void> {
    if (this.draining) return;
    this.draining = true;
    try {
      const limit = await this.concurrency();
      while (this.waiting.length && this.running.size < limit) {
        const next = this.waiting.shift()!;
        await this.store.setQueuePositions(this.waiting);
        await this.store.updateJob(next, { queuePos: 0 });
        void this.run(next);
      }
    } finally {
      this.draining = false;
    }
  }

  /** 执行一个任务并在结束后释放空位 */
  private async run(jobId: string): Promise<void> {
    this.running.add(jobId);
    try {
      // 执行前先 hydrate：对已在内存的 job 立即返回（幂等）；对重启后 queued 的 job
      // 从 detail.json 重建内存态（inputs/stages/pendingStages），否则 startJob 会因查无此 job 静默跳过
      if (!(await this.pipeline.hydrate(jobId))) {
        this.logger.warn(`任务 ${jobId} 无法从存储恢复（缺少详情文件），已跳过执行`);
      }
      await this.pipeline.startJob(jobId);
    } catch (err) {
      this.logger.error(`任务 ${jobId} 执行异常：${(err as Error).message}`);
    } finally {
      this.running.delete(jobId);
      void this.drain();
    }
  }

  /** 并发上限实时读 AI 设置（改动无需重启生效） */
  private async concurrency(): Promise<number> {
    const cfg = await this.aiConfigService.get();
    const n = 'configured' in cfg && cfg.configured ? cfg.jobConcurrency : 2;
    return Math.min(5, Math.max(1, n || 2));
  }
}