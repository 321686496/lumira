'use client';

// src/components/ai-create/analyze-trace-stream.tsx
// AI 识别流程实时事件流（横向轨道时间线版）：
// 顶部一条可横向滚动的阶段轨道（圆点 + 阶段名 + 序号/耗时），点击某个阶段后，
// 下方展示该阶段的结论与全部子项（子阶段、联网检索/模型调用卡片）。
// 后端事件带 parentStep 后按「发生次数」建树——同一阶段多轮迭代各占一格，不再被合并；
// 子阶段 / 调用 / 说明挂在其父阶段下，顺序严格按事件 seq，消除因果倒置与 note 堆到末尾。
// 提示词与上游原始响应默认展开、可一键复制（见 TraceCallCard）。
// 运行中默认「跟随最新」并自动滚底；用户点击某阶段后停止跟随，可点「跟随最新」恢复。
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
  /** 稳定 key：step + 第几次发生（同阶段多轮迭代各占一格） */
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
  /** 该 step 一共发生几次（> 1 时展示序号） */
  total: number;
  children: TimelineItem[];
}

/** 时间线子项：子阶段，或一次调用 / 一条说明（叶子） */
type TimelineItem = { kind: 'step'; node: StepNode } | { kind: 'event'; ev: AiTraceEvent };

/** 扁平事件 → 时间线树：按发生次数建阶段节点，子事件按 parentStep 挂到最近开放阶段 */
function buildTimeline(events: AiTraceEvent[]): { roots: TimelineItem[]; count: number } {
  // 先数每个 step 发生几次（供重复阶段序号）
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

/** 一层内的行：子阶段 / 一次调用（已折叠）/ 一条说明 */
type RowSpec =
  | { key: string; kind: 'step'; node: StepNode }
  | { key: number; kind: 'call'; ev: TraceCallCardData }
  | { key: number; kind: 'note'; ev: AiTraceEvent };

/** 按 seq 顺序把一层内的子项整理成行（连续的调用事件折叠成一张卡片） */
function collapseToRows(items: TimelineItem[]): RowSpec[] {
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
  return rows;
}

/** 一层的行 → 竖轨嵌套列表（用于「选中阶段」下方的子项展示） */
function renderItems(items: TimelineItem[]): React.ReactNode[] {
  const rows = collapseToRows(items);
  const lastIdx = rows.length - 1;
  return rows.map((row, i) => {
    const last = i === lastIdx;
    if (row.kind === 'step') return <StepRow key={row.key} node={row.node} last={last} />;
    if (row.kind === 'call') return <CallRow key={row.key} ev={row.ev} last={last} />;
    return <NoteRow key={row.key} ev={row.ev} last={last} />;
  });
}

const rowId = (row: RowSpec): string => (row.kind === 'step' ? `s:${row.key}` : `${row.kind === 'call' ? 'c' : 'n'}:${row.key}`);

/** 轨道格子副行文案：序号 · 状态/耗时 · 时间 */
function railMeta(row: RowSpec): string {
  if (row.kind === 'step') {
    const parts: string[] = [];
    if (row.node.total > 1) parts.push(`#${row.node.occurrence}`);
    if (row.node.status === 'running') parts.push('执行中…');
    else {
      const d = formatDuration(row.node.durationMs);
      if (d) parts.push(d);
    }
    parts.push(formatTime(row.node.ts));
    return parts.join(' · ');
  }
  if (row.ev.status === 'running' || row.ev.status === 'pending') return '执行中…';
  return [formatDuration(row.ev.durationMs), row.ev.ts ? formatTime(row.ev.ts) : null].filter(Boolean).join(' · ');
}

const railLabel = (row: RowSpec): string => (row.kind === 'step' ? row.node.title : row.ev.title);

export function AnalyzeTraceStream({ events, running = false, title = '识别流程实时过程', bodyClassName = 'max-h-[420px]', className }: AnalyzeTraceStreamProps) {
  const bodyRef = useRef<HTMLDivElement | null>(null);
  const railRef = useRef<HTMLDivElement | null>(null);
  const stickRef = useRef(true);
  const [stick, setStick] = useState(true);
  /** 用户手动点选的阶段（null = 跟随最新） */
  const [pickedId, setPickedId] = useState<string | null>(null);

  const timeline = buildTimeline(events);
  const rows = collapseToRows(timeline.roots);
  const lastRow = rows[rows.length - 1];
  const pickedValid = pickedId !== null && rows.some((r) => rowId(r) === pickedId);
  const selectedId = pickedValid ? pickedId : lastRow ? rowId(lastRow) : null;
  const selected = rows.find((r) => rowId(r) === selectedId) ?? null;

  // 跟随最新时把轨道滚到最右，保证新出现的阶段可见
  useEffect(() => {
    const el = railRef.current;
    if (!el || pickedValid) return;
    el.scrollLeft = el.scrollWidth;
  }, [rows.length, pickedValid]);

  useEffect(() => {
    const el = bodyRef.current;
    if (!el || !stickRef.current) return;
    el.scrollTop = el.scrollHeight;
  }, [events.length, running, selectedId]);

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
          {pickedValid && (
            <button
              type="button"
              onClick={() => setPickedId(null)}
              className="text-xs text-primary underline-offset-2 hover:underline"
            >
              跟随最新
            </button>
          )}
          {!stick && (
            <button type="button" onClick={jumpToBottom} className="text-xs text-primary underline-offset-2 hover:underline">
              回到底部
            </button>
          )}
        </div>
      )}

      {rows.length === 0 ? (
        <p className="py-6 text-center text-xs text-muted-foreground">
          {running ? '等待流程事件…' : '本次识别没有留下流程事件。'}
        </p>
      ) : (
        <>
          {/* 横向阶段轨道 */}
          <div ref={railRef} className="overflow-x-auto border-b border-border px-3 pt-3 pb-2">
            <div className="flex min-w-max items-start">
              {rows.map((row, i) => {
                const id = rowId(row);
                const active = id === selectedId;
                const fail = row.kind === 'step' ? row.node.status === 'fail' : row.ev.status === 'fail';
                return (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setPickedId(active ? null : id)}
                    title={`${railLabel(row)}（${railMeta(row)}）`}
                    className={cn(
                      'flex w-[118px] shrink-0 flex-col items-center rounded-md px-1 py-1 text-center transition-colors',
                      active ? 'bg-muted' : 'hover:bg-muted/50',
                    )}
                  >
                    <span className="flex w-full items-center">
                      <span className={cn('h-px flex-1', i === 0 ? 'bg-transparent' : 'bg-border')} />
                      <RailDot row={row} active={active} />
                      <span className={cn('h-px flex-1', i === rows.length - 1 ? 'bg-transparent' : 'bg-border')} />
                    </span>
                    <span className={cn('mt-1.5 w-full truncate text-xs', fail ? 'text-destructive' : active ? 'font-semibold text-foreground' : 'text-foreground')}>
                      {railLabel(row)}
                    </span>
                    <span className="w-full truncate font-mono text-[10px] text-muted-foreground">{railMeta(row)}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* 选中阶段的详情与子项 */}
          <div ref={bodyRef} onScroll={handleScroll} className={cn('overflow-y-auto p-3', bodyClassName)}>
            {selected && <RowDetail row={selected} />}
          </div>
        </>
      )}
    </div>
  );
}

