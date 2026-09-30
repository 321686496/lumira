'use client';

// src/components/ai-create/job-detail.tsx
// 生成任务详情页：信息条 / 阶段状态条 / 实时生成过程 / 产物预览 / 停止·继续·删除·打开到向导。
// 运行中（未终态）每 3 秒按 lastSeq 增量轮询并累积事件；进入终态或组件卸载即清除定时器。

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  JOB_STAGE_LABEL,
  JOB_STATUS_META,
  deleteAiJob,
  formatJobElapsed,
  getAiJobDetail,
  isSettled,
  jobStageProgressText,
  resumeAiJob,
  stopAiJob,
  type AiJobDetail,
  type AiJobStage,
} from '@/lib/ai-jobs';
import { toAnalyzeDetail, toPoseEvents, toRecogEvents } from '@/lib/pipeline-task';
import type { AiAnalyzeStatusResult, AiPipelineEvent, AiPipelineStatusResult } from '@/types/admin';
import { GenerateProgressPanel } from '@/components/ai-create/generate-progress-panel';
import { AnalyzeResultDialog } from '@/components/ai-create/analyze-result-dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ArrowLeft } from '@phosphor-icons/react/dist/csr/ArrowLeft';

type Tone = 'run' | 'wait' | 'ok' | 'bad';

/** 状态 tone → 类名（与 job-list.tsx 保持一致） */
const TONE_CLASS: Record<Tone, string> = {
  run: 'bg-sky-100 text-sky-700',
  wait: 'bg-amber-100 text-amber-700',
  ok: 'bg-emerald-100 text-emerald-700',
  bad: 'bg-rose-100 text-rose-700',
};

/** 单阶段状态 → 文案 + tone */
const STAGE_STATUS_META: Record<string, { label: string; tone: Tone }> = {
  pending: { label: '待执行', tone: 'wait' },
  running: { label: '进行中', tone: 'run' },
  done: { label: '已完成', tone: 'ok' },
  error: { label: '失败', tone: 'bad' },
};

const MODE_LABEL: Record<string, string> = {
  auto: '全自动',
  'analyze-only': '仅识别',
};

/** createdAt 为秒级 unix 时间戳 → 本地可读时间 */
function formatCreatedAt(sec: number): string {
  if (!sec) return '—';
  return new Date(sec * 1000).toLocaleString('zh-CN', { hour12: false });
}

function stageStatusMeta(status: string | undefined): { label: string; tone: Tone } {
  return STAGE_STATUS_META[status ?? 'pending'] ?? { label: status ?? '未知', tone: 'wait' };
}

/** 运行中增量轮询的事件合并：按 seq 去重并升序（同一 job 的 seq 全局递增，天然唯一） */
function mergeJobEvents(prev: AiPipelineEvent[], incoming: AiPipelineEvent[]): AiPipelineEvent[] {
  if (!incoming.length) return prev;
  if (!prev.length) return incoming;
  const map = new Map<number, AiPipelineEvent>();
  for (const e of prev) map.set(e.seq, e);
  for (const e of incoming) map.set(e.seq, e);
  return [...map.values()].sort((a, b) => a.seq - b.seq);
}

/** 返回任务列表的入口（加载态 / 错误态 / 正常态共用） */
function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm">
      <Link href="/dashboard/templates/ai-tasks">
        <ArrowLeft size={14} className="mr-1" /> 返回任务列表
      </Link>
    </Button>
  );
}

