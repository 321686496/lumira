'use client';

import { useMemo, useState, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Input } from '@/components/ui/input';
import {
  Dialog, DialogContent, DialogDescription, DialogFooter,
  DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import {
  MagnifyingGlass, PencilSimple, Trash, Plus,
} from '@phosphor-icons/react';
import { formatUnixTime } from '@/lib/utils';
import { toAssetUrl } from '@/lib/asset-url';
import { useToast } from '@/hooks/use-toast';
import { toggleTemplateActive, deleteTemplate } from '@/actions/templates';
import type { AdminTemplateListItem, TemplateCategory } from '@/types/admin';
import type { UsageStatsItem, BuiltinTemplate } from '@/lib/api';

interface TemplateCardGridProps {
  templates: AdminTemplateListItem[];
  categories: TemplateCategory[];
  backendUrl?: string;
  usage?: Record<string, Pick<UsageStatsItem, 'useShoot' | 'openDetail'>>;
  builtinTemplates?: BuiltinTemplate[];
}

export function TemplateCardGrid({
  templates,
  categories,
  backendUrl = 'http://localhost:3000',
  usage = {},
  builtinTemplates = [],
}: TemplateCardGridProps) {
  const router = useRouter();
  const { toast } = useToast();
  const [query, setQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState<string>('all');
  // 每张卡片的加载状态（Record<模板id, 是否处理中>），避免 React 18 中 async
  // + useTransition 包裹导致异步渲染被丢弃、点击"无反应"的问题。
  const [pendingMap, setPendingMap] = useState<Record<string, boolean>>({});
  const [deleteTarget, setDeleteTarget] = useState<AdminTemplateListItem | null>(null);
  const [deletePending, setDeletePending] = useState(false);

  // 一级分类（题材），用于顶部筛选
  const typeCategories = useMemo(
    () => categories.filter((c) => c.level === 1),
    [categories],
  );

  const stats = useMemo(() => {
    const total = templates.length;
    const active = templates.filter((t) => t.isActive).length;
    const free = templates.filter((t) => !t.price || t.price <= 0).length;
    return { total, active, free };
  }, [templates]);

  const filtered = useMemo(() => {
    const kw = query.trim().toLowerCase();
    return templates.filter((t) => {
      if (activeCategory !== 'all' && t.category !== activeCategory) return false;
      if (!kw) return true;
      return (
        t.name.toLowerCase().includes(kw) ||
        t.id.toLowerCase().includes(kw) ||
        (t.categoryName || '').toLowerCase().includes(kw)
      );
    });
  }, [templates, query, activeCategory]);

  // 内置模板（排除已在主网格展示的后端模板 id，避免重复）
  const builtinRecords = useMemo(() => {
    const backendIds = new Set(templates.map((t) => t.id));
    return builtinTemplates.filter((b) => !backendIds.has(b.id));
  }, [builtinTemplates, templates]);

  // 上架/下架切换：用显式 pending 状态驱动，保证点击立刻有反馈，且处理中禁用避免重复点击
  const handleToggle = useCallback(
    async (t: AdminTemplateListItem) => {
      if (pendingMap[t.id]) return; // 正在处理，忽略重复点击
      setPendingMap((p) => ({ ...p, [t.id]: true }));
      let result;
      try {
        result = await toggleTemplateActive(t.id);
      } finally {
        setPendingMap((p) => ({ ...p, [t.id]: false }));
      }
      if (result?.error) {
        toast({
          variant: 'destructive',
          title: '操作失败',
          description: result.error,
        });
      } else {
        toast({
          title: result.isActive ? '已上架' : '已下架',
          description: `「${t.name}」${result.isActive ? '已上架' : '已下架'}`,
        });
        router.refresh();
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [pendingMap],
  );

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) return;
    const id = deleteTarget.id;
    setDeletePending(true);
    let result;
    try {
      result = await deleteTemplate(id);
    } finally {
      setDeletePending(false);
    }
    if (result?.error) {
      toast({
        variant: 'destructive',
        title: '删除失败',
        description: result.error,
      });
    } else {
      toast({ title: '已删除', description: `「${deleteTarget.name}」已删除` });
      setDeleteTarget(null);
      router.refresh();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [deleteTarget]);

  return (
    <div className="space-y-5">
      {/* 顶部工具栏：统计 + 搜索 + 新建 */}
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
          <Badge variant="secondary">
            <span className="font-medium text-foreground">{stats.total}</span>
            <span className="ml-1.5">全部</span>
          </Badge>
          <Badge variant="secondary">
            <span className="font-medium text-foreground">{stats.active}</span>
            <span className="ml-1.5">上架中</span>
          </Badge>
          <Badge variant="secondary">
            <span className="font-medium text-foreground">{stats.free}</span>
            <span className="ml-1.5">免费</span>
          </Badge>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative flex-1 max-w-sm">
            <MagnifyingGlass
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
            />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="搜索模板名称 / ID / 分类…"
              className="pl-9"
            />
          </div>
          <Button asChild>
            <Link href="/dashboard/templates/new">
              <Plus size={16} className="mr-1" /> 新建模板
            </Link>
          </Button>
        </div>
      </div>

      {/* 一级分类筛选标签 */}
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => setActiveCategory('all')}
          className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
            activeCategory === 'all'
              ? 'bg-primary text-primary-foreground'
              : 'bg-muted text-muted-foreground hover:bg-muted/70'
          }`}
        >
          全部
        </button>
        {typeCategories.map((c) => (
          <button
            key={c.key}
            type="button"
            onClick={() => setActiveCategory(c.key)}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              activeCategory === c.key
                ? 'bg-primary text-primary-foreground'
                : 'bg-muted text-muted-foreground hover:bg-muted/70'
            }`}
          >
            {c.name}
          </button>
        ))}
      </div>

      {/* 卡片网格 */}
      {filtered.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border bg-card py-16 text-center text-muted-foreground">
          {query || activeCategory !== 'all'
            ? '没有匹配的模板，换个关键词或分类试试'
            : '暂无模板，点击右上角「新建模板」创建'}
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-4">
          {filtered.map((t) => {
          const cover = toAssetUrl(t.coverUrl, backendUrl);
          const toggling = !!pendingMap[t.id];
          const u = usage[t.id];
            return (
              <div
                key={t.id}
                className="group flex flex-col overflow-hidden rounded-lg border border-border bg-card shadow-sm transition-shadow hover:shadow-md"
              >
                {/* 封面 */}
                <Link
                  href={`/dashboard/templates/${t.id}`}
                  className="relative block aspect-[3/4] w-full overflow-hidden bg-muted"
                >
                  {cover ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={cover}
                      alt={t.name}
                      className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                    />
                  ) : (
                    <span className="flex h-full w-full items-center justify-center text-xs text-muted-foreground">
                      无封面
                    </span>
                  )}
                  {/* 价格角标 */}
                  <span className="absolute right-2 top-2 rounded-full bg-black/60 px-2 py-0.5 text-[11px] font-medium text-white backdrop-blur">
                    {t.price > 0 ? `${t.price} 积分` : '免费'}
                  </span>
                  {/* 上架状态角标 */}
                  <span
                    className={`absolute left-2 top-2 rounded-full px-2 py-0.5 text-[11px] font-medium backdrop-blur ${
                      t.isActive
                        ? 'bg-emerald-500/85 text-white'
                        : 'bg-zinc-500/85 text-white'
                    }`}
                  >
                    {t.isActive ? '上架' : '下架'}
                  </span>
                </Link>

                {/* 信息区 */}
                <div className="flex flex-1 flex-col gap-2 p-3">
                  <div className="min-w-0">
                    <Link
                      href={`/dashboard/templates/${t.id}`}
                      className="block truncate text-sm font-medium text-foreground hover:text-primary"
                    >
                      {t.name}
                    </Link>
                    <p className="truncate text-xs text-muted-foreground">
                      {t.id} · 更新于 {formatUnixTime(t.updatedAt)}
                    </p>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <Badge variant="outline" className="text-[11px]">
                      {t.categoryName || t.category}
                    </Badge>
                    {/* 悬停显示排序 */}
                    <span className="ml-auto text-[11px] text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100">
                      序号 {t.sortOrder}
                    </span>
                  </div>

                  {/* 使用次数（始终显示，无数据时为 0） */}
                  <div className="flex items-center gap-1.5 text-[11px] text-muted-foreground">
                    <span>{t.price > 0 ? `${t.price} 积分` : '免费'}</span>
                    <span className="ml-auto flex items-center gap-2 tabular-nums">
                      <span>拍摄 {u?.useShoot ?? 0}</span>
                      <span>查看 {u?.openDetail ?? 0}</span>
                    </span>
                  </div>

                  {/* 操作区 */}
                  <div className="mt-auto flex items-center justify-between gap-2 border-t border-border/60 pt-2">
                    <div className="flex items-center gap-1.5">
                      <Switch
                        checked={t.isActive}
                        disabled={toggling}
                        onCheckedChange={() => handleToggle(t)}
                        aria-label="切换上架状态"
                      />
                      <span className="text-xs text-muted-foreground">
                        {t.isActive ? '上架' : '下架'}
                      </span>
                    </div>
                    <div className="flex items-center gap-0.5">
                      <Button asChild size="sm" variant="ghost" className="h-8 w-8 px-0">
                        <Link href={`/dashboard/templates/${t.id}`}>
                          <PencilSimple size={15} />
                          <span className="sr-only">编辑</span>
                        </Link>
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-8 w-8 px-0 text-destructive hover:text-destructive"
                        onClick={() => setDeleteTarget(t)}
                      >
                        <Trash size={15} />
                        <span className="sr-only">删除</span>
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* 内置模板分区（App 内嵌，后端只读展示名称与次数） */}
      <div className="space-y-3">
        <div className="flex items-center gap-2 pt-2">
          <h2 className="text-sm font-semibold text-foreground">内置模板</h2>
          <Badge variant="secondary" className="text-xs">
            {builtinRecords.length}
          </Badge>
        </div>
        {builtinRecords.length === 0 ? (
          <div className="rounded-lg border border-dashed border-border bg-card py-10 text-center text-sm text-muted-foreground">
            暂未获取到内置模板记录，App 同步后展示
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-4">
            {builtinRecords.map((b) => {
              const u = usage[b.id];
              return (
                <div
                  key={b.id}
                  className="flex flex-col overflow-hidden rounded-lg border border-border bg-card shadow-sm"
                >
                  <div className="relative aspect-[3/4] w-full bg-muted">
                    <span className="flex h-full w-full items-center justify-center text-xs text-muted-foreground">
                      无封面
                    </span>
                    <span className="absolute left-2 top-2 rounded-full bg-indigo-500/85 px-2 py-0.5 text-[11px] font-medium text-white backdrop-blur">
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
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* 删除确认弹窗 */}
      <Dialog open={deleteTarget !== null} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>删除模板</DialogTitle>
            <DialogDescription>
              确定要删除模板「{deleteTarget?.name}」吗？删除后不可恢复。
              <span className="mt-1 block text-xs text-muted-foreground">{deleteTarget?.id}</span>
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setDeleteTarget(null)}
              disabled={deletePending}
            >
              取消
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={deletePending}
            >
              {deletePending ? '删除中…' : '确认删除'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default TemplateCardGrid;