# AI 一键生成：识别 & 姿势图实时过程溯源优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让后台 AI 一键生成页的识别实时过程更清晰（每阶段一行、状态正确流转、常驻步骤栏上方可回看），并为姿势图生成新增可精确到每张图的实时过程 trace。

**Architecture:** 后端把批量姿势图任务事件化（每张 `startedAt/finishedAt/prompt/model` + `events[]/seq` 增量事件日志，状态接口支持 `?since=` 增量）；前端新增常驻「生成过程」面板（步骤栏上方、Tab 切换、运行中展开/结束后收拢窄条），重构识别 trace 为阶段时间线，并新增姿势图逐张 trace 组件。

**Tech Stack:** NestJS（backend）、Next.js App Router + Tailwind + shadcn/ui（admin）、TypeScript。

## Global Constraints

- 后端改动仅在 `lumira-server/packages/backend/**`、`packages/shared/**`、`packages/admin/**` 内进行，不动 `lumira-app/`（废弃 uni-app 原型）。
- 每次完成一个后端或后台任务后，必须 `commit` 并 **push 到两个远程**：`git push origin master`（gitee）与 `git push github master`（github）。
- 前端所有 UI 遵循现有 shadcn/ui + Tailwind 组件范式，不引入新 UI 库。
- 事件日志需设上限（`MAX_TRACE_EVENTS`），防止内存无限增长。
- 后端命令：`pnpm --filter @lumira/backend build`（tsc 校验）。后台命令：`pnpm --filter @lumira/admin build`（next build 含类型校验）。

---
### Task 1: 后端 — AiGenerateImageService.generate 返回 prompt / model

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts:97-146`

**Interfaces:**
- Produces: `AiGenerateImageService.generate(...): Promise<GenerateImageResult & { prompt: string; model: string }>` — 在原来的 `{ base64, mimeType }` 基础上附带实际发送的生图提示词 `prompt`（已加固）与生图模型名 `model`。Task 2 依赖此返回。

- [ ] **Step 1: 改返回值类型**

在 `ai-generate-image.service.ts` 中将 `generate` 的返回类型从 `Promise<GenerateImageResult>` 改为 `Promise<GenerateImageResult & { prompt: string; model: string }>`。

```ts
  async generate(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    researchJson?: string | null,
  ): Promise<GenerateImageResult & { prompt: string; model: string }> {
```

- [ ] **Step 2: 返回附带 prompt / model**

将末尾的 `return imageSemaphore.run(...)` 改为先 await 再合并返回：

```ts
    // 网络生图（含 qwen 异步轮询/结果下载）纳入全局并发闸门，避免并发打爆上游厂商
    // prompt 出口统一照片写实加固（媒介声明 + 真实材质 + 反动漫负面清单）
    const hardenedPrompt = hardenPhotoRealism(prompt);
    const imageResult = await imageSemaphore.run(() => generateImage(cfg.image, {
      prompt: hardenedPrompt,
      size: mapSize(cfg.image.provider, extractAspectRatio(draft)),
      referenceBase64: reference?.buffer.toString('base64'),
      referenceMime: reference?.mimetype,
    }));
    return { ...imageResult, prompt: hardenedPrompt, model: cfg.image.model };
```

- [ ] **Step 3: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/backend build`
Expected: 编译通过，无 `prompt`/`model` 相关类型错误（`cfg.image.model` 需类型存在，若报错则为 `cfg.image` 增加 `model: string` 读取路径或回退 `''`）。

- [ ] **Step 4: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
git commit -m "feat(backend): 生图返回实际 prompt 与模型名，供姿势图 trace 使用"
git push origin master
git push github master
```

---
### Task 2: 后端 — AiImageTaskService 批量事件化

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts`

**Interfaces:**
- Consumes: `generateWithRetry` 返回 `{ base64, mimeType, prompt, model }`（源自 Task 1）。
- Produces:
  - `ImageTask` 新增 `startedAt/result` 侧字段：`startedAt?: number`、`finishedAt?: number`、`prompt?: string`、`model?: string`。
  - 新导出类型 `AiBatchImageTraceEvent`、新常量 `MAX_TRACE_EVENTS = 1000`。
  - `AiBatchProgress` 新增 `events: AiBatchImageTraceEvent[]` 与 `lastSeq: number`。
  - `AiBatchResultItem` 新增 `startedAt?: number`、`finishedAt?: number`、`prompt?: string`、`model?: string`。
  - `getBatch(batchId: string, since?: number): AiBatchProgress | null`。
  - Task 3 依赖 `getBatch(batchId, since)`。

- [ ] **Step 1: 新增事件类型与常量**

在文件顶部类型区，`AiBatchResultItem` 追加字段，并新增事件类型与上限：

```ts
/** 批次中单张姿势图的结果项 */
export interface AiBatchResultItem {
  index: number;
  taskId?: string;
  status: ImageTaskStatus;
  image?: string;
  mimeType?: string;
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}

/** 批量姿势图的单条实时 trace 事件（仿 analyze 的 seq 增量机制） */
export interface AiBatchImageTraceEvent {
  seq: number;
  ts: number;
  /** 对应姿势图 index（0-based） */
  index: number;
  title: string;
  status: ImageTaskStatus;
  prompt?: string;
  model?: string;
  error?: string;
  durationMs?: number;
}
```

在 `AiBatchProgress` 中追加：

```ts
export interface AiBatchProgress {
  batchId: string;
  total: number;
  completed: number;
  current: number;
  status: ImageTaskStatus;
  results: AiBatchResultItem[];
  createdAt: number;
  /** 实时事件日志（按 seq 递增；前端按 lastSeq 增量拉取） */
  events: AiBatchImageTraceEvent[];
  lastSeq: number;
}
```

在常量区追加：

```ts
/** 批次 trace 事件上限（超出静默丢弃，防空涨内存） */
const MAX_TRACE_EVENTS = 1000;
```

- [ ] **Step 2: ImageTask 追加时间戳/prompt/model 字段**

```ts
export interface ImageTask {
  id: string;
  status: ImageTaskStatus;
  createdAt: number;
  batchId?: string;
  batch?: {
    metaJson: string;
    extraPrompt?: string | null;
    research?: string | null;
    dependencyTaskId?: string;
    dependents?: string[];
  };
  result?: { image: string; mimeType: string };
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}
```

- [ ] **Step 3: 新增 emitBatchEvent 与 indexOfTask 辅助方法**

在 `AiImageTaskService` 类中添加两个私有方法（放在 `refreshBatch` 前后均可）：

```ts
  /** 向批次追加一条 trace 事件（带 seq/ts；达上限静默丢弃） */
  private emitBatchEvent(
    batchId: string | undefined,
    ev: Omit<AiBatchImageTraceEvent, 'seq' | 'ts'>,
  ): void {
    if (!batchId) return;
    const batch = this.batches.get(batchId);
    if (!batch || batch.events.length >= MAX_TRACE_EVENTS) return;
    batch.lastSeq += 1;
    batch.events.push({ ...ev, seq: batch.lastSeq, ts: Date.now() });
  }

  /** 由 taskId 反查其在批次内的 index（-1 表示未归属任何批次） */
  private indexOfTask(taskId: string): number {
    let found = -1;
    for (const [, entries] of this.batchEntries) {
      const hit = entries.find((e) => e.taskId === taskId);
      if (hit) {
        found = hit.index;
        break;
      }
    }
    return found;
  }
```

- [ ] **Step 4: 初始化批次的 events/lastSeq 并发射 pending 事件**

在 `submitBatch` 中创建 `this.batches.set(batchId, {...})` 时补上 `events: []`、`lastSeq: 0`：

```ts
    this.batches.set(batchId, {
      batchId,
      total: entries.length,
      completed: 0,
      current: 1,
      status: 'pending',
      results: entries.map(({ index }) => ({ index, status: 'pending' })),
      createdAt: Date.now(),
      events: [],
      lastSeq: 0,
    });
```

随后（`this.batches.set` 之后、`run(firstTaskId...)` 之前）为每张补发 `pending` 事件：

```ts
    entries.forEach(({ index }) => {
      this.emitBatchEvent(batchId, { index, title: `姿势图 #${index + 1} 排队中`, status: 'pending' });
    });

    if (!anchor?.batch) throw new BadRequestException('批量姿势任务初始化失败');
