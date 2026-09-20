'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import type {
  MigrationRecordView, MigrationRunningView, MigrationSummary, FailureRecord, StorageId,
} from '@/types/admin';
import { STORAGE_OPTIONS } from '@/types/admin';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import {
  startMigrationAction, stopMigrationAction, getMigrationStatusAction,
  listMigrationsAction, getMigrationDetailAction,
} from './actions';

const CATEGORY_LABEL: Record<string, string> = {
  templates: '模板（封面/多图/剪影）',
  categories: '分类图标',
  banners: 'Banner 配图',
  feedback: '反馈截图',
  users: '用户头像',
};

const PHASE_LABEL: Record<string, string> = {
  'enum-db': '枚举数据库引用…',
  'enum-disk': '扫描本地磁盘…',
  'enum-target': '读取目标存储清单…',
  copy: '回填至 Cloudflare R2…',
  verify: '逐实体全校验…',
  idle: '就绪',
};

const STATUS_VARIANT: Record<string, string> = {
  running: 'bg-blue-100 text-blue-700',
  success: 'bg-green-100 text-green-700',
  failed: 'bg-red-100 text-red-700',
  stopped: 'bg-amber-100 text-amber-700',
};

function fmtTime(sec: number | null | undefined): string {
  if (!sec) return '-';
  return new Date(sec * 1000).toLocaleString('zh-CN', { hour12: false });
}

function statusDot(status?: string) {
  const color =
    status === 'running' ? 'animate-pulse bg-blue-500' :
    status === 'success' ? 'bg-green-500' :
    status === 'failed' ? 'bg-red-500' : 'bg-amber-400';
  return <span className={cn('inline-block h-2 w-2 rounded-full', color)} />;
}

const STORAGE_LABEL: Record<StorageId, string> = Object.fromEntries(
  STORAGE_OPTIONS.map((o) => [o.value, o.label]),
) as Record<StorageId, string>;

