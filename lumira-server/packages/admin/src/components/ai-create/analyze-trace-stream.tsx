'use client';

// src/components/ai-create/analyze-trace-stream.tsx
// AI 识别流程实时事件流（聊天式）：按发生顺序展示「走到哪一步 / 该步提示词 / 模型响应 / 检索命中」，
// 运行中自动滚到底部（用户上滑回看历史时不打断），提示词与响应可折叠以收纳长文本。
// 数据来源：后端 llm-trace 事件流（task.events），前端按 seq 增量拉取后累积渲染。

import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import type { AiTraceEvent, AiTraceEventStatus } from '@/types/admin';

interface AnalyzeTraceStreamProps {
  events: AiTraceEvent[];
  /** 流程是否仍在进行（决定头部指示与自动滚动） */
  running?: boolean;
  /** 标题；null 时不渲染头部 */
  title?: string | null;
  /** 内容区高度类（默认 max-h-[420px]） */
  bodyClassName?: string;
  className?: string;
}

/** 毫秒 → 可读耗时 */
function formatMs(ms?: number): string | null {
  if (typeof ms !== 'number') return null;
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

/** 时间戳 → HH:MM:SS */
function formatTime(ts: number): string {
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

const STATUS_DOT: Record<AiTraceEventStatus, string> = {
  running: 'bg-primary animate-pulse',
  done: 'bg-emerald-500',
  fail: 'bg-destructive',
};

export function AnalyzeTraceStream({
  events,
  running = false,
  title = '识别流程实时过程',
  bodyClassName = 'max-h-[420px]',
  className,
}: AnalyzeTraceStreamProps) {
  const bodyRef = useRef<HTMLDivElement | null>(null);
  // 是否吸附底部：初始 true；用户上滑离开底部后暂停自动滚动
  const stickRef = useRef(true);
  const [stick, setStick] = useState(true);

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
          <span className={cn('h-2 w-2 rounded-full', running ? STATUS_DOT.running : 'bg-muted-foreground/50')} />
          <span className="text-sm font-medium text-foreground">{title}</span>
          {running && <span className="text-xs text-primary">进行中…</span>}
          <span className="ml-auto text-xs text-muted-foreground">{events.length} 条事件</span>
          {!stick && (
            <button
              type="button"
              onClick={jumpToBottom}
              className="text-xs text-primary underline-offset-2 hover:underline"
            >
              回到底部
            </button>
          )}
        </div>
      )}

      <div ref={bodyRef} onScroll={handleScroll} className={cn('space-y-2 overflow-y-auto p-3', bodyClassName)}>
        {events.length === 0 ? (
          <p className="py-6 text-center text-xs text-muted-foreground">
            {running ? '等待流程事件…' : '本次识别没有留下流程事件。'}
          </p>
        ) : (
          events.map((ev) => <TraceEventItem key={ev.seq} ev={ev} />)
        )}
      </div>
    </div>
  );
}

/** 单条事件：阶段/说明渲染为分节标题行，LLM/检索调用渲染为可折叠卡片 */
function TraceEventItem({ ev }: { ev: AiTraceEvent }) {
  if (ev.type === 'step' || ev.type === 'note') return <StepRow ev={ev} />;
  return <CallCard ev={ev} />;
}

function StepRow({ ev }: { ev: AiTraceEvent }) {
  const duration = formatMs(ev.durationMs);
  const isNote = ev.type === 'note';
  return (
    <div className={cn('flex items-center gap-2', isNote ? 'px-0.5 py-0.5' : 'pt-1.5 first:pt-0')}>
      <span className={cn('h-2 w-2 shrink-0 rounded-full', STATUS_DOT[ev.status])} />
      <span
        className={cn(
          'text-sm',
          isNote ? 'text-muted-foreground' : 'font-semibold text-foreground',
          ev.status === 'fail' && 'text-destructive',
        )}
      >
        {ev.title}
      </span>
      {ev.step && !isNote && (
        <span className="font-mono text-[10px] text-muted-foreground">{ev.step}</span>
      )}
      {ev.status === 'running' && <span className="text-xs text-primary">执行中…</span>}
      {ev.resultBrief && <span className="truncate text-xs text-muted-foreground">{ev.resultBrief}</span>}
      {ev.error && <span className="truncate text-xs text-destructive">{ev.error}</span>}
      <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
        {duration && <span>{duration}</span>}
        <span>{formatTime(ev.ts)}</span>
      </span>
    </div>
  );
}

function CallCard({ ev }: { ev: AiTraceEvent }) {
  const duration = formatMs(ev.durationMs);
  const isSearch = ev.type === 'search';
  return (
    <div className="rounded-md border border-border bg-card px-3 py-2">
      <div className="flex flex-wrap items-center gap-1.5">
        <Badge variant="outline" className="font-mono text-[10px]">
          {isSearch ? '联网检索' : 'LLM'}
        </Badge>
        <span className="truncate text-xs font-medium text-foreground">{ev.title}</span>
        {ev.model && (
          <span className="font-mono text-[10px] text-muted-foreground">{ev.model}</span>
        )}
        {ev.imageBytes ? (
          <span className="text-[10px] text-muted-foreground">附图 {(ev.imageBytes / 1024).toFixed(0)}KB</span>
        ) : null}
        <span className={cn('ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground')}>
          {ev.status === 'running' ? (
            <span className="text-primary">等待响应…</span>
          ) : ev.status === 'fail' ? (
            <span className="text-destructive">失败</span>
          ) : (
            ev.resultBrief && <span>{ev.resultBrief}</span>
          )}
          {duration && <span>{duration}</span>}
        </span>
      </div>

      {(ev.systemPrompt || ev.userPrompt) && (
        <Collapsible label={isSearch ? '检索词' : '提示词'} text={[ev.systemPrompt, ev.userPrompt].filter(Boolean).join('\n\n---\n\n')} />
      )}
      {ev.response && <Collapsible label={isSearch ? '命中结果' : '响应'} text={ev.response} defaultOpen={isSearch || ev.response.length < 600} />}
      {ev.error && !ev.response && (
        <p className="mt-1.5 whitespace-pre-wrap break-all text-xs text-destructive">{ev.error}</p>
      )}
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