/** 轨道上的圆点：阶段用状态圆点，调用/说明用小圆点 */
function RailDot({ row, active }: { row: RowSpec; active: boolean }) {
  const ring = cn('rounded-full', active && 'ring-2 ring-primary/30 ring-offset-1 ring-offset-muted/30');
  if (row.kind === 'step') {
    return (
      <span className={cn('flex items-center justify-center', ring)}>
        <StatusDot status={row.node.status} />
      </span>
    );
  }
  const waiting = row.ev.status === 'running' || row.ev.status === 'pending';
  return (
    <span
      className={cn(
        'h-2.5 w-2.5 shrink-0',
        ring,
        row.ev.status === 'fail' ? 'bg-destructive' : waiting ? 'bg-primary animate-pulse' : 'bg-muted-foreground/40',
      )}
    />
  );
}

/** 选中阶段下方的内容：阶段结论 + 其全部子项；调用/说明则直接展示本身 */
function RowDetail({ row }: { row: RowSpec }) {
  if (row.kind === 'call') return <TraceCallCard ev={row.ev} />;
  if (row.kind === 'note') {
    return (
      <div className="flex items-center gap-2 py-0.5">
        <span className={cn('text-sm', row.ev.status === 'fail' ? 'text-destructive' : 'text-muted-foreground')}>{row.ev.title}</span>
        {row.ev.resultBrief && <span className="text-xs text-muted-foreground">· {row.ev.resultBrief}</span>}
        <span className="ml-auto shrink-0 text-[10px] text-muted-foreground">{formatTime(row.ev.ts)}</span>
      </div>
    );
  }

  const node = row.node;
  const duration = formatDuration(node.durationMs);
  const hasChildren = node.children.length > 0;
  return (
    <div>
      <div className="flex items-center gap-2">
        <StatusDot status={node.status} />
        <span className={cn('text-sm', node.status === 'fail' ? 'font-medium text-destructive' : 'font-semibold text-foreground')}>{node.title}</span>
        {node.total > 1 && <span className="shrink-0 rounded bg-muted px-1 font-mono text-[10px] text-muted-foreground">#{node.occurrence}</span>}
        <span className="truncate font-mono text-[10px] text-muted-foreground">{node.step}</span>
        {node.status === 'running' && <span className="shrink-0 text-xs text-primary">执行中…</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {duration && <span>{duration}</span>}
          <span>{formatTime(node.ts)}</span>
        </span>
      </div>
      {(node.error || node.brief) && (
        <div className={cn('mt-1 text-xs', node.error ? 'text-destructive' : 'text-muted-foreground')}>{node.error || node.brief}</div>
      )}
      {hasChildren ? (
        <div className="mt-2">{renderItems(node.children)}</div>
      ) : (
        <p className="mt-2 text-xs text-muted-foreground">该阶段没有更细的过程事件。</p>
      )}
    </div>
  );
}

/** 子项行：左侧竖轨（圆点 + 竖线） + 右侧内容；子阶段由内容列自行缩进 */
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
  const [open, setOpen] = useState(true);
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