export function MigrationClient({
  initialList, initialStatus,
}: {
  initialList: MigrationRecordView[];
  initialStatus: MigrationRunningView;
}) {
  const [status, setStatus] = useState<MigrationRunningView>(initialStatus);
  const [records, setRecords] = useState<MigrationRecordView[]>(initialList);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [target, setTarget] = useState<StorageId>('r2');
  const [detail, setDetail] = useState<MigrationRecordView | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const running = status.running;

  const refresh = useCallback(async () => {
    const [s, l] = await Promise.all([getMigrationStatusAction(), listMigrationsAction()]);
    if (s.ok && s.data) setStatus(s.data);
    if (l.ok && l.data) setRecords(l.data);
  }, []);

  useEffect(() => {
    if (!running) return;
    const t = setInterval(() => void refresh(), 2500);
    // 轮询间隙触发一次立即刷新，感知任务结束
    const donePoll = setInterval(() => {
      void getMigrationStatusAction().then((s) => {
        if (s.ok && s.data && !s.data.running) {
          if (status.running) void refresh();
        }
      });
    }, 1200);
    return () => { clearInterval(t); clearInterval(donePoll); };
  }, [running, refresh, status.running]);

  const onStart = async () => {
    setBusy(true); setErr(null);
    const res = await startMigrationAction('admin', target);
    setBusy(false);
    if (!res.ok) { setErr(res.error ?? '发起失败'); return; }
    await refresh();
  };

  const onStop = async () => {
    setBusy(true); setErr(null);
    const res = await stopMigrationAction();
    setBusy(false);
    if (!res.ok) setErr(res.error ?? '停止失败');
    setTimeout(() => void refresh(), 800);
  };

  const openDetail = async (id: string) => {
    setDetailLoading(true);
    const res = await getMigrationDetailAction(id);
    setDetailLoading(false);
    if (res.ok && res.data) setDetail(res.data);
    else setErr(res.error ?? '读取详情失败');
  };

  const progressPct = useMemo(() => {
    if (!status || !status.total) return 0;
    return Math.min(100, Math.round(((status.done ?? 0) / status.total) * 100));
  }, [status]);

  return (
    <div className="space-y-6">
      {/* 顶部操作 + 进度 */}
      <Card>
        <CardHeader className="flex flex-row items-start justify-between space-y-0">
          <div>
            <CardTitle>图片存储迁移</CardTitle>
            <CardDescription>
              迁移源＝当前激活存储（由服务器 UPLOAD_STORAGE / UPLOAD_R2 决定，自动识别，非写死）；
              迁移目标＝本次选择。迁移后逐实体全校验，失败明细存服务器本地。
              仅允许一个任务并发运行。
            </CardDescription>
          </div>
          <div className="flex items-end gap-2">
            <div className="space-y-1">
              <div className="text-xs text-muted-foreground">迁移目标</div>
              <Select value={target} onValueChange={(v) => setTarget(v as StorageId)} disabled={running}>
                <SelectTrigger className="w-44">
                  <SelectValue placeholder="选择目标存储" />
                </SelectTrigger>
                <SelectContent>
                  {STORAGE_OPTIONS.map((o) => (
                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button
              onClick={onStart}
              disabled={busy}
              variant={running ? 'secondary' : 'default'}
              className={running ? 'opacity-60' : ''}
            >
              {running ? '迁移进行中…' : '发起迁移'}
            </Button>
            <Button onClick={onStop} disabled={!running || busy} variant="destructive">
              停止
            </Button>
          </div>
        </CardHeader>
        <CardContent className="space-y-3">
          {running && (
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">
                  {PHASE_LABEL[status.phase ?? 'idle'] ?? status.phase}
                </span>
                <span className="font-medium">
                  已复制 {status.copied ?? 0} / 待处理 {status.total ?? 0}
                </span>
              </div>
              <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full bg-primary transition-all"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
            </div>
          )}
          {!running && (
            <p className="text-sm text-muted-foreground">当前无进行中的迁移任务。</p>
          )}
          {err && <p className="text-sm text-destructive">{err}</p>}
        </CardContent>
      </Card>

      {/* 迁移记录列表 */}
      <Card>
        <CardHeader>
          <CardTitle>迁移记录</CardTitle>
          <CardDescription>每次迁移在数据库中留一条记录；失败明细存于服务器本地文件。</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>记录 ID</TableHead>
                <TableHead>迁移路径</TableHead>
                <TableHead>状态</TableHead>
                <TableHead>触发人</TableHead>
                <TableHead>开始时间</TableHead>
                <TableHead>结果</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {records.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-muted-foreground">
                    暂无迁移记录
                  </TableCell>
                </TableRow>
              )}
              {records.map((r) => (
                <TableRow key={r.id} className="cursor-pointer" onClick={() => openDetail(r.id)}>
                  <TableCell className="font-mono text-xs">{r.id}</TableCell>
                  <TableCell className="text-xs">
                    {STORAGE_LABEL[r.sourceId] ?? r.sourceId}
                    <span className="mx-1 text-muted-foreground">→</span>
                    {STORAGE_LABEL[r.targetId] ?? r.targetId}
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary" className={STATUS_VARIANT[r.status]}>
                      <span className="flex items-center gap-1.5">
                        {statusDot(r.status)}
                        {r.status === 'success' ? '成功' : r.status === 'failed' ? '失败' : r.status === 'stopped' ? '已停止' : '进行中'}
                      </span>
                    </Badge>
                  </TableCell>
                  <TableCell>{r.triggerBy}</TableCell>
                  <TableCell className="text-xs">{fmtTime(r.startedAt)}</TableCell>
                  <TableCell className="text-xs text-muted-foreground">
                    {r.summary
                      ? `${r.summary.totals.migrated + r.summary.totals.copied} 已迁 · 失败 ${r.summary.totals.failed} · 坏数据 ${r.summary.totals.danglingDb}`
                      : (r.status === 'running' ? '进行中…' : '-')}
                  </TableCell>
                  <TableCell className="text-right text-sm text-primary">查看报告</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* 详情弹窗：全校验报告 + 失败明细 */}
      <Dialog open={!!detail} onOpenChange={(o) => { if (!o) setDetail(null); }}>
        <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {detail ? statusDot(detail.status) : null}
              迁移报告 · {detail?.id}
            </DialogTitle>
            <DialogDescription>
              开始 {fmtTime(detail?.startedAt)} · 结束 {fmtTime(detail?.finishedAt)}
              {detail?.error ? ` · 错误：${detail.error}` : ''}
            </DialogDescription>
          </DialogHeader>
          {detailLoading ? (
            <p className="text-sm text-muted-foreground">加载中…</p>
          ) : detail ? (
            <MigrationReport summary={detail.summary} failures={detail.failureDetail ?? []} />
          ) : (
            <p className="text-sm text-muted-foreground">无数据</p>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}

function MigrationReport({ summary, failures }: { summary: MigrationSummary | null; failures: FailureRecord[] }) {
  if (!summary) {
    return <p className="text-sm text-muted-foreground">该记录未产出汇总（可能被中止）。</p>;
  }
  const cats = ['templates', 'categories', 'banners', 'feedback', 'users'];
  return (
    <div className="space-y-4">
      {failures.length > 0 && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          本次迁移发现 {failures.length} 项问题，明细见下方「失败 / 异常明细」。
        </div>
      )}
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>存储类别</TableHead>
            <TableHead className="text-right">DB 引用</TableHead>
            <TableHead className="text-right">磁盘文件</TableHead>
            <TableHead className="text-right">已迁</TableHead>
            <TableHead className="text-right">本次复制</TableHead>
            <TableHead className="text-right">目标缺失</TableHead>
            <TableHead className="text-right">坏数据</TableHead>
            <TableHead className="text-right">孤儿</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {cats.map((cat) => {
            const r = summary.byCategory[cat];
            if (!r) return null;
            return (
              <TableRow key={cat}>
                <TableCell>{CATEGORY_LABEL[cat] ?? cat}</TableCell>
                <TableCell className="text-right">{r.dbTotal}</TableCell>
                <TableCell className="text-right">{r.diskTotal}</TableCell>
                <TableCell className="text-right">{r.migrated}</TableCell>
                <TableCell className="text-right">{r.copied}</TableCell>
                <TableCell className="text-right">
                  <span className={r.missingTarget > 0 ? 'text-destructive font-medium' : ''}>{r.missingTarget}</span>
                </TableCell>
                <TableCell className="text-right">
                  <span className={r.danglingDb > 0 ? 'text-destructive font-medium' : ''}>{r.danglingDb}</span>
                </TableCell>
                <TableCell className="text-right text-muted-foreground">{r.orphans}</TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Metric label="DB 引用总数" value={summary.totals.db} />
        <Metric label="磁盘文件总数" value={summary.totals.disk} />
        <Metric label="成功在目标存储" value={summary.totals.migrated + summary.totals.copied} />
        <Metric label="问题总数" value={summary.totals.failed} highlight={summary.totals.failed > 0} />
      </div>

      {failures.length > 0 && (
        <div>
          <h4 className="mb-2 text-sm font-semibold">失败 / 异常明细（读自服务器本地文件）</h4>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>阶段</TableHead>
                <TableHead>存储 Key</TableHead>
                <TableHead>实体</TableHead>
                <TableHead>原因</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {failures.map((f, i) => (
                <TableRow key={i}>
                  <TableCell className="text-xs">{f.phase === 'copy' ? '复制' : '校验'}</TableCell>
                  <TableCell className="font-mono text-xs">{f.storageKey}</TableCell>
                  <TableCell className="text-xs">{f.entityLabel ?? '-'}</TableCell>
                  <TableCell className="text-xs text-muted-foreground">{f.reason}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}

function Metric({ label, value, highlight }: { label: string; value: number; highlight?: boolean }) {
  return (
    <div className="rounded-md border bg-muted/40 p-3">
      <div className={cn('text-2xl font-semibold', highlight ? 'text-destructive' : 'text-foreground')}>{value}</div>
      <div className="text-xs text-muted-foreground">{label}</div>
    </div>
  );
}