// src/components/scene-manager.tsx
'use client';

import { useMemo, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog';
import {
  Plus, PencilSimple, Trash, Camera, MagnifyingGlass,
} from '@phosphor-icons/react';
import { useToast } from '@/hooks/use-toast';
import {
  saveScene, removeScene, setSceneActive,
} from '@/actions/scenes';
import type { AdminScene, UsageStatsItem, BuiltinScene } from '@/lib/api';

const CATEGORY_OPTIONS = [
  { value: 'light', label: '光线' },
  { value: 'outdoor', label: '户外' },
  { value: 'indoor', label: '室内' },
  { value: 'mood', label: '氛围' },
];

const CATEGORY_LABEL: Record<string, string> = Object.fromEntries(
  CATEGORY_OPTIONS.map((c) => [c.value, c.label]),
);

interface FormState {
  id: string;
  name: string;
  category: string;
  style: string;
  icon: string;
  vibe: string;
  description: string;
  bestTime: string;
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  id: '',
  name: '',
  category: '',
  style: '',
  icon: '',
  vibe: '',
  description: '',
  bestTime: '',
  sortOrder: 0,
  isActive: true,
};

export function SceneManager({
  scenes,
  usage = {},
  builtinScenes = [],
}: {
  scenes: AdminScene[];
  usage?: Record<string, Pick<UsageStatsItem, 'useShoot' | 'openDetail' | 'sceneSelect'>>;
  builtinScenes?: BuiltinScene[];
}) {
  const router = useRouter();
  const { toast } = useToast();

  const [search, setSearch] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmitTransition] = useTransition();
  const [pendingToggleId, setPendingToggleId] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [deleteTarget, setDeleteTarget] = useState<AdminScene | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();

  const filtered = scenes.filter((s) => {
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return (
      s.name.toLowerCase().includes(q) ||
      s.id.toLowerCase().includes(q) ||
      (CATEGORY_LABEL[s.category] || s.category).toLowerCase().includes(q)
    );
  });

  // 内置场景（排除已在主网格展示的系统场景 id，避免重复）
  const builtinRecords = useMemo(() => {
    const backendIds = new Set(scenes.map((s) => s.id));
    return builtinScenes.filter((b) => !backendIds.has(b.id));
  }, [builtinScenes, scenes]);

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError(null);
    setDialogOpen(true);
  };

  const openEdit = (s: AdminScene) => {
    setEditingId(s.id);
    setForm({
      id: s.id,
      name: s.name,
      category: s.category,
      style: s.style,
      icon: s.icon,
      vibe: s.vibe,
      description: s.description,
      bestTime: s.bestTime,
      sortOrder: s.sortOrder,
      isActive: s.isActive,
    });
    setError(null);
    setDialogOpen(true);
  };

  const handleSubmit = () => {
    setError(null);
    if (!editingId && !form.id.trim()) {
      setError('请填写场景 id');
      return;
    }
    if (!form.name.trim()) {
      setError('请填写场景名称');
      return;
    }
    if (!form.category) {
      setError('请选择场景分类');
      return;
    }

    const payload: Record<string, unknown> = {
      name: form.name.trim(),
      category: form.category,
      style: form.style.trim(),
      icon: form.icon.trim(),
      vibe: form.vibe.trim(),
      description: form.description.trim(),
      bestTime: form.bestTime.trim(),
      sortOrder: Number(form.sortOrder) || 0,
      isActive: form.isActive,
    };
    if (!editingId) payload.id = form.id.trim();

    startSubmitTransition(async () => {
      const result = await saveScene(editingId, payload);
      if (result?.error) {
        setError(result.error);
        return;
      }
      toast({
        title: editingId ? '已更新' : '已创建',
        description: `场景「${form.name}」${editingId ? '已更新' : '已创建'}`,
      });
      setDialogOpen(false);
      router.refresh();
    });
  };

  const handleToggle = (s: AdminScene) => {
    setPendingToggleId(s.id);
    startToggleTransition(async () => {
      const result = await setSceneActive(s.id);
      setPendingToggleId(null);
      if (result?.error) {
        toast({ variant: 'destructive', title: '操作失败', description: result.error });
      } else {
        toast({
          title: result.isActive ? '已启用' : '已停用',
          description: `「${s.name}」${result.isActive ? '已启用' : '已停用'}`,
        });
        router.refresh();
      }
    });
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    const id = deleteTarget.id;
    startDeleteTransition(async () => {
      const result = await removeScene(id);
      if (result?.error) {
        toast({ variant: 'destructive', title: '删除失败', description: result.error });
      } else {
        toast({ title: '已删除', description: `「${deleteTarget.name}」已删除` });
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
          <h2 className="text-lg font-semibold tracking-tight text-foreground">场景管理</h2>
          <span className="hidden text-xs text-muted-foreground md:inline">
            光线 / 户外 / 室内 / 氛围
          </span>
        </div>
        <div className="flex items-center gap-2">
          <div className="relative">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground"
            />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="搜索名称 / id"
              className="h-9 w-48 pl-8 sm:w-56"
            />
          </div>
          <Button size="sm" onClick={openCreate}>
            <Plus size={16} className="mr-1" /> 新建场景
          </Button>
        </div>
      </div>

      {/* 场景统计胶囊 */}
      <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{scenes.length}</span>
          <span className="ml-1.5">全部</span>
        </Badge>
        <Badge variant="secondary">
          <span className="font-medium text-foreground">{scenes.filter((s) => s.isActive).length}</span>
          <span className="ml-1.5">启用</span>
        </Badge>
      </div>

      {/* 网格 */}
      {filtered.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border bg-card py-16 text-center text-muted-foreground">
          {search.trim()
            ? '没有匹配的场景，换个关键词试试'
            : '暂无场景，点击右上角「新建场景」创建'}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filtered.map((s) => {
            const u = usage[s.id];
            return (
              <div
                key={s.id}
                className="group flex flex-col gap-3 rounded-lg border border-border bg-card p-4 shadow-sm transition-shadow hover:shadow-md"
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-input bg-muted text-muted-foreground">
                      {s.icon ? (
                        <span className="text-lg">{s.icon}</span>
                      ) : (
                        <Camera size={18} />
                      )}
                    </div>
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-foreground">{s.name}</p>
                      <code className="block max-w-[160px] truncate font-mono text-xs text-muted-foreground/70">
                        {s.id}
                      </code>
                    </div>
                  </div>
                  <Badge
                    variant={s.isActive ? 'default' : 'secondary'}
                    className="shrink-0"
                  >
                    {s.isActive ? '启用' : '停用'}
                  </Badge>
                </div>

                <div className="flex flex-wrap items-center gap-1.5 text-[11px]">
                  <Badge variant="outline" className="text-[11px]">
                    {CATEGORY_LABEL[s.category] || s.category}
                  </Badge>
                  {s.style && (
                    <Badge variant="outline" className="text-[11px]">
                      {s.style}
                    </Badge>
                  )}
                  {s.vibe && (
                    <Badge variant="outline" className="text-[11px]">
                      {s.vibe}
                    </Badge>
                  )}
                </div>

                {s.description && (
                  <p className="line-clamp-2 text-xs text-muted-foreground">{s.description}</p>
                )}

                {u && (
                  <p className="text-xs text-muted-foreground">
                    拍摄 {u.useShoot} · 查看 {u.openDetail} · 选场 {u.sceneSelect}
                  </p>
                )}

                <div className="mt-auto flex items-center justify-between gap-2 border-t border-border/60 pt-3">
                  <div className="flex items-center gap-1.5">
                    <Switch
                      checked={s.isActive}
                      disabled={togglePending && pendingToggleId === s.id}
                      onCheckedChange={() => handleToggle(s)}
                      aria-label="切换启停"
                    />
                    <span className="text-xs text-muted-foreground">
                      {s.isActive ? '启用' : '停用'}
                    </span>
                  </div>
                  <div className="flex items-center gap-0.5">
                    <button
                      type="button"
                      title="编辑"
                      onClick={() => openEdit(s)}
                      className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                    >
                      <PencilSimple size={15} />
                    </button>
                    <button
                      type="button"
                      title="删除"
                      onClick={() => setDeleteTarget(s)}
                      className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                    >
                      <Trash size={15} />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* 内置场景分区（App 内嵌，后端只读展示名称与次数） */}
      <div className="space-y-3">
        <div className="flex items-center gap-2 pt-2">
          <h2 className="text-sm font-semibold text-foreground">内置场景</h2>
          <Badge variant="secondary" className="text-xs">
            {builtinRecords.length}
          </Badge>
        </div>
        {builtinRecords.length === 0 ? (
          <div className="rounded-lg border border-dashed border-border bg-card py-10 text-center text-sm text-muted-foreground">
            暂未获取到内置场景记录，App 同步后展示
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {builtinRecords.map((b) => {
              const u = usage[b.id];
              return (
                <div
                  key={b.id}
                  className="flex flex-col overflow-hidden rounded-lg border border-border bg-card shadow-sm"
                >
                  <div className="flex h-16 w-full items-center justify-center bg-muted">
                    <span className="rounded-full bg-indigo-500/85 px-2 py-0.5 text-[11px] font-medium text-white backdrop-blur">
                      内置
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-1 p-3">
                    <span className="truncate text-sm font-medium text-foreground">
                      {b.name || b.id}
                    </span>
                    <span className="truncate text-xs text-muted-foreground">{b.id}</span>
                    <span className="mt-1 flex items-center gap-2 text-[11px] text-muted-foreground tabular-nums">
                      <span>拍摄 {u?.useShoot ?? 0}</span>
                      <span>查看 {u?.openDetail ?? 0}</span>
                      <span>选场 {u?.sceneSelect ?? 0}</span>
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* 新建 / 编辑对话框 */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-left">
              {editingId ? '编辑场景' : '新建场景'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingId
                ? `修改场景「${editingId}」的属性。id 不可更改。`
                : '创建系统内置场景。id 为唯一标识，建议使用小写英文 + 连字符。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="scene-id">Id *</Label>
              <Input
                id="scene-id"
                value={form.id}
                onChange={(e) => setForm({ ...form, id: e.target.value })}
                placeholder="如：window-light / fierce-sun"
                disabled={Boolean(editingId)}
                className="font-mono"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="scene-name">名称 *</Label>
              <Input
                id="scene-name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="如：窗边光"
              />
            </div>

            <div className="space-y-2">
              <Label>分类 *</Label>
              <Select
                value={form.category}
                onValueChange={(v) => setForm({ ...form, category: v })}
              >
                <SelectTrigger><SelectValue placeholder="选择分类" /></SelectTrigger>
                <SelectContent>
                  {CATEGORY_OPTIONS.map((c) => (
                    <SelectItem key={c.value} value={c.value}>
                      {c.label} ({c.value})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="scene-style">风格</Label>
                <Input
                  id="scene-style"
                  value={form.style}
                  onChange={(e) => setForm({ ...form, style: e.target.value })}
                  placeholder="如：自然 / 电影感"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="scene-vibe">氛围</Label>
                <Input
                  id="scene-vibe"
                  value={form.vibe}
                  onChange={(e) => setForm({ ...form, vibe: e.target.value })}
                  placeholder="如：安静 / 温暖"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="scene-icon">图标（emoji 或文本）</Label>
                <Input
                  id="scene-icon"
                  value={form.icon}
                  onChange={(e) => setForm({ ...form, icon: e.target.value })}
                  placeholder="如：🪟"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="scene-best-time">最佳时间</Label>
                <Input
                  id="scene-best-time"
                  value={form.bestTime}
                  onChange={(e) => setForm({ ...form, bestTime: e.target.value })}
                  placeholder="如：清晨 6:00-8:00"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="scene-desc">描述</Label>
              <Input
                id="scene-desc"
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="场景说明"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="scene-sort">排序</Label>
                <Input
                  id="scene-sort"
                  type="number"
                  value={form.sortOrder}
                  onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                />
              </div>
              <div className="space-y-2">
                <Label>是否启用</Label>
                <div className="flex h-10 items-center gap-2">
                  <Switch
                    checked={form.isActive}
                    onCheckedChange={(checked) => setForm({ ...form, isActive: checked })}
                  />
                  <span className="text-sm text-muted-foreground">
                    {form.isActive ? '启用' : '停用'}
                  </span>
                </div>
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
            <DialogTitle className="text-left">删除场景</DialogTitle>
            <DialogDescription className="text-left">
              确定要删除场景「{deleteTarget?.name}」({deleteTarget?.id}) 吗？此操作不可撤销。
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

export default SceneManager;