```

- [ ] **Step 5: run() 记录时间戳并发射 running / done / error 事件**

改写 `run` 方法体：

```ts
  /** 后台执行（复用 AiGenerateImageService.generate，内部已有各类超时兜底，不会无限挂起） */
  private async run(
    id: string,
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    task.startedAt = Date.now();
    const index = this.indexOfTask(id);
    this.emitBatchEvent(task.batchId, { index, title: `姿势图 #${index + 1} 生成中`, status: 'running' });
    this.refreshBatch(task.batchId);
    try {
      const r = await this.generateWithRetry(reference, metaJson, extraPrompt, research);
      task.status = 'done';
      task.result = { image: r.base64, mimeType: r.mimeType };
      task.prompt = r.prompt;
      task.model = r.model;
      task.finishedAt = Date.now();
      this.emitBatchEvent(task.batchId, {
        index,
        title: `姿势图 #${index + 1} 完成`,
        status: 'done',
        durationMs: task.startedAt ? Date.now() - task.startedAt : undefined,
        prompt: task.prompt,
        model: task.model,
      });
      void this.startDependents(id);
    } catch (err) {
      task.status = 'error';
      task.error = (err as Error)?.message || '生图失败，请重试';
      task.finishedAt = Date.now();
      this.emitBatchEvent(task.batchId, {
        index,
        title: `姿势图 #${index + 1} 失败`,
        status: 'error',
        error: task.error,
        durationMs: task.startedAt ? Date.now() - task.startedAt : undefined,
      });
      this.failDependents(id, task.error);
    }
    this.refreshBatch(task.batchId);
  }
```

- [ ] **Step 6: generateWithRetry 透传 prompt/model**

将 `generateWithRetry` 返回类型与 `return this.aiGenerateImageService.generate(...)` 保持 Task 1 的扩展返回（无需改逻辑，类型随之透传）：

```ts
  private async generateWithRetry(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<{ base64: string; mimeType: string; prompt: string; model: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      try {
        return await this.aiGenerateImageService.generate(reference, metaJson, extraPrompt, research);
      } catch (err) { /* 保持不变 */ }
    }
    throw lastError instanceof Error ? lastError : new Error('生图失败，请重试');
  }
```

- [ ] **Step 7: refreshBatch 透出每张时间戳/prompt/model**

在 `refreshBatch` 的 `results.push({ ... })` 处补上：

```ts
      results.push({
        index,
        taskId: t?.id,
        status,
        image: t?.result?.image,
        mimeType: t?.result?.mimeType,
        error: t?.error,
        startedAt: t?.startedAt,
        finishedAt: t?.finishedAt,
        prompt: t?.prompt,
        model: t?.model,
      });
