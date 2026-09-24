'use client';

// src/components/ai-create/pose-trace-stream.tsx
// 姿势图批量生成实时过程：按每张（index）归组，展示 排队→生成中→完成/失败 + 耗时 + 模型（prompt 默认展开）+ 失败原因。
// 该张图生成过程中的模型调用（kind='llm'/'search'）以其原始数据卡片内嵌展示，不参与头部状态灯计算。
// 数据来源：后端批量状态接口的事件日志（AiBatchImageTraceEvent[]），前端按 lastSeq 增量累积后传入。

import * as React from 'react';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';
import { TraceCallCard, TraceTextBlock, collapseTraceCalls } from '@/components/ai-create/trace-call-card';
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

function formatTime(ts: number): string {
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
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
  // 头部状态只认姿势图生命周期事件（kind 缺省即 'pose'），避免被模型调用子事件污染
  const poseEvs = evs.filter((e) => !e.kind || e.kind === 'pose');
  const latest = poseEvs[poseEvs.length - 1] ?? evs[evs.length - 1]!;
  const meta = STATUS_META[latest.status] ?? STATUS_META.pending;
  const finished = poseEvs.find((e) => e.status === 'done' || e.status === 'error');
  const prompt = finished?.prompt;
  const model = finished?.model;
  const duration = formatDuration(finished?.durationMs);
  const calls = collapseTraceCalls(evs.filter((e) => e.kind === 'llm' || e.kind === 'search'));
  return (
    <div className="rounded-md border border-border bg-card px-3 py-2">
      <div className="flex items-center gap-2">
        <span className={cn('h-2 w-2 shrink-0 rounded-full', meta.dot)} />
        <span className="text-sm font-semibold text-foreground">姿势图 #{index + 1}</span>
        <Badge variant="outline" className={cn('font-mono text-[10px]', meta.text)}>{meta.label}</Badge>
        {model && <span className="font-mono text-[10px] text-muted-foreground">{model}</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {duration && <span>{duration}</span>}
          <span>{formatTime(latest.ts)}</span>
        </span>
      </div>
      {finished?.error && <p className="mt-1 whitespace-pre-wrap break-all text-xs text-destructive">{finished.error}</p>}
      {calls.map(({ key, ev }) => (
        <TraceCallCard key={key} className="mt-1.5" ev={ev} />
      ))}
      {prompt && <TraceTextBlock label="最终生图提示词" text={prompt} />}
    </div>
  );
}
