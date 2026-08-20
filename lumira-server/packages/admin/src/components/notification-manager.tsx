// src/components/notification-manager.tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Plus, PencilSimple, Trash, Megaphone } from '@phosphor-icons/react/dist/ssr';
import { useToast } from '@/hooks/use-toast';
import {
  saveNotification, removeNotification, setNotificationActive,
  type NotificationMutationBody,
} from '@/actions/notifications';
import type { NotificationAdminItem } from '@/types/admin';

const SCOPE_OPTIONS: Array<{ value: NotificationAdminItem['targetScope']; label: string }> = [
  { value: 'all', label: '全部用户' },
  { value: 'devices', label: '指定设备' },
  { value: 'criteria', label: '按条件匹配' },
];

const SCOPE_LABEL = Object.fromEntries(SCOPE_OPTIONS.map((c) => [c.value, c.label])) as Record<
  NotificationAdminItem['targetScope'],
  string
>;

const CRITERIA_FIELDS: Array<{ key: string; label: string; placeholder: string }> = [
  { key: 'platform', label: '平台', placeholder: '如：ios, android（留空 = 不限）' },
  { key: 'deviceModel', label: '机型', placeholder: '如：iPhone 15 Pro（逗号分隔，留空 = 不限）' },
  { key: 'osVersion', label: '系统版本', placeholder: '如：18.0（逗号分隔，留空 = 不限）' },
  { key: 'appVersion', label: 'APP 版本', placeholder: '如：1.2.0（逗号分隔，留空 = 不限）' },
  { key: 'email', label: '邮箱', placeholder: '如：a@x.com（逗号分隔，留空 = 不限）' },
];

interface FormState {
  id: string;
  title: string;
  body: string;
  category: string;
  iconKey: string;
  targetScope: NotificationAdminItem['targetScope'];
  deviceIdsText: string;
  criteria: Record<string, string>;
  startAt: string; // datetime-local 字符串
  endAt: string;
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  id: '',
  title: '',
  body: '',
  category: 'announcement',
  iconKey: 'announcement',
  targetScope: 'all',
  deviceIdsText: '',
  criteria: { platform: '', deviceModel: '', osVersion: '', appVersion: '', email: '' },
  startAt: '',
  endAt: '',
  sortOrder: 0,
  isActive: true,
};

