// src/components/banner-manager.tsx
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
import { Plus } from '@phosphor-icons/react/dist/csr/Plus';
import { PencilSimple } from '@phosphor-icons/react/dist/csr/PencilSimple';
import { Trash } from '@phosphor-icons/react/dist/csr/Trash';
import { ImageSquare } from '@phosphor-icons/react/dist/csr/ImageSquare';
import { useToast } from '@/hooks/use-toast';
import { saveBanner, removeBanner, setBannerActive } from '@/actions/banners';
import type { BannerAdminItem, BannerPayload } from '@/types/admin';

const ROUTE_OPTIONS = [
  { value: '/invite', label: '邀请页（/invite）' },
  { value: '/points/wallet', label: '积分钱包（/points/wallet）' },
  { value: '/templates/unlock', label: '模板解锁（/templates/unlock）' },
];

const ROUTE_LABEL = Object.fromEntries(ROUTE_OPTIONS.map((r) => [r.value, r.label])) as Record<string, string>;

const CONDITION_OPTIONS = [
  { value: 'nonNewUserNotInvited', label: '老用户未绑定邀请码' },
  { value: 'pointsReady', label: '积分余额 > 0' },
  { value: 'hasLockedTemplate', label: '存在未解锁付费模板' },
];

const CONDITION_LABEL = Object.fromEntries(CONDITION_OPTIONS.map((c) => [c.value, c.label])) as Record<string, string>;

interface FormState {
  id: string;
  title: string;
  subtitle: string;
  tag: string;
  route: string;
  condition: string;
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  id: '',
  title: '',
  subtitle: '',
  tag: '',
  route: '/invite',
  condition: 'nonNewUserNotInvited',
  sortOrder: 0,
  isActive: true,
};

/** 秒级时间戳 → 本地时间字符串 */
function formatSec(value: number): string {
  return new Date(value * 1000).toLocaleString();
}

