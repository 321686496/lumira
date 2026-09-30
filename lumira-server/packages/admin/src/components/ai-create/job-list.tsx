'use client';
// src/components/ai-create/job-list.tsx
// 生成任务队列列表：状态筛选 + 表格 + 停止/继续/删除/清理 + 未终态自动轮询。
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  JOB_STATUS_META,
  cleanupAiJobs,
  deleteAiJob,
  formatJobElapsed,
  isSettled,
  jobStageProgressText,
  listAiJobs,
  resumeAiJob,
  stopAiJob,
  type AiJobListItem,
  type AiJobStatus,
} from '@/lib/ai-jobs';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

const TONE_CLASS: Record<'run' | 'wait' | 'ok' | 'bad', string> = {
  run: 'bg-sky-100 text-sky-700',
  wait: 'bg-amber-100 text-amber-700',
  ok: 'bg-emerald-100 text-emerald-700',
  bad: 'bg-rose-100 text-rose-700',
};

/** 状态筛选下拉项：全部 + 各状态（顺序沿用 JOB_STATUS_META） */
const STATUS_OPTIONS: Array<{ value: AiJobStatus | 'all'; label: string }> = [
  { value: 'all', label: '全部' },
  ...(Object.keys(JOB_STATUS_META) as AiJobStatus[]).map((s) => ({
    value: s,
    label: JOB_STATUS_META[s].label,
  })),
];

/** createdAt 为秒级 unix 时间戳 → 本地可读时间 */
function formatCreatedAt(sec: number): string {
  if (!sec) return '—';
  return new Date(sec * 1000).toLocaleString('zh-CN', { hour12: false });
}

export function JobList() {
  const router = useRouter();
  const [items, setItems] = useState<AiJobListItem[]>([]);
  const [status, setStatus] = useState<AiJobStatus | 'all'>('all');
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [cleanupBusy, setCleanupBusy] = useState(false);

  const refresh = useCallback(async () => {
    const res = await listAiJobs({
      status: status === 'all' ? undefined : status,
      limit: 50,
    });
    if ('error' in res) {
      setError(res.error);
      setLoading(false);
      return;
    }
    setError(null);
    setItems(res.items);
    setLoading(false);
  }, [status]);

  // 首屏及筛选变化时拉取
  useEffect(() => {
    void refresh();
  }, [refresh]);

  // 仅当存在未终态任务时轮询；全部终态则不再设定时器
  const hasUnsettled = items.some((i) => !isSettled(i.status));
  useEffect(() => {
    if (!hasUnsettled) return;
    const timer = setInterval(() => {
      void refresh();
    }, 3000);
    return () => clearInterval(timer);
  }, [hasUnsettled, refresh]);

  /** 行内操作统一收口：错误显示在提示区，成功后重载列表 */
  const runRowAction = useCallback(
    async (id: string, okText: string, action: () => Promise<unknown>) => {
      setBusyId(id);
      setError(null);
      setNotice(null);
      try {
        const res = await action();
        if (res && typeof res === 'object' && 'error' in res) {
          setError(String((res as { error: unknown }).error));
          return;
        }
        setNotice(okText);
        await refresh();
      } finally {
        setBusyId(null);
      }
    },
    [refresh],
  );

  async function handleCleanup() {
    setCleanupBusy(true);
    setError(null);
    setNotice(null);
    try {
      const res = await cleanupAiJobs();
      if ('error' in res) {
        setError(res.error);
        return;
      }
      setNotice(`已清理 ${res.removed} 条任务记录`);
      await refresh();
    } finally {
      setCleanupBusy(false);
    }
  }

  function handleDelete(item: AiJobListItem) {
    if (!window.confirm(`确认删除任务「${item.title}」？此操作不可撤销。`)) return;
    void runRowAction(item.id, '任务已删除', () => deleteAiJob(item.id));
  }

  return (
    <Card>
      <CardHeader className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div className="space-y-1.5">
          <CardTitle>任务队列</CardTitle>
          <CardDescription>
            展示 AI 生成任务的排队与执行状态，未完成的任务会自动刷新（每 3 秒）。
          </CardDescription>
        </div>
        <div className="flex items-end gap-2">
          <div className="space-y-1">
            <div className="text-xs text-muted-foreground">状态筛选</div>
            <Select value={status} onValueChange={(v) => setStatus(v as AiJobStatus | 'all')}>
              <SelectTrigger className="w-36">
                <SelectValue placeholder="选择状态" />
              </SelectTrigger>
              <SelectContent>
                {STATUS_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <Button variant="outline" onClick={() => void refresh()} disabled={loading}>
            刷新
          </Button>
          <Button variant="outline" onClick={() => void handleCleanup()} disabled={cleanupBusy}>
            {cleanupBusy ? '清理中…' : '清理已完成'}
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {error && <p className="text-sm text-destructive">{error}</p>}
        {notice && <p className="text-sm text-emerald-600">{notice}</p>}

        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>标题</TableHead>
              <TableHead>状态</TableHead>
              <TableHead>阶段进度</TableHead>
              <TableHead>排队位次</TableHead>
              <TableHead>耗时</TableHead>
              <TableHead>创建时间</TableHead>
              <TableHead className="text-right">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && items.length === 0 && (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  加载中…
                </TableCell>
              </TableRow>
            )}
            {!loading && items.length === 0 && (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  {status === 'all' ? '暂无任务' : '没有符合筛选条件的任务'}
                </TableCell>
              </TableRow>
            )}
            {items.map((item) => {
              const meta = JOB_STATUS_META[item.status];
              const busy = busyId === item.id;
              const canStop = item.status === 'running' || item.status === 'queued';
              const canResume =
                item.status === 'error' ||
                item.status === 'stopped' ||
                item.status === 'interrupted';
              const canDelete = isSettled(item.status);
              return (
                <TableRow key={item.id}>
                  <TableCell className="max-w-[16rem]">
                    <div className="truncate font-medium" title={item.title}>
                      {item.title}
                    </div>
                    <div className="truncate font-mono text-xs text-muted-foreground" title={item.id}>
                      {item.id}
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary" className={TONE_CLASS[meta.tone]}>
                      {meta.label}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm">{jobStageProgressText(item)}</TableCell>
                  <TableCell className="text-sm text-muted-foreground">
                    {item.status === 'queued' && item.queuePos > 0 ? `第 ${item.queuePos} 位` : '—'}
                  </TableCell>
                  <TableCell className="text-sm">
                    {formatJobElapsed(item.startedAt, item.finishedAt)}
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">
                    {formatCreatedAt(item.createdAt)}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap items-center justify-end gap-1.5">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => router.push('/dashboard/templates/ai-tasks/' + item.id)}
                      >
                        查看详情
                      </Button>
                      {canStop && (
                        <Button
                          variant="outline"
                          size="sm"
                          disabled={busy}
                          onClick={() => void runRowAction(item.id, '已提交停止', () => stopAiJob(item.id))}
                        >
                          停止
                        </Button>
                      )}
                      {canResume && (
                        <Button
                          variant="outline"
                          size="sm"
                          disabled={busy}
                          onClick={() => void runRowAction(item.id, '已提交继续', () => resumeAiJob(item.id))}
                        >
                          继续
                        </Button>
                      )}
                      {canDelete && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-destructive hover:text-destructive"
                          disabled={busy}
                          onClick={() => handleDelete(item)}
                        >
                          删除
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}