/** 单类产物区块：成功项网格 + 失败项下标与原因；两者皆空时给明确文案 */
function ArtifactSection({
  title,
  images,
  errors,
}: {
  title: string;
  images: Array<{ index: number; mimeType: string; storageKey: string; url: string }>;
  errors: Array<{ index: number; error: string }>;
}) {
  const sorted = [...images].sort((a, b) => a.index - b.index);
  const sortedErrors = [...errors].sort((a, b) => a.index - b.index);
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 text-sm font-medium">
        <span>{title}</span>
        <span className="text-xs font-normal text-muted-foreground">
          成功 {sorted.length} 张{sortedErrors.length ? ` · 失败 ${sortedErrors.length} 张` : ''}
        </span>
      </div>
      {sorted.length === 0 && sortedErrors.length === 0 && (
        <p className="text-sm text-muted-foreground">暂无产物（任务未完成或该阶段未产出）。</p>
      )}
      {sorted.length > 0 && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {sorted.map((a) => (
            <figure key={`${a.index}-${a.storageKey}`} className="space-y-1">
              {/* 相对路径（/uploads/ai-jobs/...）经 admin 的 next.config rewrite 代理到后端，直接 <img> 渲染 */}
              <img
                src={a.url}
                alt={`${title} 第 ${a.index + 1} 张`}
                className="h-32 w-full rounded-md border border-border bg-muted object-cover"
              />
              <figcaption className="text-xs text-muted-foreground">#{a.index + 1}</figcaption>
            </figure>
          ))}
        </div>
      )}
      {sortedErrors.length > 0 && (
        <ul className="space-y-1">
          {sortedErrors.map((e) => (
            <li key={`err-${e.index}`} className="text-xs text-destructive">
              第 {e.index + 1} 张失败：{e.error || '未知原因'}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export function JobDetail({ jobId }: { jobId: string }) {
  const router = useRouter();
  const [detail, setDetail] = useState<AiJobDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<null | 'stop' | 'resume' | 'delete'>(null);
  const [panelVisible, setPanelVisible] = useState(true);
  const [analyzeOpen, setAnalyzeOpen] = useState(false);
  /** 下一次增量拉取的 since（轮询内递增；停止/继续成功后重置为 0 以重建事件） */
  const lastSeq = useRef(0);

  const load = useCallback(async () => {
    const res = await getAiJobDetail(jobId, lastSeq.current);
    // 注意：AiJobDetail 自身带 `error` 字段（失败详情，可为 null），不能以 `'error' in res` 判别包装失败；
    // 成功响应必备 `jobId`，以 `'jobId' in res` 作为判别（与 pipeline-task 的 fetchPipelineStatus 同策略）。
    if (!('jobId' in res)) {
      setLoadError(res.error);
      setLoading(false);
      return;
    }
    setLoadError(null);
    lastSeq.current = Math.max(lastSeq.current, res.lastSeq ?? 0);
    setDetail((prev) => {
      const incoming = (res.events ?? []) as AiPipelineEvent[];
      if (!prev) return res;
      // 终态响应为全量事件（后端忽略 since 返回完整正文）→ 整体替换，避免与已累积的增量重复；
      // 运行中为增量 → 按 seq 去重合并。
      const events = isSettled(res.status)
        ? incoming
        : mergeJobEvents(prev.events as AiPipelineEvent[], incoming);
      return { ...res, events };
    });
    setLoading(false);
  }, [jobId]);

  // 首屏加载
  useEffect(() => {
    void load();
  }, [load]);

  // 仅未终态时轮询；进入终态或组件卸载即清除定时器（detail 为空时也不设定时器）
  const unsettled = detail ? !isSettled(detail.status) : false;
  useEffect(() => {
    if (!unsettled) return;
    const timer = setInterval(() => void load(), 3000);
    return () => clearInterval(timer);
  }, [unsettled, load]);

  const recogEvents = useMemo(
    () => toRecogEvents((detail?.events ?? []) as AiPipelineEvent[]),
    [detail?.events],
  );
  const poseEvents = useMemo(
    () => toPoseEvents((detail?.events ?? []) as AiPipelineEvent[]),
    [detail?.events],
  );
  // 识别详情弹窗所需结构由既有 toAnalyzeDetail 产出；AiJobDetail 与 AiPipelineStatusResult
  // 在 status/error/events 三处类型更宽（含 queued/stopped/interrupted 等），此处局部断言适配（Task 10 收口）。
  const analyzeResult = useMemo<AiAnalyzeStatusResult | null>(
    () => (detail ? toAnalyzeDetail(detail as unknown as AiPipelineStatusResult) : null),
    [detail],
  );

  /** 停止/继续统一收口：失败文案落页面，成功后重载详情 */
  const handleAction = useCallback(
    async (kind: 'stop' | 'resume', okText: string, run: () => Promise<unknown>) => {
      setBusy(kind);
      setActionError(null);
      setNotice(null);
      try {
        const res = await run();
        if (res && typeof res === 'object' && 'error' in res) {
          setActionError(String((res as { error: unknown }).error));
          return;
        }
        setNotice(okText);
        // 停止/继续成功后必须重置事件游标并清空已累积事件：后端内存态被淘汰/重启后会 hydrate
        // 重建 job，其 events 从空开始、seq 从 1 重新计数（ai-pipeline-job.service.ts 中
        // seq = job.events.length + 1）；若沿用上一轮终态的最大 seq 作为 since，新事件（seq ≤ N）
        // 会被后端以 since 过滤掉而静默丢失，且旧 events 仍在 → 面板停在「进行中」却永不刷新。
        // 置 0 后 since=0 走全量返回，配合 load() 的终态整体替换语义可安全重建事件列表。
        lastSeq.current = 0;
        setDetail((prev) => (prev ? { ...prev, events: [] } : prev));
        await load();
      } finally {
        setBusy(null);
      }
    },
    [load],
  );

  const handleDelete = useCallback(async () => {
    if (!detail) return;
    if (!window.confirm(`确认删除任务「${detail.title}」？此操作不可撤销。`)) return;
    setBusy('delete');
    setActionError(null);
    setNotice(null);
    try {
      const res = await deleteAiJob(detail.id);
      if ('error' in res) {
        setActionError(res.error);
        return;
      }
      router.push('/dashboard/templates/ai-tasks');
    } finally {
      setBusy(null);
    }
  }, [detail, router]);

  if (loading && !detail) {
    return (
      <div className="space-y-4">
        <BackLink />
        <Card>
          <CardContent className="py-10 text-center text-sm text-muted-foreground">加载中…</CardContent>
        </Card>
      </div>
    );
  }

  if (loadError && !detail) {
    return (
      <div className="space-y-4">
        <BackLink />
        <Card>
          <CardContent className="space-y-3 py-10 text-center">
            <p className="text-sm text-destructive">加载任务详情失败：{loadError}</p>
            <p className="text-xs text-muted-foreground">
              任务可能已被删除、超过保留期，或后端不可达。
            </p>
            <Button variant="outline" onClick={() => router.push('/dashboard/templates/ai-tasks')}>
              返回任务列表
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!detail) return null;

  const meta = JOB_STATUS_META[detail.status];
  const running = detail.status === 'running';
  const recogRunning = running && detail.currentStage === 'analyze';
  const poseRunning = running && detail.currentStage === 'image';
  const hadError = detail.error != null || (isSettled(detail.status) && detail.status !== 'done');
  const canStop = detail.status === 'running' || detail.status === 'queued';
  const canResume =
    detail.status === 'error' || detail.status === 'stopped' || detail.status === 'interrupted';
  const canDelete = isSettled(detail.status);
  const analyzeDone = detail.stages.analyze.status === 'done';
  const canOpenWizard = isSettled(detail.status) && analyzeDone;
  const wizardDisabledReason = !isSettled(detail.status)
    ? '任务尚未结束，完成后可打开到向导'
    : !analyzeDone
      ? '识别阶段未完成，暂不能打开到向导'
      : undefined;
  const stageOrder: AiJobStage[] =
    detail.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];

  return (
    <div className="space-y-4">
      <BackLink />

      {loadError && <p className="text-sm text-destructive">刷新失败：{loadError}（将继续重试）</p>}
      {actionError && <p className="text-sm text-destructive">{actionError}</p>}
      {notice && <p className="text-sm text-emerald-600">{notice}</p>}

      <Card>
        <CardHeader className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <CardTitle className="text-left">{detail.title || '未命名任务'}</CardTitle>
            <Badge variant="secondary" className={TONE_CLASS[meta.tone]}>
              {meta.label}
            </Badge>
            <Badge variant="outline">{MODE_LABEL[detail.mode] ?? detail.mode}</Badge>
          </div>
          <div className="flex flex-wrap gap-x-6 gap-y-1 text-sm text-muted-foreground">
            <span>
              任务 ID：
              <span className="font-mono text-xs text-foreground">{detail.id}</span>
            </span>
            <span>阶段进度：{jobStageProgressText(detail)}</span>
            <span>耗时：{formatJobElapsed(detail.startedAt, detail.finishedAt)}</span>
            {detail.status === 'queued' && detail.queuePos > 0 && (
              <span>排队位次：第 {detail.queuePos} 位</span>
            )}
            <span>创建时间：{formatCreatedAt(detail.createdAt)}</span>
          </div>
          {detail.errorMessage && <p className="text-sm text-destructive">失败原因：{detail.errorMessage}</p>}
          {detail.error?.hint && <p className="text-xs text-muted-foreground">建议：{detail.error.hint}</p>}
        </CardHeader>
        <CardContent className="space-y-4">
          {/* 三阶段状态条（analyze-only 模式仅识别一阶段） */}
          <div className="flex flex-wrap items-center gap-3">
            {stageOrder.map((stage) => {
              const st = stageStatusMeta(detail.stages[stage]?.status);
              return (
                <div key={stage} className="flex items-center gap-2">
                  <span className="text-sm">{JOB_STAGE_LABEL[stage]}</span>
                  <Badge variant="secondary" className={TONE_CLASS[st.tone]}>
                    {st.label}
                  </Badge>
                </div>
              );
            })}
          </div>

          {/* 操作按钮 */}
          <div className="flex flex-wrap items-center gap-2">
            {canStop && (
              <Button
                variant="outline"
                size="sm"
                disabled={busy !== null}
                onClick={() => void handleAction('stop', '已提交停止', () => stopAiJob(detail.id))}
              >
                停止
              </Button>
            )}
            {canResume && (
              <Button
                variant="outline"
                size="sm"
                disabled={busy !== null}
                onClick={() => void handleAction('resume', '已提交继续', () => resumeAiJob(detail.id))}
              >
                继续
              </Button>
            )}
            <Button
              variant="outline"
              size="sm"
              disabled={!canOpenWizard}
              title={wizardDisabledReason}
              onClick={() => router.push('/dashboard/templates/ai-create?job=' + detail.jobId)}
            >
              打开到向导
            </Button>
            {canDelete && (
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive hover:text-destructive"
                disabled={busy !== null}
                onClick={() => void handleDelete()}
              >
                删除
              </Button>
            )}
          </div>

          {/* 实时生成过程（复用常驻面板；关闭仅隐藏，不清空已采集事件） */}
          {panelVisible ? (
            <GenerateProgressPanel
              recogEvents={recogEvents}
              recogRunning={recogRunning}
              poseEvents={poseEvents}
              poseRunning={poseRunning}
              statusText={jobStageProgressText(detail)}
              hadError={hadError}
              onOpenDetail={() => setAnalyzeOpen(true)}
              onClose={() => setPanelVisible(false)}
            />
          ) : (
            (recogEvents.length > 0 || poseEvents.length > 0) && (
              <Button variant="ghost" size="sm" onClick={() => setPanelVisible(true)}>
                显示生成过程
              </Button>
            )
          )}

          {/* 产物预览：成功项与失败项同时展示 */}
          <div className="space-y-4">
            <ArtifactSection title="姿势图" images={detail.poseImages} errors={detail.poseErrors} />
            {detail.mode !== 'analyze-only' && (
              <ArtifactSection title="剪影" images={detail.silhouetteImages} errors={detail.silhouetteErrors} />
            )}
          </div>
        </CardContent>
      </Card>

      <AnalyzeResultDialog open={analyzeOpen} onOpenChange={setAnalyzeOpen} result={analyzeResult} />
    </div>
  );
}