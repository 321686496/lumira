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
function buildTimeline(events: AiTraceEvent[]): { phases: PhaseNode[]; notes: AiTraceEvent[]; orphans: AiTraceEvent[] } {
  const phases: PhaseNode[] = [];
  const notes: AiTraceEvent[] = [];
  const orphans: AiTraceEvent[] = [];
  const map = new Map<string, PhaseNode>();
  // 后端 traceStep 是栈式的（嵌套时内层先结束），故用栈记录未结束的阶段，
  // 栈顶即当前真正打开的阶段；避免内层结束后仍把后续调用挂到内层。
  const stack: string[] = [];

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
        stack.push(ev.step);
      } else {
        phase.status = ev.status;
        phase.brief = ev.resultBrief ?? '';
        phase.error = ev.error ?? '';
        phase.durationMs = ev.durationMs;
        // 弹出与其匹配的阶段：优先栈顶，否则移除最后一个同名项（容错乱序）
        if (stack[stack.length - 1] === ev.step) {
          stack.pop();
        } else {
          const idx = stack.lastIndexOf(ev.step);
          if (idx >= 0) stack.splice(idx, 1);
        }
      }
      continue;
    }
    // llm / search → 归属栈顶（当前打开）的阶段；栈空时作孤立调用
    const openStep = stack[stack.length - 1];
    if (openStep) {
      const owner = map.get(openStep);
      if (owner) owner.calls.push(ev);
    } else {
      orphans.push(ev);
    }
  }
  return { phases, notes, orphans };
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
          <span className="ml-auto text-xs text-muted-foreground">{timeline.phases.length + timeline.orphans.length + timeline.notes.length} 项</span>
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
            {timeline.orphans.map((ev) => (
              <CallCard key={ev.seq} ev={ev} />
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