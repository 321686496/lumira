'use client';

// src/components/ai-create/trace-call-card.tsx
// 单次 LLM / 检索调用的「原始数据」卡片（识别流与姿势图流共用）：
// 分区展示 请求提示词（system / user）、模型输出（提取）、上游原始响应（JSON），
// 默认全部展开、限高内部滚动，每块可一键复制，便于排查问题时直接取证。

import * as React from 'react';
import { useState } from 'react';
import { Copy } from '@phosphor-icons/react/dist/csr/Copy';
import { Check } from '@phosphor-icons/react/dist/csr/Check';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

export interface TraceCallCardData {
  type?: 'llm' | 'search';
  title: string;
  model?: string;
  status?: 'running' | 'done' | 'fail' | 'error' | 'pending';
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  /** 实际发出的请求次数（含降级/重试；> 1 时卡片显示「请求 N 次」） */
  attempts?: number;
  resultBrief?: string;
  error?: string;
  durationMs?: number;
}

function formatDuration(ms?: number): string | null {
  if (typeof ms !== 'number') return null;
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function statusText(ev: TraceCallCardData): string | null {
  if (ev.status === 'running' || ev.status === 'pending') return '等待响应…';
  if (ev.status === 'fail' || ev.status === 'error') return '失败';
  return ev.resultBrief ?? null;
}

/** 复制到剪贴板；环境不支持时返回 false（由调用方提示） */
async function copyText(text: string): Promise<boolean> {
  try {
    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // 非安全上下文 / 权限被拒：交给调用方提示
  }
  return false;
}

export function TraceCallCard({ ev, defaultOpen = true, className }: { ev: TraceCallCardData; defaultOpen?: boolean; className?: string }) {
  const duration = formatDuration(ev.durationMs);
  const isSearch = ev.type === 'search';
  const status = statusText(ev);
  return (
    <div className={cn('rounded-md border border-border bg-muted/40 px-3 py-2', className)}>
      <div className="flex flex-wrap items-center gap-1.5">
        <Badge variant="outline" className="font-mono text-[10px]">{isSearch ? '联网检索' : 'LLM'}</Badge>
        <span className="truncate text-xs font-medium text-foreground">{ev.title}</span>
        {ev.model && <span className="font-mono text-[10px] text-muted-foreground">{ev.model}</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {status && <span className={cn(ev.status === 'fail' || ev.status === 'error' ? 'text-destructive' : ev.status === 'running' || ev.status === 'pending' ? 'text-primary' : undefined)}>{status}</span>}
          {typeof ev.attempts === 'number' && ev.attempts > 1 && <span>请求 {ev.attempts} 次</span>}
          {duration && <span>{duration}</span>}
        </span>
      </div>

      {ev.systemPrompt && <TraceTextBlock label="System 提示词" text={ev.systemPrompt} defaultOpen={defaultOpen} />}
      {ev.userPrompt && <TraceTextBlock label={isSearch ? '检索词' : 'User 提示词'} text={ev.userPrompt} defaultOpen={defaultOpen} />}
      {ev.response && <TraceTextBlock label={isSearch ? '命中摘要' : '模型输出（提取）'} text={ev.response} defaultOpen={defaultOpen} />}
      {ev.rawResponse && <TraceTextBlock label="上游原始响应（JSON）" text={ev.rawResponse} defaultOpen={defaultOpen} />}
      {ev.error && !ev.response && <p className="mt-1.5 whitespace-pre-wrap break-all text-xs text-destructive">{ev.error}</p>}
    </div>
  );
}

export function TraceTextBlock({ label, text, defaultOpen = true }: { label: string; text: string; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(defaultOpen);
  const [copied, setCopied] = useState(false);
  const [failed, setFailed] = useState(false);

  const onCopy = async () => {
    const ok = await copyText(text);
    if (ok) {
      setCopied(true);
      setFailed(false);
      setTimeout(() => setCopied(false), 1500);
    } else {
      setFailed(true);
      setTimeout(() => setFailed(false), 1500);
    }
  };

  return (
    <div className="mt-1.5">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          className="text-[11px] text-muted-foreground hover:text-foreground"
        >
          {open ? '▾' : '▸'} {label}（{text.length} 字）
        </button>
        <button
          type="button"
          onClick={onCopy}
          className="ml-auto flex items-center gap-1 text-[10px] text-muted-foreground hover:text-foreground"
        >
          {copied ? <Check size={11} /> : <Copy size={11} />}
          {copied ? '已复制' : failed ? '复制失败' : '复制'}
        </button>
      </div>
      {open && (
        <pre className="mt-1 max-h-56 overflow-auto rounded bg-muted p-2 text-[11px] leading-relaxed whitespace-pre-wrap break-all">
          {text}
        </pre>
      )}
    </div>
  );
}

/** 可参与合并的事件源（识别流 AiTraceEvent 与批次流 AiBatchImageTraceEvent 的公共子集） */
export interface TraceCallSource {
  seq: number;
  /** 识别流用 type；批次流用 kind */
  type?: 'llm' | 'search' | 'step' | 'note' | 'pose';
  kind?: 'pose' | 'llm' | 'search';
  title: string;
  model?: string;
  status: string;
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
  resultBrief?: string;
  error?: string;
  durationMs?: number;
}

export interface TraceCallItem {
  key: number;
  ev: TraceCallCardData;
}

/** 只覆盖有值的字段，避免 done 事件把 running 已记录的提示词清成 undefined */
function mergeDefined<T extends object>(base: T, patch: Partial<T>): T {
  const out: Record<string, unknown> = { ...(base as Record<string, unknown>) };
  for (const [k, v] of Object.entries(patch)) if (v !== undefined) out[k] = v;
  return out as T;
}

/**
 * 把「一次调用的两条事件」折叠成一张卡片的数据：
 * running/pending 开一个待配对槽位并占据当前位置；随后同 种类+title+model 的 done/fail/error
 * 原位补齐响应字段（key 不变 → React 不重建节点，表现为同一张卡片内容变完整）。
 * 未能配对的事件各自单独成条（如只有 done 的历史事件、并发同名调用）。
 */
export function collapseTraceCalls(sources: TraceCallSource[]): TraceCallItem[] {
  const items: TraceCallItem[] = [];
  const open = new Map<string, number>();
  for (const src of sources) {
    const isSearch = src.kind === 'search' || src.type === 'search';
    const ev: TraceCallCardData = {
      type: isSearch ? 'search' : 'llm',
      title: src.title,
      model: src.model,
      status: src.status as TraceCallCardData['status'],
      systemPrompt: src.systemPrompt,
      userPrompt: src.userPrompt,
      response: src.response,
      rawResponse: src.rawResponse,
      attempts: src.attempts,
      resultBrief: src.resultBrief,
      error: src.error,
      durationMs: src.durationMs,
    };
    const key = `${isSearch ? 'search' : 'llm'}|${src.title}|${src.model ?? ''}`;
    const waiting = src.status === 'running' || src.status === 'pending';
    if (waiting) {
      if (open.has(key)) continue; // 同一次调用不会重复 running；重复时忽略以免卡片抖动
      open.set(key, items.length);
      items.push({ key: src.seq, ev });
      continue;
    }
    const idx = open.get(key);
    if (typeof idx === 'number') {
      open.delete(key);
      items[idx] = { key: items[idx].key, ev: mergeDefined(items[idx].ev, ev) };
      continue;
    }
    items.push({ key: src.seq, ev });
  }
  return items;
}