```

- [ ] **Step 8: getBatch 支持 since 增量**

```ts
  /** 查询批次进度；support since 增量（返回 seq > since 的事件副本）。不存在返回 null */
  getBatch(batchId: string, since?: number): AiBatchProgress | null {
    const batch = this.batches.get(batchId);
    if (!batch) return null;
    if (typeof since === 'number' && since > 0) {
      return { ...batch, events: batch.events.filter((e) => e.seq > since) };
    }
    return batch;
  }
```

- [ ] **Step 9: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/backend build`
Expected: 编译通过。

- [ ] **Step 10: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts
git commit -m "feat(backend): 批量姿势图任务事件化，支持逐张实时过程与 since 增量"
git push origin master
git push github master
```

---
### Task 3: 后端 — 控制器 batch 状态接口支持 ?since=

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`

**Interfaces:**
- Consumes: `AiImageTaskService.getBatch(batchId, since?)`（Task 2）。
- Produces: `GET ai-generate-image/batch/:batchId?since=N` 按 `since` 增量返回 `AiBatchProgress`（`events` 仅含 `seq>since`）。

- [ ] **Step 1: 确认引入 @Query**

查看文件顶部 `@nestjs/common` import 是否含 `Query`；若否，追加：

```ts
import { ..., Query } from '@nestjs/common';
```

- [ ] **Step 2: 改写 getImageBatch**

```ts
  /** 查询批量姿势图进度（total/completed/current/status/results/events）；支持 ?since= 增量拉取事件；批次不存在则 404 */
  @Get('ai-generate-image/batch/:batchId')
  async getImageBatch(@Param('batchId') batchId: string, @Query('since') since?: string) {
    const batch = this.aiImageTaskService.getBatch(batchId, since ? Number(since) : undefined);
    if (!batch) throw new NotFoundException('Image batch not found');
    return batch;
  }
```

- [ ] **Step 3: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/backend build`
Expected: 编译通过。

- [ ] **Step 4: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts
git commit -m "feat(backend): 姿势图批量状态接口支持 since 增量"
git push origin master
git push github master
```

---
### Task 4: 后台 — 类型对齐

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`

**Interfaces:**
- Produces: `AiBatchResultItem`、`AiBatchStatusResult` 更新字段，新类型 `AiBatchImageTraceEvent`（与后端一致）。Task 5/6/8/9 依赖。

- [ ] **Step 1: 更新 AiBatchResultItem 与 AiBatchStatusResult，新增事件类型**

在 `admin.ts` 的批量类型处（`AiBatchResultItem` L561-567、`AiBatchStatusResult` L570-577）替换为：

```ts
/** 批次内单张姿势图结果项（按 index 排序） */
export interface AiBatchResultItem {
  index: number;
  status: 'pending' | 'running' | 'done' | 'error';
  image?: string;
  mimeType?: string;
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}

/** 批量姿势图的单条实时 trace 事件（seq 增量拉取与去重依据） */
export interface AiBatchImageTraceEvent {
  seq: number;
  ts: number;
  index: number;
  title: string;
  status: 'pending' | 'running' | 'done' | 'error';
  prompt?: string;
  model?: string;
  error?: string;
  durationMs?: number;
}

/** 批量姿势图进度（total/completed/current/status/results/events；status=done 即全部处理完毕） */
export interface AiBatchStatusResult {
  batchId: string;
  total: number;
  completed: number;
  current: number;
  status: 'pending' | 'running' | 'done' | 'error';
  results: AiBatchResultItem[];
  createdAt: number;
  events: AiBatchImageTraceEvent[];
  lastSeq: number;
}
```

- [ ] **Step 2: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 类型校验通过（构建成功）。

- [ ] **Step 3: 提交并推送**

```bash
git add lumira-server/packages/admin/src/types/admin.ts
git commit -m "feat(admin): 同步批量姿势图事件 trace 类型"
git push origin master
git push github master
```

---
### Task 5: 后台 — batch 状态 action 支持 since 增量

**Files:**
- Modify: `lumira-server/packages/admin/src/actions/ai.ts`（`aiGenerateImageBatchStatusAction`，约 L110-119）

**Interfaces:**
- Consumes: `AiBatchStatusResult`（Task 4）。
- Produces: `aiGenerateImageBatchStatusAction(batchId: string, since?: number): Promise<AiBatchStatusResult | { error: string }>`。Task 6 依赖。

- [ ] **Step 1: 改写 action 支持 since**

将现有 `aiGenerateImageBatchStatusAction` 改为：

```ts
export async function aiGenerateImageBatchStatusAction(batchId: string, since?: number) {
  const qs = typeof since === 'number' && since > 0 ? `?since=${since}` : '';
  return adminFetch<AiBatchStatusResult>(`/templates/ai-generate-image/batch/${batchId}${qs}`);
}
```

（对齐该文件内相邻 action 的写法与返回处理；若现有实现返回结构不同，按现有模式保留。）

- [ ] **Step 2: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过。

- [ ] **Step 3: 提交并推送**

```bash
git add lumira-server/packages/admin/src/actions/ai.ts
git commit -m "feat(admin): 批量姿势图状态查询支持 since 增量拉取事件"
git push origin master
git push github master
```

---
### Task 6: 后台 — generateAiPoseImages 消费事件，回调逐张实时过程

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts`

**Interfaces:**
- Consumes: `AiBatchImageTraceEvent`（Task 4）、`aiGenerateImageBatchStatusAction(batchId, since)`（Task 5）。
- Produces: `generateAiPoseImages(options)` 新增参数 `onEvents?: (events: AiBatchImageTraceEvent[]) => void`（按 since 增量累积后回调）。Task 9/10 依赖。

