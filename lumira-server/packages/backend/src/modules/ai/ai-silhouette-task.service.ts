// 剪影异步任务化：本地 ONNX / AI 生图都可能超过网关超时，提交后后台执行，前端轮询。

import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { UploadFile } from '../templates/admin-templates.service';
import { AiSilhouetteService, SilhouetteGenResult } from './ai-generate-silhouette.service';

export type SilhouetteTaskStatus = 'pending' | 'running' | 'done' | 'error';

export interface SilhouetteTask {
  id: string;
  status: SilhouetteTaskStatus;
  createdAt: number;
  result?: SilhouetteGenResult;
  error?: string;
}

const RESULT_TTL_MS = 15 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;

@Injectable()
export class AiSilhouetteTaskService implements OnModuleDestroy {
  private readonly tasks = new Map<string, SilhouetteTask>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(private readonly aiSilhouetteService: AiSilhouetteService) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    this.sweeper.unref?.();
  }

  private sweep(): void {
    const now = Date.now();
    for (const [id, task] of this.tasks) {
      if (now - task.createdAt > RESULT_TTL_MS) this.tasks.delete(id);
    }
  }

  async submit(image: UploadFile, metaJson: string | null): Promise<{ taskId: string }> {
    const id = `sil_${nanoid(16)}`;
    this.tasks.set(id, { id, status: 'pending', createdAt: Date.now() });
    void this.run(id, image, metaJson);
    return { taskId: id };
  }

  private async run(id: string, image: UploadFile, metaJson: string | null): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    try {
      task.result = await this.aiSilhouetteService.generate(image, metaJson);
      task.status = 'done';
    } catch (err) {
      task.status = 'error';
      task.error = (err as Error)?.message || '剪影生成失败，请重试';
    }
  }

  get(taskId: string): SilhouetteTask | null {
    return this.tasks.get(taskId) ?? null;
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}
