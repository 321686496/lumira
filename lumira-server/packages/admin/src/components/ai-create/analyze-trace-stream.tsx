'use client';

// src/components/ai-create/analyze-trace-stream.tsx
// AI 识别流程实时事件流（嵌套竖轨时间线版）：
// 后端事件带 parentStep 后，按「发生次数」建树——同一阶段多轮迭代各占一行，不再被合并成一行；
// 子阶段 / 调用 / 说明就地缩进挂在父阶段下，顺序严格按事件 seq 先序遍历，消除
// 「父阶段先建行导致因果倒置」与「note 堆到列表末尾」两类错乱。
// 提示词与上游原始响应默认展开、可一键复制（见 TraceCallCard）。
// 运行中自动滚底（用户上滑回看不打断）。
// 数据来源：后端 llm-trace 事件流（task.events），前端按 seq 增量拉取后累积渲染。

import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import { TraceCallCard, collapseTraceCalls } from '@/components/ai-create/trace-call-card';
import type { TraceCallCardData } from '@/components/ai-create/trace-call-card';
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

/** 时间线节点（阶段，可含子项） */
interface StepNode {
  kind: 'step';
  /** 稳定 key：step + 第几次发生（同阶段多轮迭代各占一行） */
  key: string;
  step: string;
  title: string;
  status: AiTraceEventStatus;
  ts: number;
  durationMs?: number;
  brief: string;
  error: string;
  /** 该 step 的第几次发生（1 起） */
  occurrence: number;
  /** 该 step 一共发生几次（> 1 时展示序号角标） */
  total: number;
  children: TimelineItem[];
}

/** 时间线子项：子阶段，或一次调用 / 一条说明（叶子） */
type TimelineItem = { kind: 'step'; node: StepNode } | { kind: 'event'; ev: AiTraceEvent };

/** 扁平事件 → 时间线树：按发生次数建阶段节点，子事件按 parentStep 挂到最近开放阶段 */
function buildTimeline(events: AiTraceEvent[]): { roots: TimelineItem[]; count: number } {
  // 先数每个 step 发生几次（供重复阶段序号角标）
  const totalByStep = new Map<string, number>();
  for (const ev of events) {
    if (ev.type === 'step' && ev.status === 'running') totalByStep.set(ev.step, (totalByStep.get(ev.step) ?? 0) + 1);
  }

  const roots: TimelineItem[] = [];
  /** 尚未收到 done/fail 的阶段（从尾向前找最近同名项即「最近开放节点」） */
  const open: StepNode[] = [];
  const seenByStep = new Map<string, number>();
  let count = 0;

  const nextOccurrence = (step: string): number => {
    const occurrence = (seenByStep.get(step) ?? 0) + 1;
    seenByStep.set(step, occurrence);
    return occurrence;
  };

  /** 挂到 parentStep 匹配的最近开放阶段；无匹配（顶层事件 / 父阶段已关闭）→ 顶层 */
  const attach = (ev: AiTraceEvent, item: TimelineItem): void => {
    let parent: StepNode | undefined;
    if (ev.parentStep) {
      for (let i = open.length - 1; i >= 0; i--) {
        if (open[i].step === ev.parentStep) {
          parent = open[i];
          break;
        }
      }
    }
    if (parent) parent.children.push(item);
    else roots.push(item);
  };

  for (const ev of events) {
    if (ev.type === 'step') {
      if (ev.status === 'running') {
        const occurrence = nextOccurrence(ev.step);
        const node: StepNode = {
          kind: 'step',
          key: `${ev.step}#${occurrence}`,
          step: ev.step,
          title: ev.title,
          status: 'running',
          ts: ev.ts,
          brief: '',
          error: '',
          occurrence,
          total: totalByStep.get(ev.step) ?? occurrence,
          children: [],
        };
        count += 1;
        attach(ev, { kind: 'step', node });
        open.push(node);
        continue;
      }
      // done / fail：关闭最近的同名开放阶段，原位补齐状态与结论
      let idx = -1;
      for (let i = open.length - 1; i >= 0; i--) {
        if (open[i].step === ev.step) {
          idx = i;
          break;
        }
      }
      if (idx >= 0) {
        const node = open[idx];
        node.status = ev.status;
        node.brief = ev.resultBrief ?? '';
        node.error = ev.error ?? '';
        node.durationMs = ev.durationMs;
        open.splice(idx, 1);
      } else {
        // 兼容缺 running 的历史事件：直接建一个已结束的阶段节点
        const occurrence = nextOccurrence(ev.step);
        count += 1;
        attach(ev, {
          kind: 'step',
          node: {
            kind: 'step',
            key: `${ev.step}#${occurrence}`,
            step: ev.step,
            title: ev.title,
            status: ev.status,
            ts: ev.ts,
            durationMs: ev.durationMs,
            brief: ev.resultBrief ?? '',
            error: ev.error ?? '',
            occurrence,
            total: Math.max(totalByStep.get(ev.step) ?? 0, occurrence),
            children: [],
          },
        });
      }
      continue;
    }
    // llm / search / note → 挂到所属阶段下；无归属时作顶层叶子
    count += 1;
    attach(ev, { kind: 'event', ev });
  }

  return { roots, count };
}

/** 按 seq 顺序先序遍历：父阶段行 → 其子项 → 下一个顶层节点（调用事件折叠成卡片） */
type RowSpec =
  | { key: string; kind: 'step'; node: StepNode }
  | { key: number; kind: 'call'; ev: TraceCallCardData }
  | { key: number; kind: 'note'; ev: AiTraceEvent };