- [ ] **Step 1: 类型导入与签名**

在 `ai-task.ts` 的 import 中加 `AiBatchImageTraceEvent`，并在 `generateAiPoseImages` 的 options 类型加 `onEvents`：

```ts
      onResult?: (result: AiTaskFileResult) => void;
      onProgress?: (progress: AiPoseProgress) => void;
      /** 逐张实时过程事件（按 seq 增量累积；用于可溯源的姿势图过程展示） */
      onEvents?: (events: AiBatchImageTraceEvent[]) => void;
```

并在解构处加入 `onEvents`。

- [ ] **Step 2: 轮询循环内累积事件**

在 `generateAiPoseImages` 中，`const onResultFile = new Set<number>();` 附近加入：

```ts
    let since = 0;
    const trace: AiBatchImageTraceEvent[] = [];
```

在循环内拿到 `res` 后、`emitProgress(res)` 之前加入吸收逻辑：

```ts
      // 增量吸收实时过程事件（按 seq 去重）
      if ((res as AiBatchStatusResult).events?.length) {
        since = (res as AiBatchStatusResult).lastSeq ?? since;
        trace.push(...(res as AiBatchStatusResult).events!);
        onEvents?.(trace.slice());
      }
```

并将轮询调用改为传 `since`：

```ts
      const res = await aiGenerateImageBatchStatusAction(batchId, since);
```

（`res.events`/`res.lastSeq` 在 Task 4 类型中已存在，`AiBatchStatusResult` 需置换原本的 `AiBatchStatusResult` 轮询返回类型，保证 `results`/`events` 均可访问。）

- [ ] **Step 3: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过。

- [ ] **Step 4: 提交并推送**

```bash
git add lumira-server/packages/admin/src/lib/ai-task.ts
git commit -m "feat(admin): generateAiPoseImages 透出逐张实时过程事件"
git push origin master
git push github master
```

---
### Task 7: 后台 — AnalyzeTraceStream 重构为阶段时间线

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx`（整文件重写）

**Interfaces:**
- Consumes: `AiTraceEvent`（不变）。
- Produces: 同名 `AnalyzeTraceStream({ events, running?, title?, bodyClassName?, className? })`。行为变化：每阶段**一行**、状态原位从 happens `running → done/fail`；LLM/检索调用折叠收纳到阶段下。Task 9/10 依赖。

- [ ] **Step 1: 重写为阶段时间线**

整文件替换为（保留 formatted time/ms 辅助函数，新增按阶段归组逻辑）：

```tsx
'use client';

// src/components/ai-create/analyze-trace-stream.tsx
// AI 识别流程实时事件流（阶段时间线版）：
// 把后端扁平事件按阶段归组——每个阶段只渲染一行，状态原位 running→done/fail 流转，
// 消除"每阶段两行"与"残留执行中"；该阶段的 LLM/检索调用折叠收纳到阶段下，默认收拢。
// 运行中自动滚底（用户上滑回看不打断），提示词/响应可折叠。
// 数据来源：后端 llm-trace 事件流（task.events），前端按 seq 增量拉取后累积渲染。

import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import type { AiTraceEvent, AiTraceEventStatus } from '@/types/admin';

interface AnalyzeTraceStreamProps {
  events: AiTraceEvent[];
  running?: boolean;
  title?: string | null;
  bodyClassName?: string;
  className?: string;
}

