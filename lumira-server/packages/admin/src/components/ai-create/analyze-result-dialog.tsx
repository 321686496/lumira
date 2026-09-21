'use client';

// src/components/ai-create/analyze-result-dialog.tsx
// AI 识别结果详情弹窗（供数据分析）：三块内容用 Tab 切换。
// 1) 识别过程：Agentic 研究管线逐步执行的 trace（研究/识别/姿势面片/评分等）。
// 2) 原始结构数据：LLM 直接吐出的原始 JSON（raw）与归一化后的 draft 对比。
// 3) 参考来源（URL）：趋势研究阶段命中的来源（title 可点外链 + source 标签 + 摘要）。
// 研究管线未开启时 trace/research 为空，对应 Tab 友好降级。

import * as React from 'react';
import { useState, useMemo } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import type { AiAnalyzeStatusResult, AiAnalyzeTraceEntry, AiResearchRef } from '@/types/admin';

type TabKey = 'trace' | 'raw' | 'research';

interface AnalyzeResultDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** 识别完成后的全量结果（含 trace/raw/research） */
  result: AiAnalyzeStatusResult | null;
}

export function AnalyzeResultDialog({ open, onOpenChange, result }: AnalyzeResultDialogProps) {
  const [tab, setTab] = useState<TabKey>('trace');

  // 关闭后重置到第一个 Tab，下次打开从头看
  React.useEffect(() => {
    if (!open) setTab('trace');
  }, [open]);

  const trace = result?.trace ?? [];
  const research = useMemo<(AiResearchRef & { url?: string })[]>(
    () => (result?.research ?? []).filter((r) => typeof r?.url === 'string' && r.url),
    [result],
  );
  const raw = result?.raw;

  // 归一化后有对应子项个数（用于头部展示 draft 概要）
  const draftEntries = useMemo(
    () => (result?.draft ? Object.entries(result.draft).filter(([, v]) => v != null) : []),
    [result],
  );

  const tabs: { key: TabKey; label: string; count?: number }[] = [
    { key: 'trace', label: '识别过程', count: trace.length },
    { key: 'raw', label: '原始结构数据' },
    { key: 'research', label: '参考来源', count: research.length },
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[85vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle>AI 识别结果详情</DialogTitle>
          <DialogDescription>
            查看本次识别的全过程、LLM 原始结构化输出与参考来源，用于数据分析。
          </DialogDescription>
        </DialogHeader>

        {/* Tab 切换 */}
        <div className="flex items-center gap-1 border-b">
          {tabs.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => setTab(t.key)}
              className={cn(
                'relative -mb-px px-3 py-2 text-sm font-medium transition-colors border-b-2',
                tab === t.key
                  ? 'border-primary text-foreground'
                  : 'border-transparent text-muted-foreground hover:text-foreground',
              )}
            >
              {t.label}
              {typeof t.count === 'number' && t.count > 0 && (
                <Badge variant="secondary" className="ml-1.5 px-1.5 py-0 text-xs">
                  {t.count}
                </Badge>
              )}
            </button>
          ))}
        </div>

        {/* 内容区 */}
        <div className="flex-1 overflow-y-auto p-1">
          {tab === 'trace' && <TraceTab entries={trace} />}
          {tab === 'raw' && <RawTab raw={raw} draft={result?.draft} draftEntries={draftEntries} />}
          {tab === 'research' && <ResearchTab items={research} />}
        </div>
      </DialogContent>
    </Dialog>
  );
}

/* ---------- 识别过程（时间线） ---------- */
function TraceTab({ entries }: { entries: AiAnalyzeTraceEntry[] }) {
  if (!entries.length) {
    return (
      <p className="py-10 text-center text-sm text-muted-foreground">
        研究管线未开启，本次为单次识别，无分步轨迹。
      </p>
    );
  }
  return (
    <ol className="relative space-y-4 border-l pl-6">
      {entries.map((e, i) => (
        <li key={i} className="relative">
          <span className="absolute -left-[29px] top-1.5 h-3 w-3 rounded-full border-2 border-background bg-primary" />
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <span className="font-mono font-semibold">{e.step}</span>
            {e.tool && (
              <Badge variant="outline" className="font-mono">
                {e.tool}
              </Badge>
            )}
            {typeof e.score === 'number' && (
              <Badge variant={e.score >= 60 ? 'secondary' : 'destructive'} className="font-mono">
                评分 {e.score}
              </Badge>
            )}
          </div>
          <p className="mt-0.5 text-sm text-muted-foreground">{e.resultBrief}</p>
        </li>
      ))}
    </ol>
  );
}

/* ---------- 原始结构数据（raw vs draft 对比） ---------- */
function RawTab({
  raw,
  draft,
  draftEntries,
}: {
  raw?: Record<string, unknown>;
  draft?: Record<string, unknown>;
  draftEntries: [string, unknown][];
}) {
  const rawText = raw ? JSON.stringify(raw, null, 2) : '';
  const draftText = draft ? JSON.stringify(draft, null, 2) : '';

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <section className="min-w-0">
          <h4 className="mb-1 text-sm font-semibold">LLM 原始输出 (raw)</h4>
          <pre className="max-h-72 overflow-auto rounded-md bg-muted p-3 text-xs leading-relaxed whitespace-pre-wrap break-all">
            {rawText || '(无原始数据)'}
          </pre>
        </section>
        <section className="min-w-0">
          <h4 className="mb-1 text-sm font-semibold">归一化草稿 (draft)</h4>
          <pre className="max-h-72 overflow-auto rounded-md bg-muted p-3 text-xs leading-relaxed whitespace-pre-wrap break-all">
            {draftText || '(无草稿)'}
          </pre>
        </section>
      </div>
      {draftEntries.length > 0 && (
        <p className="text-xs text-muted-foreground">
          归一化草稿共 {draftEntries.length} 个字段，可用于与原始输出对照分析差异。
        </p>
      )}
    </div>
  );
}

/* ---------- 参考来源（URL 列表） ---------- */
function ResearchTab({ items }: { items: (AiResearchRef & { url?: string })[] }) {
  if (!items.length) {
    return (
      <p className="py-10 text-center text-sm text-muted-foreground">
        本次未启用趋势研究，没有参考 URL。
      </p>
    );
  }
  return (
    <ul className="space-y-3">
      {items.map((it, i) => (
        <li key={i} className="rounded-md border bg-card p-3">
          <div className="flex items-center justify-between gap-2">
            <a
              href={it.url}
              target="_blank"
              rel="noopener noreferrer"
              className="line-clamp-2 text-sm font-medium text-primary hover:underline break-all"
            >
              {it.title || it.url}
            </a>
            <Badge variant="outline" className="shrink-0 font-mono">
              {it.source}
            </Badge>
          </div>
          {it.snippet && (
            <p className="mt-1 line-clamp-3 text-xs text-muted-foreground">{it.snippet}</p>
          )}
          <a
            href={it.url}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-1 inline-block max-w-full truncate text-xs text-muted-foreground hover:text-primary break-all"
          >
            {it.url}
          </a>
        </li>
      ))}
    </ul>
  );
}