// lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts
// 封面生图异步任务化（修复 Vercel serverless 同步长请求被掐断）：提交 → 立即返回 taskId，
// 后台执行生图；前端轮询状态。任务存在内存 Map（单容器、结果瞬态；重启丢失由前端针对
// "任务不存在" 给出可重试提示）。仅生图改异步，识别/剪影保持同步。

import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { AiGenerateImageService } from './ai-generate-image.service';

export type ImageTaskStatus = 'pending' | 'running' | 'done' | 'error';

export interface ImageTask {
  id: string;
  status: ImageTaskStatus;
  createdAt: number;
  /** 仅 done 时存在 */
  result?: { image: string; mimeType: string };
  /** 仅 error 时存在 */
  error?: string;
}

/** 已完成/错误任务的保留时长（超过即清理，防 base64 结果占用内存） */
const RESULT_TTL_MS = 15 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;

@Injectable()
export class AiImageTaskService implements OnModuleDestroy {
  private readonly tasks = new Map<string, ImageTask>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiConfigService: AiConfigService,
  ) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期任务（含 done/error 结果） */
  private sweep(): void {
    const now = Date.now();
    for (const [id, task] of this.tasks) {
      if (now - task.createdAt > RESULT_TTL_MS) this.tasks.delete(id);
    }
  }

  /**
   * 提交生图任务：先快速失败（未配置/未启用时 getActiveConfig 抛 503，避免用户空等），
   * 创建 pending 任务后后台执行并立即返回 taskId。
   */
  async submit(
    reference: UploadFile | undefined,
    metaJson: string | null,
  ): Promise<{ taskId: string }> {
    await this.aiConfigService.getActiveConfig();
    const id = `img_${nanoid(16)}`;
    this.tasks.set(id, { id, status: 'pending', createdAt: Date.now() });
    void this.run(id, reference, metaJson);
    return { taskId: id };
  }

  /** 后台执行（复用 AiGenerateImageService.generate，内部已有各类超时兜底，不会无限挂起） */
  private async run(
    id: string,
    reference: UploadFile | undefined,
    metaJson: string | null,
  ): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    try {
      const r = await this.aiGenerateImageService.generate(reference, metaJson);
      task.status = 'done';
      task.result = { image: r.base64, mimeType: r.mimeType };
    } catch (err) {
      task.status = 'error';
      task.error = (err as Error)?.message || '生图失败，请重试';
    }
  }

  /** 查询任务；不存在返回 null（前端据此提示可重试） */
  get(taskId: string): ImageTask | null {
    return this.tasks.get(taskId) ?? null;
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}