function formatDuration(ms?: number): string | null {
  if (typeof ms !== 'number') return null;
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function formatTime(ts: number): string {
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

interface PhaseNode {
  key: string;
  title: string;
  step: string;
  status: AiTraceEventStatus;
  brief: string;
  error: string;
  durationMs?: number;
  ts: number;
  calls: AiTraceEvent[];
}

/** 扁平事件 → 阶段时间线（每阶段一行，LLM/检索调用回归所属阶段） */
function buildTimeline(events: AiTraceEvent[]): { phases: PhaseNode[]; notes: AiTraceEvent[] } {
  const phases: PhaseNode[] = [];
  const notes: AiTraceEvent[] = [];
  const map = new Map<string, PhaseNode>();
  let openStep: string | null = null;

  for (const ev of events) {
    if (ev.type === 'note') {
      notes.push(ev);
      continue;
    }
    if (ev.type === 'step') {
      let phase = map.get(ev.step);
      if (!phase) {
        phase = { key: ev.step, title: ev.title, step: ev.step, status: ev.status, brief: '', error: '', ts: ev.ts, calls: [] };
        map.set(ev.step, phase);
        phases.push(phase);
      }
      if (ev.status === 'running') {
        phase.status = 'running';
        phase.brief = '';
        phase.error = '';
        phase.durationMs = undefined;
        phase.ts = ev.ts;
      } else {
        phase.status = ev.status;
        phase.brief = ev.resultBrief ?? '';
        phase.error = ev.error ?? '';
        phase.durationMs = ev.durationMs;
      }
      openStep = ev.step;
      continue;
    }
    // llm / search → 归属当前打开的阶段；无阶段时作孤立调用
    if (openStep) {
      const owner = map.get(openStep);
      if (owner) owner.calls.push(ev);
    } else {
      const standalone: PhaseNode = { key: `orphan-${ev.seq}`, title: ev.title, step: '', status: ev.status, brief: '', error: '', ts: ev.ts, calls: [ev] };
      phases.push(standalone);
    }
  }
  return { phases, notes };
}

export function AnalyzeTraceStream({ events, running = false, title = '识别流程实时过程', bodyClassName = 'max-h-[420px]', className }: AnalyzeTraceStreamProps) {
  const bodyRef = useRef<HTMLDivElement | null>(null);
  const stickRef = useRef(true);
  const [stick, setStick] = useState(true);
  const timeline = buildTimeline(events);

  useEffect(() => {
    const el = bodyRef.current;
    if (!el || !stickRef.current) return;
    el.scrollTop = el.scrollHeight;
  }, [events.length, running]);

  const handleScroll = () => {
    const el = bodyRef.current;
    if (!el) return;
    const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 48;
    stickRef.current = nearBottom;
    setStick(nearBottom);
  };

  const jumpToBottom = () => {
    const el = bodyRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
    stickRef.current = true;
    setStick(true);
  };

  return (
    <div className={cn('rounded-md border border-border bg-muted/30', className)}>
      {title !== null && (
        <div className="flex items-center gap-2 border-b border-border px-3 py-2">
          <span className={cn('h-2 w-2 rounded-full', running ? 'bg-primary animate-pulse' : 'bg-muted-foreground/50')} />
          <span className="text-sm font-medium text-foreground">{title}</span>
          {running && <span className="text-xs text-primary">进行中…</span>}
          <span className="ml-auto text-xs text-muted-foreground">{timeline.phases.length + timeline.notes.length} 项</span>
          {!stick && (
            <button type="button" onClick={jumpToBottom} className="text-xs text-primary underline-offset-2 hover:underline">
              回到底部
            </button>
          )}
        </div>
      )}

      <div ref={bodyRef} onScroll={handleScroll} className={cn('space-y-1.5 overflow-y-auto p-3', bodyClassName)}>
        {events.length === 0 ? (
          <p className="py-6 text-center text-xs text-muted-foreground">{running ? '等待流程事件…' : '本次识别没有留下流程事件。'}</p>
        ) : (
          <>
            {timeline.phases.map((phase) => (
              <PhaseRow key={phase.key} phase={phase} />
            ))}
            {timeline.notes.map((note) => (
              <div key={note.seq} className="flex items-center gap-2 px-0.5 py-0.5">
                <span className={cn('h-2 w-2 shrink-0 rounded-full', note.status === 'fail' ? 'bg-destructive' : 'bg-muted-foreground/50')} />
                <span className="text-sm text-muted-foreground">{note.title}</span>
                <span className="ml-auto shrink-0 text-[10px] text-muted-foreground">{formatTime(note.ts)}</span>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}

function PhaseRow({ phase }: { phase: PhaseNode }) {
  const [open, setOpen] = useState(phase.status === 'running' || phase.calls.length === 0);
  const duration = formatDuration(phase.durationMs);
  return (
    <div className="rounded-md border border-border bg-card px-3 py-2">
      <button type="button" onClick={() => setOpen((o) => !o)} className="flex w-full items-center gap-2 text-left">
        <StatusDot status={phase.status} />
        <span className={cn('text-sm', phase.status === 'fail' ? 'font-medium text-destructive' : 'font-semibold text-foreground')}>
          {phase.title}
        </span>
        {phase.step && <span className="font-mono text-[10px] text-muted-foreground">{phase.step}</span>}
        {phase.status === 'running' && <span className="text-xs text-primary">执行中…</span>}
        {!phase.status && null}
        <div className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {duration && <span>{duration}</span>}
          <span>{formatTime(phase.ts)}</span>
          {phase.calls.length > 0 && <Chevron open={open} />}
        </div>
      </button>
      {(phase.brief || phase.error) && (
        <div className={cn('mt-1 pl-4 text-xs', phase.error ? 'text-destructive' : 'text-muted-foreground')}>
          {phase.error || phase.brief}
        </div>
      )}
      {open && phase.calls.length > 0 && (
        <div className="mt-1.5 space-y-1.5 pl-1">
          {phase.calls.map((ev) => <CallCard key={ev.seq} ev={ev} />)}
        </div>
      )}
    </div>
  );
}

function StatusDot({ status }: { status: AiTraceEventStatus }) {
  return (
    <span
      className={cn(
        'flex h-4 w-4 shrink-0 items-center justify-center rounded-full',
        status === 'running' ? 'bg-primary text-primary-foreground animate-pulse' : 'bg-emerald-500 text-emerald-50',
        status === 'fail' && 'bg-destructive text-destructive-foreground',
      )}
    >
      <span className="text-[9px] leading-none font-semibold">
        {status === 'running' ? '…' : status === 'fail' ? '!' : '✓'}
      </span>
    </span>
  );
}

function Chevron({ open }: { open: boolean }) {
  return (
    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className={cn('transition-transform', open && 'rotate-180')}>
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}

function CallCard({ ev }: { ev: AiTraceEvent }) {
  const duration = formatDuration(ev.durationMs);
  const isSearch = ev.type === 'search';
  return (
    <div className="rounded-md border border-border bg-muted/40 px-3 py-2">
      <div className="flex flex-wrap items-center gap-1.5">
        <Badge variant="outline" className="font-mono text-[10px]">{isSearch ? '联网检索' : 'LLM'}</Badge>
        <span className="truncate text-xs font-medium text-foreground">{ev.title}</span>
        {ev.model && <span className="font-mono text-[10px] text-muted-foreground">{ev.model}</span>}
        <span className={cn('ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground')}>
          {ev.status === 'running' ? <span className="text-primary">等待响应…</span>
            : ev.status === 'fail' ? <span className="text-destructive">失败</span>
            : ev.resultBrief ? <span>{ev.resultBrief}</span> : null}
          {duration && <span>{duration}</span>}
        </span>
      </div>
      {(ev.systemPrompt || ev.userPrompt) && (
        <Collapsible label={isSearch ? '检索词' : '提示词'} text={[ev.systemPrompt, ev.userPrompt].filter(Boolean).join('\n\n---\n\n')} />
      )}
      {ev.response && <Collapsible label={isSearch ? '命中结果' : '响应'} text={ev.response} defaultOpen={isSearch || ev.response.length < 600} />}
      {ev.error && !ev.response && <p className="mt-1.5 whitespace-pre-wrap break-all text-xs text-destructive">{ev.error}</p>}
    </div>
  );
}

function Collapsible({ label, text, defaultOpen = false }: { label: string; text: string; defaultOpen?: boolean }) {
  return (
    <details open={defaultOpen} className="mt-1.5">
      <summary className="cursor-pointer text-[11px] text-muted-foreground hover:text-foreground">
        {label}（{text.length} 字）
      </summary>
      <pre className="mt-1 max-h-56 overflow-auto rounded bg-muted p-2 text-[11px] leading-relaxed whitespace-pre-wrap break-all">
        {text}
      </pre>
    </details>
  );
}
```

- [ ] **Step 2: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过，无未使用 import（确认无遗留 `STATUS_DOT` 引用）。

- [ ] **Step 3: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx
git commit -m "feat(admin): 识别实时过程重构为阶段时间线，修复每阶段两行与残留执行中"
git push origin master
git push github master
```

---
### Task 8: 后台 — 新增 PoseTraceStream 组件

**Files:**
- Create: `lumira-server/packages/admin/src/components/ai-create/pose-trace-stream.tsx`

**Interfaces:**
- Consumes: `AiBatchImageTraceEvent[]`（Task 4）。
- Produces: `PoseTraceStream({ events, running?: boolean, title?: string | null, bodyClassName?, className? })` — 按 index 逐张渲染从排队到完成/失败的实时过程。Task 9 依赖。

- [ ] **Step 1: 写组件**

```tsx
'use client';

// src/components/ai-create/pose-trace-stream.tsx
// 姿势图批量生成实时过程：按每张（index）归组，展示 排队→生成中→完成/失败 + 耗时 + 模型（折叠 prompt）+ 失败原因。
// 数据来源：后端批量状态接口的事件日志（AiBatchImageTraceEvent[]），前端按 lastSeq 增量累积后传入。

import * as React from 'react';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';
import type { AiBatchImageTraceEvent } from '@/types/admin';

interface PoseTraceStreamProps {
  events: AiBatchImageTraceEvent[];
  running?: boolean;
  title?: string | null;
  bodyClassName?: string;
  className?: string;
}

function formatDuration(ms?: number): string | null {
  if (typeof ms !== 'number') return null;
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

const STATUS_META: Record<string, { label: string; dot: string; text: string }> = {
  pending: { label: '排队', dot: 'bg-muted-foreground/50', text: 'text-muted-foreground' },
  running: { label: '生成中', dot: 'bg-primary animate-pulse', text: 'text-primary' },
  done: { label: '完成', dot: 'bg-emerald-500', text: 'text-emerald-600' },
  error: { label: '失败', dot: 'bg-destructive', text: 'text-destructive' },
};

export function PoseTraceStream({ events, running = false, title = '姿势图生成实时过程', bodyClassName = 'max-h-[420px]', className }: PoseTraceStreamProps) {
  const byIndex = new Map<number, AiBatchImageTraceEvent[]>();
  for (const ev of events) {
    if (!byIndex.has(ev.index)) byIndex.set(ev.index, []);
    byIndex.get(ev.index)!.push(ev);
  }
  const indexes = [...byIndex.keys()].sort((a, b) => a - b);

  return (
    <div className={cn('rounded-md border border-border bg-muted/30', className)}>
      {title !== null && (
        <div className="flex items-center gap-2 border-b border-border px-3 py-2">
          <span className={cn('h-2 w-2 rounded-full', running ? 'bg-primary animate-pulse' : 'bg-muted-foreground/50')} />
          <span className="text-sm font-medium text-foreground">{title}</span>
          {running && <span className="text-xs text-primary">进行中…</span>}
          <span className="ml-auto text-xs text-muted-foreground">{indexes.length} 张姿态</span>
        </div>
      )}
      <div className={cn('space-y-1.5 overflow-y-auto p-3', bodyClassName)}>
        {indexes.length === 0 ? (
          <p className="py-6 text-center text-xs text-muted-foreground">{running ? '等待生成事件…' : '本轮没有生成事件。'}</p>
        ) : (
          indexes.map((idx) => <PoseRow key={idx} index={idx} evs={byIndex.get(idx)!} />)
        )}
      </div>
    </div>
  );
}

function PoseRow({ index, evs }: { index: number; evs: AiBatchImageTraceEvent[] }) {
  const latest = evs[evs.length - 1]!;
  const meta = STATUS_META[latest.status] ?? STATUS_META.pending;
  const lastRunning = [...evs].reverse().find((e) => e.status === 'running');
  const finished = evs.find((e) => e.status === 'done' || e.status === 'error');
  const prompt = finished?.prompt;
  const model = finished?.model;
  const duration = formatDuration(finished?.durationMs);
  return (
    <div className="rounded-md border border-border bg-card px-3 py-2">
      <div className="flex items-center gap-2">
        <span className={cn('h-2 w-2 shrink-0 rounded-full', meta.dot)} />
        <span className="text-sm font-semibold text-foreground">姿势图 #{index + 1}</span>
        <Badge variant="outline" className={cn('font-mono text-[10px]', meta.text)}>{meta.label}</Badge>
        {model && <span className="font-mono text-[10px] text-muted-foreground">{model}</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {duration && <span>{duration}</span>}
          <span>{new Date(latest.ts).toLocaleTimeString()}</span>
        </span>
      </div>
      {finished?.error && <p className="mt-1 whitespace-pre-wrap break-all text-xs text-destructive">{finished.error}</p>}
      {prompt && (
        <details className="mt-1.5">
          <summary className="cursor-pointer text-[11px] text-muted-foreground hover:text-foreground">提示词（{prompt.length} 字）</summary>
          <pre className="mt-1 max-h-44 overflow-auto rounded bg-muted p-2 text-[11px] leading-relaxed whitespace-pre-wrap break-all">{prompt}</pre>
        </details>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过。

- [ ] **Step 3: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/ai-create/pose-trace-stream.tsx
git commit -m "feat(admin): 新增姿势图批量生成实时过程组件"
git push origin master
git push github master
```

---
### Task 9: 后台 — 新增常驻「生成过程」面板（步骤栏上方）

**Files:**
- Create: `lumira-server/packages/admin/src/components/ai-create/generate-progress-panel.tsx`

**Interfaces:**
- Consumes: `AnalyzeTraceStream`（Task 7）、`PoseTraceStream`（Task 8）。
- Produces: `GenerateProgressPanel({ recogEvents, recogRunning, poseEvents, poseRunning, onOpenDetail })` — 顶部常驻卡，Tab 切换「风格识别/姿势图生成」，运行中自动展开、结束后自动收拢成窄条，标题点击可展开；头部含「识别详情」入口触发 `onOpenDetail`。Task 10 依赖。

- [ ] **Step 1: 写组件**

```tsx
'use client';

// src/components/ai-create/generate-progress-panel.tsx
// 常驻「生成过程」面板（渲染在向导顶部步骤栏上方，跨 Step1~5 可见）：
// - Tab 切换：风格识别（AnalyzeTraceStream）/ 姿势图生成（PoseTraceStream）
// - 运行中自动展开；结束后自动收拢成窄条（仅标题栏）；点击标题可再展开
// - 头部提供「识别详情/过程」弹窗入口

import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import { AnalyzeTraceStream } from './analyze-trace-stream';
import { PoseTraceStream } from './pose-trace-stream';
import type { AiTraceEvent, AiBatchImageTraceEvent } from '@/types/admin';
import { MagicWand, CaretDown, X } from '@phosphor-icons/react';

type TabKey = 'recog' | 'pose';

interface GenerateProgressPanelProps {
  recogEvents: AiTraceEvent[];
  recogRunning: boolean;
  poseEvents: AiBatchImageTraceEvent[];
  poseRunning: boolean;
  /** 点「识别详情」时触发（打开原有数据分析弹窗） */
  onOpenDetail: () => void;
  /** 手动关闭整个面板（仅本次隐藏） */
  onClose: () => void;
}

export function GenerateProgressPanel({
  recogEvents,
  recogRunning,
  poseEvents,
  poseRunning,
  onOpenDetail,
  onClose,
}: GenerateProgressPanelProps) {
  const anyRunning = recogRunning || poseRunning;
  const anyContent = recogEvents.length > 0 || poseEvents.length > 0;
  const [tab, setTab] = useState<TabKey>('recog');
  const [expanded, setExpanded] = useState(true);
  const wasRunningRef = useRef(false);

  // 运行中自动展开；从未运行→运行→结束，结束后自动收拢
  useEffect(() => {
    if (anyRunning) {
      setExpanded(true);
      wasRunningRef.current = true;
    } else if (wasRunningRef.current && !anyRunning) {
      setExpanded(false);
    }
  }, [anyRunning]);

  if (!anyRunning && !anyContent) return null;

  const activeTab: TabKey = anyRunning ? tab : tab;
  const recogCount = recogEvents.filter((e) => e.type === 'step').length;
  const poseCount = poseEvents.length ? new Set(poseEvents.map((e) => e.index)).size : 0;

  return (
    <div className="rounded-md border border-primary/30 bg-primary/5">
      {/* 标题栏（点击展开/收拢；收拢时即窄条） */}
      <div className="flex items-center gap-2 px-3 py-2">
        <button type="button" onClick={() => setExpanded((o) => !o)} className="flex min-w-0 flex-1 items-center gap-2 text-left">
          <MagicWand size={16} className="shrink-0 text-primary" weight={anyRunning ? 'fill' : 'regular'} />
          <span className="truncate text-sm font-semibold text-foreground">AI 生成过程</span>
          {anyRunning && <span className="shrink-0 text-xs text-primary">进行中…</span>}
          <span className="shrink-0 text-xs text-muted-foreground">
            {tab === 'recog' ? `识别 ${recogCount} 项` : `姿势图 ${poseCount} 张`}
          </span>
          <CaretDown size={14} className={cn('ml-auto shrink-0 text-muted-foreground transition-transform', expanded && 'rotate-180')} />
        </button>
        <button type="button" onClick={onOpenDetail} className="shrink-0 rounded px-1.5 py-0.5 text-xs text-primary underline-offset-2 hover:underline">
          识别详情
        </button>
        <button type="button" onClick={onClose} className="shrink-0 text-muted-foreground hover:text-foreground" aria-label="关闭">
          <X size={14} />
        </button>
      </div>

      {expanded && anyContent && (
        <>
          {/* Tab 切换 */}
          <div className="flex items-center gap-1 border-t border-primary/20 px-2 pt-1">
            {([
              { key: 'recog', label: '风格识别' },
              { key: 'pose', label: '姿势图生成' },
            ] as const).map((t) => (
              <button
                key={t.key}
                type="button"
                onClick={() => setTab(t.key)}
                className={cn(
                  'rounded px-2.5 py-1 text-xs font-medium transition-colors',
                  activeTab === t.key ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {t.label}
              </button>
            ))}
          </div>
          {/* 内容区 */}
          <div className="p-2">
            {activeTab === 'recog'
              ? <AnalyzeTraceStream events={recogEvents} running={recogRunning} title={null} bodyClassName="max-h-56" />
              : <PoseTraceStream events={poseEvents} running={poseRunning} title={null} bodyClassName="max-h-56" />}
          </div>
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过（若 `@phosphor-icons/react` 未提供 `CaretDown`/`MagicWand`/`X` 命名导出，改用已存在的 import 路径或官网文档中的正确 icon 名称）。

- [ ] **Step 3: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/ai-create/generate-progress-panel.tsx
git commit -m "feat(admin): 新增常驻 AI 生成过程面板（Tab 切换，运行中展开/结束收拢）"
git push origin master
git push github master
```

---
### Task 10: 后台 — wizard 集成常驻面板并移除分散入口

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: `GenerateProgressPanel`（Task 9）、`onEvents`（Task 6）。
- Produces: 步骤栏上方渲染 `GenerateProgressPanel`；Step1 内联 `AnalyzeTraceStream` 移除；Step2「查看识别详情/过程」按钮移除（入口移入面板）。

- [ ] **Step 1: import 新组件与 icon**

在 wizard.tsx import 区加入：

```ts
import { GenerateProgressPanel } from './generate-progress-panel';
```

- [ ] **Step 2: 新增姿势图事件 state**

在 `const [poseProgress, setPoseProgress] = useState<AiPoseProgress | null>(null);` 附近加入：

```ts
  /** 生成姿势图逐张实时过程事件（喂给常驻面板「姿势图生成」Tab） */
  const [poseTraceEvents, setPoseTraceEvents] = useState<AiBatchImageTraceEvent[]>([]);
```

并确保 `AiBatchImageTraceEvent` 从 `@/types/admin` 导入。

- [ ] **Step 3: resetFlow 清空 poseTraceEvents**

在 `resetFlow` 中加入：

```ts
    setPoseTraceEvents([]);
```

- [ ] **Step 4: 全自动流程透传 onEvents**

在 `runAutoAll` 中对 `generateAiPoseImages` 调用增加 `onEvents: setPoseTraceEvents`：

```ts
      const poseResults = await generateAiPoseImages({
        draft: draftLocal,
        referenceFile: poseReferenceFile ?? exampleFile,
        research: analyzeResult.research,
        onProgress: setPoseProgress,
        onResult: appendGeneratedPose,
        onEvents: setPoseTraceEvents,
      });
```

- [ ] **Step 5: 移入常驻面板并删除 Step1 内联流与 Step2 详情按钮**

(a) 在「全自动进度/失败提示」区块之前（即 stepper 下方、previewPanel 之后的向导主体顶部）渲染常驻面板：

```tsx
        {/* 常驻 AI 生成过程面板（步骤栏上方、跨步骤可见；运行中展开/结束收拢） */}
        <GenerateProgressPanel
          recogEvents={traceEvents}
          recogRunning={analyzing || (autoState?.running === true && autoState.stage === 'analyzing')}
          poseEvents={poseTraceEvents}
          poseRunning={autoState?.running === true && autoState.stage === 'generating-image'}
          onOpenDetail={() => setDetailDialogOpen(true)}
          onClose={() => {
            setTraceEvents([]);
            setPoseTraceEvents([]);
          }}
        />
```

(b) 删除 Step1 内的内联 `{(analyzing || traceEvents.length > 0) && (<AnalyzeTraceStream ... />)}` 整块。

(c) 删除 Step2 中「查看识别详情 / 过程」`<Button variant="outline" ... onClick={() => setDetailDialogOpen(true)}>` 整段（保留「下一步：选择封面」按钮；`analyzeDetail` 弹窗 `AnalyzeResultDialog` 保留，入口改由常驻面板「识别详情」触发）。

- [ ] **Step 6: 清理未使用引用**

检查并移除 wizard.tsx 中不再使用的 `AnalyzeTraceStream` import（若已无其他引用）。

- [ ] **Step 7: 编译校验**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 构建通过，无未使用变量/lint 报错。

- [ ] **Step 8: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): 集成常驻生成过程面板，移除分散的识别流与详情入口"
git push origin master
git push github master
```

---
## 验收（整体）

- `cd lumira-server && pnpm --filter @lumira/backend build` 通过。
- `cd lumira-server && pnpm --filter @lumira/admin build` 通过。
- 手动：识别期间步骤栏上方出现「AI 生成过程」面板并自动展开；「风格识别」Tab 实时显示阶段时间线，每阶段一行、状态从执行中流转到完成/失败，无每阶段两行、无残留「执行中」。
- 结束后面板自动收拢窄条，跨 Step1~5 常驻；点击标题可再展开回看每阶段与提示词/响应。
- 全自动进入生图阶段时，「姿势图生成」Tab 逐张显示 排队→生成中→完成/失败、耗时、prompt、模型、失败原因；结束后可整体回看。
- 任意步骤都能通过面板内「识别详情」打开原有数据分析弹窗。