/** 毫秒时间戳 → datetime-local 可编辑字符串（本地时区） */
function msToLocalInput(value: number | null | undefined): string {
  if (!value) return '';
  const d = new Date(value);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** datetime-local 字符串 → 毫秒时间戳；空返回 null */
function localInputToMs(value: string): number | null {
  if (!value) return null;
  const t = new Date(value).getTime();
  return Number.isNaN(t) ? null : t;
}

function formatMs(value: number | null | undefined, fallback: string): string {
  if (!value) return fallback;
  return new Date(value).toLocaleString();
}

export function NotificationManager({ notifications }: { notifications: NotificationAdminItem[] }) {
  const router = useRouter();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmitTransition] = useTransition();
  const [pendingToggleId, setPendingToggleId] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [deleteTarget, setDeleteTarget] = useState<NotificationAdminItem | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();

  const targetSummary = (n: NotificationAdminItem): string => {
    if (n.targetScope === 'all') return '全部用户';
    if (n.targetScope === 'devices') return `${n.targetDeviceIds.length} 台设备`;
    const parts = Object.entries(n.targetCriteria)
      .filter(([, v]) => v.length > 0)
      .map(([k, v]) => `${k}: ${v.join('、')}`);
    return parts.length ? parts.join('；') : '条件不限';
  };

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError(null);
    setDialogOpen(true);
  };

  const openEdit = (n: NotificationAdminItem) => {
    setEditingId(n.id);
    setForm({
      id: n.id,
      title: n.title,
      body: n.body,
      category: n.category,
      iconKey: n.iconKey,
      targetScope: n.targetScope,
      deviceIdsText: n.targetDeviceIds.join('\n'),
      criteria: Object.fromEntries(CRITERIA_FIELDS.map((f) => [f.key, (n.targetCriteria[f.key] ?? []).join(', ')])),
      startAt: msToLocalInput(n.startAt),
      endAt: msToLocalInput(n.endAt),
      sortOrder: n.sortOrder,
      isActive: n.isActive === 1,
    });
    setError(null);
    setDialogOpen(true);
  };

  const handleSubmit = () => {
    setError(null);
    if (!editingId && !form.id.trim()) {
      setError('请填写通知 id');
      return;
    }
    if (!form.title.trim()) {
      setError('请填写通知标题');
      return;
    }
    if (!form.body.trim()) {
      setError('请填写通知内容');
      return;
    }

    const body: NotificationMutationBody = {
      title: form.title.trim(),
      body: form.body.trim(),
      category: form.category.trim() || 'announcement',
      iconKey: form.iconKey.trim() || 'announcement',
      targetScope: form.targetScope,
      startAt: localInputToMs(form.startAt),
      endAt: localInputToMs(form.endAt),
      sortOrder: Number(form.sortOrder) || 0,
      isActive: form.isActive,
    };
    if (!editingId) body.id = form.id.trim();

    if (form.targetScope === 'devices') {
      body.targetDeviceIds = form.deviceIdsText
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean);
    } else if (form.targetScope === 'criteria') {
      const crit: Record<string, string[]> = {};
      for (const f of CRITERIA_FIELDS) {
        const vals = (form.criteria[f.key] ?? '')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);
        if (vals.length) crit[f.key] = vals;
      }
      body.targetCriteria = crit;
    }

    startSubmitTransition(async () => {
      const result = await saveNotification(editingId, body);
      if (result?.error) {
        setError(result.error);
        return;
      }
      toast({
        title: editingId ? '已更新' : '已创建',
        description: `通知「${form.title}」${editingId ? '已更新' : '已创建'}`,
      });
      setDialogOpen(false);
      router.refresh();
    });
  };

  const handleToggle = (n: NotificationAdminItem) => {
    setPendingToggleId(n.id);
    startToggleTransition(async () => {
      const result = await setNotificationActive(n.id);
      setPendingToggleId(null);
      if (result?.error) {
        toast({ variant: 'destructive', title: '操作失败', description: result.error });
      } else {
        toast({
          title: result.isActive ? '已启用' : '已停用',
          description: `「${n.title}」${result.isActive ? '已启用' : '已停用'}`,
        });
        router.refresh();
      }
    });
  };

  const handleDelete = () => {
    if (!deleteTarget) return;
    const id = deleteTarget.id;
    const name = deleteTarget.title;
    startDeleteTransition(async () => {
      const result = await removeNotification(id);
      if (result?.error) {
        toast({ variant: 'destructive', title: '删除失败', description: result.error });
      } else {
        toast({ title: '已删除', description: `「${name}」已删除` });
        setDeleteTarget(null);
        router.refresh();
      }
    });
  };

  return (
    <div className="space-y-5">
      {/* 页头 */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-baseline gap-2.5">
          <h2 className="text-lg font-semibold tracking-tight text-foreground">通知公告</h2>
          <span className="hidden text-xs text-muted-foreground md:inline">
            管理 App 内公告推送与定向投放
          </span>
        </div>
        <Button size="sm" onClick={openCreate}>
          <Plus size={16} className="mr-1" /> 新建通知
        </Button>
      </div>

      <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{notifications.length}</span>
          <span className="ml-1.5">全部</span>
        </Badge>
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{notifications.filter((n) => n.isActive === 1).length}</span>
          <span className="ml-1.5">启用</span>
        </Badge>
      </div>

      {/* 列表表格 */}
      {notifications.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border bg-card py-16 text-center text-muted-foreground">
          暂无通知，点击右上角「新建通知」创建
        </div>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border bg-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>标题</TableHead>
                <TableHead>分类</TableHead>
                <TableHead>定向摘要</TableHead>
                <TableHead>投放窗口</TableHead>
                <TableHead>创建时间</TableHead>
                <TableHead>启停</TableHead>
                <TableHead className="text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {notifications.map((n) => (
                <TableRow key={n.id}>
                  <TableCell>
                    <div className="flex items-center gap-2 min-w-0">
                      {n.iconKey && n.iconKey !== 'announcement' ? (
                        <span className="text-base">{n.iconKey}</span>
                      ) : (
                        <Megaphone size={16} className="shrink-0 text-muted-foreground" />
                      )}
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-foreground">{n.title}</p>
                        <code className="block max-w-[180px] truncate font-mono text-xs text-muted-foreground/70">
                          {n.id}
                        </code>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">{n.category || 'announcement'}</Badge>
                  </TableCell>
                  <TableCell className="max-w-[220px]">
                    <Badge variant="secondary">{SCOPE_LABEL[n.targetScope]}</Badge>
                    <p className="mt-1 truncate text-xs text-muted-foreground" title={targetSummary(n)}>
                      {targetSummary(n)}
                    </p>
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                    {n.startAt || n.endAt
                      ? `${formatMs(n.startAt, '不限')} → ${formatMs(n.endAt, '不限')}`
                      : '长期有效'}
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                    {new Date(n.createdAt).toLocaleString()}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1.5">
                      <Switch
                        checked={n.isActive === 1}
                        disabled={togglePending && pendingToggleId === n.id}
                        onCheckedChange={() => handleToggle(n)}
                        aria-label="切换启停"
                      />
                      <span className="text-xs text-muted-foreground">
                        {n.isActive === 1 ? '启用' : '停用'}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-0.5">
                      <button
                        type="button"
                        title="编辑"
                        onClick={() => openEdit(n)}
                        className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                      >
                        <PencilSimple size={15} />
                      </button>
                      <button
                        type="button"
                        title="删除"
                        onClick={() => setDeleteTarget(n)}
                        className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                      >
                        <Trash size={15} />
                      </button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* 新建 / 编辑对话框 */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader>
            <DialogTitle className="text-left">
              {editingId ? '编辑通知' : '新建通知'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingId
                ? `修改通知「${editingId}」。id 不可更改。`
                : '创建 App 通知公告。id 为唯一标识，建议使用小写英文 + 连字符。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="ntf-id">Id *</Label>
                <Input
                  id="ntf-id"
                  value={form.id}
                  onChange={(e) => setForm({ ...form, id: e.target.value })}
                  placeholder="如：welcome-2026"
                  disabled={Boolean(editingId)}
                  className="font-mono"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ntf-category">分类</Label>
                <Input
                  id="ntf-category"
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                  placeholder="默认 announcement"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="ntf-title">标题 *</Label>
              <Input
                id="ntf-title"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="如：新功能上线"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="ntf-body">内容 *</Label>
              <Textarea
                id="ntf-body"
                value={form.body}
                onChange={(e) => setForm({ ...form, body: e.target.value })}
                placeholder="通知正文"
                rows={3}
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="ntf-icon">图标（emoji）</Label>
                <Input
                  id="ntf-icon"
                  value={form.iconKey}
                  onChange={(e) => setForm({ ...form, iconKey: e.target.value })}
                  placeholder="如：📢（默认 announcement）"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ntf-sort">排序</Label>
                <Input
                  id="ntf-sort"
                  type="number"
                  value={form.sortOrder}
                  onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="ntf-start">投放开始（可选）</Label>
                <Input
                  id="ntf-start"
                  type="datetime-local"
                  value={form.startAt}
                  onChange={(e) => setForm({ ...form, startAt: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ntf-end">投放结束（可选）</Label>
                <Input
                  id="ntf-end"
                  type="datetime-local"
                  value={form.endAt}
                  onChange={(e) => setForm({ ...form, endAt: e.target.value })}
                />
              </div>
            </div>

            {/* 定向作用域 */}
            <div className="space-y-2">
              <Label>定向作用域 *</Label>
              <Select
                value={form.targetScope}
                onValueChange={(v) => setForm({ ...form, targetScope: v as NotificationAdminItem['targetScope'] })}
              >
                <SelectTrigger><SelectValue placeholder="选择作用域" /></SelectTrigger>
                <SelectContent>
                  {SCOPE_OPTIONS.map((c) => (
                    <SelectItem key={c.value} value={c.value}>
                      {c.label} ({c.value})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {form.targetScope === 'devices' && (
              <div className="space-y-2">
                <Label htmlFor="ntf-devices">指定设备 id</Label>
                <Textarea
                  id="ntf-devices"
                  value={form.deviceIdsText}
                  onChange={(e) => setForm({ ...form, deviceIdsText: e.target.value })}
                  placeholder={'每行一个设备 id，如：\ndevice-abc123\ndevice-def456'}
                  rows={4}
                  className="font-mono"
                />
                <p className="text-xs text-muted-foreground">留空 = 不发给任何设备；请至少填写一个设备 id。</p>
              </div>
            )}

            {form.targetScope === 'criteria' && (
              <div className="space-y-3 rounded-lg border border-border p-3">
                <p className="text-xs text-muted-foreground">
                  条件留空 = 不限制该维度。多值用英文逗号分隔；填写 <code>{'*'}</code> 表示通配该维度所有值。
                </p>
                {CRITERIA_FIELDS.map((f) => (
                  <div key={f.key} className="space-y-1.5">
                    <Label htmlFor={`ntf-c-${f.key}`}>{f.label}</Label>
                    <Input
                      id={`ntf-c-${f.key}`}
                      value={form.criteria[f.key] ?? ''}
                      onChange={(e) => setForm({ ...form, criteria: { ...form.criteria, [f.key]: e.target.value } })}
                      placeholder={f.placeholder}
                    />
                  </div>
                ))}
              </div>
            )}

            <div className="flex h-10 items-center gap-2">
              <Switch
                checked={form.isActive}
                onCheckedChange={(checked) => setForm({ ...form, isActive: checked })}
              />
              <span className="text-sm text-muted-foreground">
                {form.isActive ? '发布为启用' : '保存为停用'}
              </span>
            </div>
          </div>

          {error && <p className="text-sm text-destructive" role="alert">{error}</p>}

          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => setDialogOpen(false)}
              disabled={submitPending}
            >
              取消
            </Button>
            <Button onClick={handleSubmit} disabled={submitPending}>
              {submitPending ? '保存中…' : editingId ? '保存' : '创建'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 删除确认对话框 */}
      <Dialog
        open={deleteTarget !== null}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-left">删除通知</DialogTitle>
            <DialogDescription className="text-left">
              确定要删除通知「{deleteTarget?.title}」({deleteTarget?.id}) 吗？此操作不可撤销。
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setDeleteTarget(null)} disabled={deletePending}>
              取消
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={deletePending}>
              {deletePending ? '删除中…' : '确认删除'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default NotificationManager;