function renderItems(items: TimelineItem[]): React.ReactNode[] {
  const rows: RowSpec[] = [];
  let pending: AiTraceEvent[] = [];
  const flush = () => {
    if (!pending.length) return;
    // 连续的同次调用（running + done）折叠成一张卡片，保证后面的「末行判定」不受影响
    for (const it of collapseTraceCalls(pending)) rows.push({ key: it.key, kind: 'call', ev: it.ev });
    pending = [];
  };

  for (const it of items) {
    if (it.kind === 'step') {
      flush();
      rows.push({ key: it.node.key, kind: 'step', node: it.node });
      continue;
    }
    if (it.ev.type === 'note') {
      flush();
      rows.push({ key: it.ev.seq, kind: 'note', ev: it.ev });
      continue;
    }
    pending.push(it.ev);
  }
  flush();

  const lastIdx = rows.length - 1;
  return rows.map((row, i) => {
    const last = i === lastIdx;
    if (row.kind === 'step') return <StepRow key={row.key} node={row.node} last={last} />;
    if (row.kind === 'call') return <CallRow key={row.key} ev={row.ev} last={last} />;
    return <NoteRow key={row.key} ev={row.ev} last={last} />;
  });
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
          <span className="ml-auto text-xs text-muted-foreground">{timeline.count} 项</span>
          {!stick && (
            <button type="button" onClick={jumpToBottom} className="text-xs text-primary underline-offset-2 hover:underline">
              回到底部
            </button>
          )}
        </div>
      )}

      <div ref={bodyRef} onScroll={handleScroll} className={cn('overflow-y-auto p-3', bodyClassName)}>
        {events.length === 0 ? (
          <p className="py-6 text-center text-xs text-muted-foreground">{running ? '等待流程事件…' : '本次识别没有留下流程事件。'}</p>
        ) : (
          renderItems(timeline.roots)
        )}
      </div>
    </div>
  );
}

/** 时间线一行：左侧竖轨（圆点 + 竖线） + 右侧内容；子项由内容列自行缩进 */
function TimelineRow({ dot, dotClassName, last, children }: { dot: React.ReactNode; dotClassName?: string; last: boolean; children: React.ReactNode }) {
  return (
    <div className="flex gap-2">
      <div className="flex w-4 shrink-0 flex-col items-center">
        <span className={cn('flex shrink-0 items-center justify-center', dotClassName)}>{dot}</span>
        {!last && <span className="mt-1 w-px flex-1 bg-border" aria-hidden />}
      </div>
      <div className="min-w-0 flex-1 pb-1.5">{children}</div>
    </div>
  );
}

function StepRow({ node, last }: { node: StepNode; last: boolean }) {
  const [open, setOpen] = useState(() => node.status === 'running' || node.children.length === 0);
  const duration = formatDuration(node.durationMs);
  const hasChildren = node.children.length > 0;
  return (
    <TimelineRow last={last} dot={<StatusDot status={node.status} />} dotClassName="mt-0.5">
      <button type="button" onClick={() => setOpen((o) => !o)} className="flex w-full items-center gap-2 text-left">
        <span className={cn('text-sm', node.status === 'fail' ? 'font-medium text-destructive' : 'font-semibold text-foreground')}>
          {node.title}
        </span>
        {node.total > 1 && (
          <span className="shrink-0 rounded bg-muted px-1 font-mono text-[10px] text-muted-foreground">#{node.occurrence}</span>
        )}
        <span className="truncate font-mono text-[10px] text-muted-foreground">{node.step}</span>
        {node.status === 'running' && <span className="shrink-0 text-xs text-primary">执行中…</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {duration && <span>{duration}</span>}
          <span>{formatTime(node.ts)}</span>
          {hasChildren && <Chevron open={open} />}
        </span>
      </button>
      {(node.error || node.brief) && (
        <div className={cn('mt-0.5 text-xs', node.error ? 'text-destructive' : 'text-muted-foreground')}>{node.error || node.brief}</div>
      )}
      {open && hasChildren && <div className="mt-1">{renderItems(node.children)}</div>}
    </TimelineRow>
  );
}

function CallRow({ ev, last }: { ev: TraceCallCardData; last: boolean }) {
  const waiting = ev.status === 'running' || ev.status === 'pending';
  return (
    <TimelineRow
      last={last}
      dotClassName="mt-2.5"
      dot={<span className={cn('h-2 w-2 rounded-full', waiting ? 'bg-primary animate-pulse' : 'bg-muted-foreground/40')} />}
    >
      <TraceCallCard ev={ev} />
    </TimelineRow>
  );
}

function NoteRow({ ev, last }: { ev: AiTraceEvent; last: boolean }) {
  return (
    <TimelineRow
      last={last}
      dotClassName="mt-1.5"
      dot={<span className={cn('h-2 w-2 rounded-full', ev.status === 'fail' ? 'bg-destructive' : 'bg-muted-foreground/50')} />}
    >
      <div className="flex items-center gap-2 py-0.5">
        <span className="text-sm text-muted-foreground">{ev.title}</span>
        {ev.resultBrief && <span className="truncate text-xs text-muted-foreground">· {ev.resultBrief}</span>}
        <span className="ml-auto shrink-0 text-[10px] text-muted-foreground">{formatTime(ev.ts)}</span>
      </div>
    </TimelineRow>
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
    <svg width={10} height={10} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className={cn('transition-transform', open && 'rotate-180')}>
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}