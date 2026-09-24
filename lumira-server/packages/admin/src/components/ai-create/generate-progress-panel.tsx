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
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { CaretDown } from '@phosphor-icons/react/dist/csr/CaretDown';
import { X } from '@phosphor-icons/react/dist/csr/X';

type TabKey = 'recog' | 'pose';

interface GenerateProgressPanelProps {
  recogEvents: AiTraceEvent[];
  recogRunning: boolean;
  poseEvents: AiBatchImageTraceEvent[];
  poseRunning: boolean;
  /** 收拢态优先展示的进度文案（如「进行中 · 姿势图 3/6」）；缺省回落 Tab 计数 */
  statusText?: string | null;
  /** 点「识别详情」时触发（打开原有数据分析弹窗） */
  onOpenDetail: () => void;
  /** 手动关闭整个面板（仅隐藏本次展示，不清空已采集过程） */
  onClose: () => void;
}

export function GenerateProgressPanel({
  recogEvents,
  recogRunning,
  poseEvents,
  poseRunning,
  statusText,
  onOpenDetail,
  onClose,
}: GenerateProgressPanelProps) {
  const anyRunning = recogRunning || poseRunning;
  const anyContent = recogEvents.length > 0 || poseEvents.length > 0;
  const [tab, setTab] = useState<TabKey>('recog');
  const [expanded, setExpanded] = useState(true);
  const wasRunningRef = useRef(false);
  /** 各 Tab 已读事件数（用于未读角标） */
  const [readCounts, setReadCounts] = useState<Record<TabKey, number>>({ recog: 0, pose: 0 });
  /** 用户是否手动切过 Tab：切过之后不再自动归位 */
  const userSwitchedTabRef = useRef(false);
  /** 是否已自动切过一次到姿势图 Tab（同一次展示只自动切一次） */
  const autoSwitchedRef = useRef(false);

  // 运行中自动展开；从未运行→运行→结束，结束后自动收拢
  useEffect(() => {
    if (anyRunning) {
      setExpanded(true);
      wasRunningRef.current = true;
    } else if (wasRunningRef.current && !anyRunning) {
      setExpanded(false);
    }
  }, [anyRunning]);

  const recogTotal = recogEvents.length;
  const poseTotal = poseEvents.length;
  const totals: Record<TabKey, number> = { recog: recogTotal, pose: poseTotal };

  // 当前 Tab 的新内容视为已读，避免给自己加角标
  useEffect(() => {
    const total = tab === 'recog' ? recogTotal : poseTotal;
    setReadCounts((prev) => (prev[tab] === total ? prev : { ...prev, [tab]: total }));
  }, [tab, recogTotal, poseTotal]);

  // 识别结束且姿势图开始产出时，自动归位到姿势图 Tab（用户手动切过则不再干预）
  useEffect(() => {
    if (userSwitchedTabRef.current || autoSwitchedRef.current) return;
    if (poseEvents.length > 0 && !recogRunning) {
      autoSwitchedRef.current = true;
      setTab('pose');
    }
  }, [poseEvents.length, recogRunning]);

  /** 非当前 Tab 的未读条数 */
  const unread = (t: TabKey) => (t === tab ? 0 : Math.max(0, totals[t] - readCounts[t]));

  if (!anyRunning && !anyContent) return null;

  const recogCount = recogEvents.filter((e) => e.type === 'step').length;
  const poseCount = poseEvents.length ? new Set(poseEvents.map((e) => e.index)).size : 0;

  return (
    <div className="rounded-md border border-primary/30 bg-primary/5">
      {/* 标题栏（点击展开/收拢；收拢时即窄条） */}
      <div className="flex items-center gap-2 px-3 py-2">
        <button type="button" onClick={() => setExpanded((o) => !o)} className="flex min-w-0 flex-1 items-center gap-2 text-left">
          <MagicWand size={16} className="shrink-0 text-primary" weight={anyRunning ? 'fill' : 'regular'} />
          <span className="truncate text-sm font-semibold text-foreground">AI 生成过程</span>
          {anyRunning && !statusText && <span className="shrink-0 text-xs text-primary">进行中…</span>}
          <span className={cn('shrink-0 text-xs', statusText ? 'text-primary' : 'text-muted-foreground')}>
            {statusText ?? (tab === 'recog' ? `识别 ${recogCount} 项` : `姿势图 ${poseCount} 张`)}
          </span>
          <CaretDown size={14} className={cn('ml-auto shrink-0 text-muted-foreground transition-transform', expanded && 'rotate-180')} />
        </button>
        <span className="h-4 w-px shrink-0 bg-primary/20" />
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
                onClick={() => {
                  userSwitchedTabRef.current = true;
                  setTab(t.key);
                }}
                className={cn(
                  'rounded px-2.5 py-1 text-xs font-medium transition-colors',
                  tab === t.key ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {t.label}
                {unread(t.key) > 0 && (
                  <span className="ml-1.5 rounded-full bg-primary px-1.5 py-0.5 text-[10px] text-primary-foreground">
                    +{unread(t.key)}
                  </span>
                )}
              </button>
            ))}
          </div>
          {/* 内容区 */}
          <div className="p-2">
            {tab === 'recog'
              ? <AnalyzeTraceStream events={recogEvents} running={recogRunning} title={null} bodyClassName="max-h-56" />
              : <PoseTraceStream events={poseEvents} running={poseRunning} title={null} bodyClassName="max-h-56" />}
          </div>
        </>
      )}
    </div>
  );
}
