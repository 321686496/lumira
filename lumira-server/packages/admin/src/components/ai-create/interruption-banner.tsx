'use client';

// src/components/ai-create/interruption-banner.tsx
// 断点详情横幅：分类错误码 + 阶段 + 耗时 + 上游原文 + 处置建议，并提供「继续 / 重新开始 / 放弃」。
// 「继续」= 优先重连（后端仍在跑/已完成），否则从失败阶段重跑并复用已完成成果（后端 resume 语义）。

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { formatSec } from '@/lib/ai-task';
import { isRetryablePipelineError, pipelineStageLabel } from '@/lib/pipeline-task';
import type { AiInterruptionInfo } from '@/types/admin';

export function InterruptionBanner({
  info,
  resuming,
  canResume = true,
  onResume,
  onRestart,
  onDismiss,
}: {
  info: AiInterruptionInfo;
  /** 「继续」请求中（按钮置灰防重复点击） */
  resuming?: boolean;
  /** 是否存在可续跑的 job；为 false 时「继续」无意义，降级为「重新开始」 */
  canResume?: boolean;
  onResume: () => void;
  onRestart: () => void;
  onDismiss: () => void;
}) {
  const [showUpstream, setShowUpstream] = useState(false);
  const retryable = canResume !== false && isRetryablePipelineError(info.code);

  return (
    <div className="rounded-md border border-destructive/50 bg-destructive/10 p-4 text-sm text-destructive">
      <div className="flex flex-wrap items-center gap-2 font-medium">
        <span>生成中断（{pipelineStageLabel(info.stage)}）</span>
        <code className="rounded bg-destructive/15 px-1.5 py-0.5 text-[11px] font-mono">{info.code}</code>
        {typeof info.elapsedMs === 'number' && (
          <span className="text-xs opacity-80">该阶段已耗时 {formatSec(info.elapsedMs)}</span>
        )}
        {info.failedIndexes && info.failedIndexes.length > 0 && (
          <span className="text-xs opacity-80">
            失败项 #{info.failedIndexes.map((i) => i + 1).join('、')}
          </span>
        )}
      </div>

      <p className="mt-2 whitespace-pre-wrap">{info.message}</p>

      {info.hint && <p className="mt-1 text-xs opacity-90">建议：{info.hint}</p>}

      {(info.upstream || typeof info.status === 'number') && (
        <div className="mt-2">
          <button
            type="button"
            className="text-xs underline underline-offset-2"
            onClick={() => setShowUpstream((v) => !v)}
          >
            {showUpstream ? '收起上游原始信息' : '查看上游原始信息'}
          </button>
          {showUpstream && (
            <pre className="mt-1 max-h-40 overflow-auto whitespace-pre-wrap break-all rounded bg-background/60 p-2 text-[11px] text-foreground">
              {typeof info.status === 'number' ? `HTTP ${info.status}\n` : ''}
              {info.upstream || '（无）'}
            </pre>
          )}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {retryable ? (
          <Button size="sm" disabled={resuming} onClick={onResume}>
            {resuming ? '继续中…' : '继续'}
          </Button>
        ) : (
          <Button size="sm" disabled={resuming} onClick={onRestart}>
            重新开始
          </Button>
        )}
        {retryable && (
          <Button size="sm" variant="outline" disabled={resuming} onClick={onRestart}>
            重新开始
          </Button>
        )}
        <Button size="sm" variant="ghost" disabled={resuming} onClick={onDismiss}>
          放弃本次生成
        </Button>
      </div>
    </div>
  );
}