export function BannerManager({ banners }: { banners: BannerAdminItem[] }) {
  const router = useRouter();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmitTransition] = useTransition();
  const [pendingToggleId, setPendingToggleId] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [deleteTarget, setDeleteTarget] = useState<BannerAdminItem | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError(null);
    setDialogOpen(true);
  };

  const openEdit = (b: BannerAdminItem) => {
    setEditingId(b.id);
    setForm({
      id: b.id,
      title: b.title,
      subtitle: b.subtitle,
      tag: b.tag,
      route: b.route,
      condition: b.condition,
      sortOrder: b.sortOrder,
      isActive: b.isActive === 1,
    });
    setError(null);
    setDialogOpen(true);
  };

  const handleSubmit = () => {
    setError(null);
    if (!editingId && !form.id.trim()) {
      setError('请填写 Banner id');
      return;
    }
    if (!/^[a-z0-9_-]{2,64}$/.test(form.id.trim()) && !editingId) {
      setError('id 仅支持小写字母、数字、下划线、连字符（2-64 位）');
      return;
    }
    if (!form.title.trim()) {
      setError('请填写主标题');
      return;
    }
    if (!form.subtitle.trim()) {
      setError('请填写副标题');
      return;
    }
    if (!form.tag.trim()) {
      setError('请填写角标文案');
      return;
    }

    const payload: BannerPayload = {
      title: form.title.trim(),
      subtitle: form.subtitle.trim(),
      tag: form.tag.trim(),
      route: form.route,
      condition: form.condition,
      sortOrder: Number(form.sortOrder) || 0,
      isActive: form.isActive,
    };
    if (!editingId) payload.id = form.id.trim();

    startSubmitTransition(async () => {
      const result = await saveBanner(editingId, payload);
      if (result?.error) {
        setError(result.error);
        return;
      }
      toast({
        title: editingId ? '已更新' : '已创建',
        description: `Banner「${form.title}」${editingId ? '已更新' : '已创建'}`,
      });
      setDialogOpen(false);
      router.refresh();
    });
  };

  const handleToggle = (b: BannerAdminItem) => {
    setPendingToggleId(b.id);
    startToggleTransition(async () => {
      const result = await setBannerActive(b.id);
      setPendingToggleId(null);
      if (result?.error) {
        toast({ variant: 'destructive', title: '操作失败', description: result.error });
      } else {
        toast({
          title: result.isActive ? '已启用' : '已停用',
          description: `「${b.title}」${result.isActive ? '已启用' : '已停用'}`,
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
      const result = await removeBanner(id);
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
          <h2 className="text-lg font-semibold tracking-tight text-foreground">Banner 运营</h2>
          <span className="hidden text-xs text-muted-foreground md:inline">
            管理 App 首页运营位（文案 / 条件 / 跳转 / 排序 / 启停）
          </span>
        </div>
        <Button size="sm" onClick={openCreate}>
          <Plus size={16} className="mr-1" /> 新建 Banner
        </Button>
      </div>

      <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{banners.length}</span>
          <span className="ml-1.5">全部</span>
        </Badge>
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{banners.filter((b) => b.isActive === 1).length}</span>
          <span className="ml-1.5">启用</span>
        </Badge>
      </div>

      {/* 列表表格 */}
      {banners.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border bg-card py-16 text-center text-muted-foreground">
          暂无运营 Banner，点击右上角「新建 Banner」创建
        </div>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border bg-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>标题</TableHead>
                <TableHead>角标</TableHead>
                <TableHead>跳转路由</TableHead>
                <TableHead>展示条件</TableHead>
                <TableHead>排序</TableHead>
                <TableHead>更新时间</TableHead>
                <TableHead>启停</TableHead>
                <TableHead className="text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {banners.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>
                    <div className="flex items-center gap-2 min-w-0">
                      <ImageSquare size={16} className="shrink-0 text-muted-foreground" />
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-foreground">{b.title}</p>
                        <code className="block max-w-[180px] truncate font-mono text-xs text-muted-foreground/70">
                          {b.id}
                        </code>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">{b.tag}</Badge>
                  </TableCell>
                  <TableCell className="max-w-[200px]">
                    <code className="block truncate font-mono text-xs text-muted-foreground" title={b.route}>
                      {b.route}
                    </code>
                  </TableCell>
                  <TableCell className="max-w-[180px]">
                    <Badge variant="secondary">{CONDITION_LABEL[b.condition] ?? b.condition}</Badge>
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">{b.sortOrder}</TableCell>
                  <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                    {formatSec(b.updatedAt)}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1.5">
                      <Switch
                        checked={b.isActive === 1}
                        disabled={togglePending && pendingToggleId === b.id}
                        onCheckedChange={() => handleToggle(b)}
                        aria-label="切换启停"
                      />
                      <span className="text-xs text-muted-foreground">
                        {b.isActive === 1 ? '启用' : '停用'}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-0.5">
                      <button
                        type="button"
                        title="编辑"
                        onClick={() => openEdit(b)}
                        className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                      >
                        <PencilSimple size={15} />
                      </button>
                      <button
                        type="button"
                        title="删除"
                        onClick={() => setDeleteTarget(b)}
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
              {editingId ? '编辑 Banner' : '新建 Banner'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingId
                ? `修改运营位「${editingId}」。id 不可更改。`
                : 'App 首页运营位配置。id 为唯一标识（App 埋点 trackingId），建议使用小写英文 + 连字符。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="bnr-id">Id *</Label>
                <Input
                  id="bnr-id"
                  value={form.id}
                  onChange={(e) => setForm({ ...form, id: e.target.value })}
                  placeholder="如：op_invite"
                  disabled={Boolean(editingId)}
                  className="font-mono"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="bnr-tag">角标文案 *</Label>
                <Input
                  id="bnr-tag"
                  value={form.tag}
                  onChange={(e) => setForm({ ...form, tag: e.target.value })}
                  placeholder="如：邀请有礼（32 字以内）"
                  maxLength={32}
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="bnr-title">主标题 *</Label>
              <Input
                id="bnr-title"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="如：邀请好友 · 双方各+30分"
                maxLength={128}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="bnr-subtitle">副标题 *</Label>
              <Textarea
                id="bnr-subtitle"
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                placeholder="Banner 副标题说明文案"
                rows={2}
                maxLength={255}
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>跳转路由 *</Label>
                <Select
                  value={form.route}
                  onValueChange={(v) => setForm({ ...form, route: v })}
                >
                  <SelectTrigger><SelectValue placeholder="选择路由" /></SelectTrigger>
                  <SelectContent>
                    {ROUTE_OPTIONS.map((r) => (
                      <SelectItem key={r.value} value={r.value}>
                        {r.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>展示条件 *</Label>
                <Select
                  value={form.condition}
                  onValueChange={(v) => setForm({ ...form, condition: v })}
                >
                  <SelectTrigger><SelectValue placeholder="选择条件" /></SelectTrigger>
                  <SelectContent>
                    {CONDITION_OPTIONS.map((c) => (
                      <SelectItem key={c.value} value={c.value}>
                        {c.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="bnr-sort">排序（小值在前）</Label>
                <Input
                  id="bnr-sort"
                  type="number"
                  value={form.sortOrder}
                  onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                />
              </div>
              <div className="flex h-10 items-end gap-2 pb-1">
                <Switch
                  checked={form.isActive}
                  onCheckedChange={(checked) => setForm({ ...form, isActive: checked })}
                />
                <span className="text-sm text-muted-foreground">
                  {form.isActive ? '保存为启用' : '保存为停用'}
                </span>
              </div>
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
            <DialogTitle className="text-left">删除 Banner</DialogTitle>
            <DialogDescription className="text-left">
              确定要删除运营位「{deleteTarget?.title}」({deleteTarget?.id}) 吗？删除后 App 端将不再下发该条目，此操作不可撤销。
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

export default BannerManager;
