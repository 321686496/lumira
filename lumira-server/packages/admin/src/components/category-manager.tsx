// src/components/category-manager.tsx
'use client';

import { useState, useTransition, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
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
  Plus, PencilSimple, Trash, Lock, CaretDown, CaretRight,
  MagnifyingGlass, ArrowUp, ArrowDown, FolderPlus, ImageSquare,
} from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';
import { useToast } from '@/hooks/use-toast';
import { FileUpload } from '@/components/ui/file-upload';
import {
  createCategory, updateCategory, deleteCategory, toggleCategoryActive,
} from '@/actions/categories';
import { buildCategoryTree } from '@/lib/category-tree';
import { toAssetUrl } from '@/lib/asset-url';
import type { TemplateCategory, TemplateCategoryTreeNode } from '@/types/admin';

interface FlatRow {
  node: TemplateCategoryTreeNode;
  depth: number;
  hasChildren: boolean;
  /** 树形连接线：guides[i] 表示在深度 i 处需要绘制垂直引导线（该节点存在跨行的祖先兄弟） */
  guides: boolean[];
}

/** 树的最大递归深度（三级分类 + 余量）。超过即截断，防止异常数据导致栈溢出。 */
const MAX_TREE_DEPTH = 8;

/** 将树扁平化为带缩进层级的行，跳过折叠节点的子级，并计算树形连接线信息。 */
function flattenTree(
  tree: TemplateCategoryTreeNode[],
  collapsedKeys: Set<string>,
): FlatRow[] {
  const rows: FlatRow[] = [];
  const walk = (nodes: TemplateCategoryTreeNode[], depth: number, guides: boolean[]) => {
    if (depth > MAX_TREE_DEPTH) return;
    nodes.forEach((n, idx) => {
      const hasChildren = n.children.length > 0;
      const isLast = idx === nodes.length - 1;
      rows.push({ node: n, depth, hasChildren, guides });
      if (hasChildren && !collapsedKeys.has(n.key)) {
        // 子级的引导线 = 当前引导线 + 当前节点是否还有后续兄弟
        walk(n.children, depth + 1, [...guides, !isLast]);
      }
    });
  };
  walk(tree, 0, []);
  return rows;
}

const LEVEL_LABEL: Record<number, string> = {
  1: '一级（题材）',
  2: '二级（大风格）',
  3: '三级（子风格）',
  4: '四级（方法）',
};

/** 层级徽标样式（与后台 Morandi 主题色对齐：蓝灰 / 鼠尾草 / 陶土 / 赭石） */
const LEVEL_BADGE: Record<number, { label: string; className: string }> = {
  1: { label: '一级', className: 'bg-primary/10 text-primary border-primary/20' },
  2: { label: '二级', className: 'bg-success/10 text-success border-success/20' },
  3: { label: '三级', className: 'bg-warning/10 text-warning border-warning/20' },
  4: { label: '四级', className: 'bg-accent/10 text-accent border-accent/25' },
};

/** 非一级分类在名称前的层级色点 */
const LEVEL_DOT: Record<number, string> = {
  2: 'bg-success/70',
  3: 'bg-warning/70',
  4: 'bg-accent/70',
};

interface FormState {
  key: string;
  name: string;
  level: 1 | 2 | 3 | 4;
  /** 祖先路径（root → 父分类），用于通用逐级选父：path 长度 = level - 1 */
  path: string[];
  parentKey: string;       // 实际父分类 key（一级为空）
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  key: '',
  name: '',
  level: 1,
  path: [],
  parentKey: '',
  sortOrder: 0,
  isActive: true,
};

export function CategoryManager({
  categories,
  backendUrl = 'http://localhost:3000',
}: {
  categories: TemplateCategory[];
  backendUrl?: string;
}) {
  const router = useRouter();
  const { toast } = useToast();

  const tree = useMemo(() => buildCategoryTree(categories), [categories]);

  const [collapsedKeys, setCollapsedKeys] = useState<Set<string>>(new Set());

  // 递归收集所有有子级的节点 key（含二/三/四级），供「全部折叠/展开」与全折叠判断使用
  const allBranchKeys = useMemo(() => {
    const keys: string[] = [];
    const collect = (nodes: TemplateCategoryTreeNode[]) => {
      for (const n of nodes) {
        if (n.children.length > 0) {
          keys.push(n.key);
          collect(n.children);
        }
      }
    };
    collect(tree);
    return keys;
  }, [tree]);

  const allCollapsed = useMemo(
    () => allBranchKeys.every((key) => collapsedKeys.has(key)),
    [allBranchKeys, collapsedKeys],
  );

  const flatRows = useMemo(() => flattenTree(tree, collapsedKeys), [tree, collapsedKeys]);

  // 层级统计（用于工具栏概览）
  const levelCounts = useMemo(() => {
    const counts = { 1: 0, 2: 0, 3: 0, 4: 0 };
    for (const c of categories) {
      if (c.level >= 1 && c.level <= 4) counts[c.level as 1 | 2 | 3 | 4] += 1;
    }
    return counts;
  }, [categories]);

  // 搜索：按名称或 key 过滤；搜索时自动展开全部子级
  const [search, setSearch] = useState('');
  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase();
    const rows = q ? flattenTree(tree, new Set()) : flatRows;
    if (!q) return rows;
    return rows.filter(
      ({ node }) =>
        node.name.toLowerCase().includes(q) || node.key.toLowerCase().includes(q),
    );
  }, [tree, flatRows, search]);
  const hasSearch = search.trim().length > 0;

  // 通用逐级选父：path 第 index 位（level=index+1）的可选项
  // index=0 选题材（根）；其后第 i 位可选项 = 上一级选中项的直接子级
  const getPathOptions = (index: number) => {
    const targetLevel = index + 1;
    const parentKey = index === 0 ? null : form.path[index - 1] ?? null;
    return categories
      .filter((c) => c.level === targetLevel && (parentKey === null ? c.parentKey === null : c.parentKey === parentKey))
      .sort((a, b) => a.sortOrder - b.sortOrder || a.key.localeCompare(b.key));
  };

  // 计算分类的祖先 key 链（root → 自身），用于重建逐级选父路径
  const getAncestorKeys = (cat: TemplateCategory): string[] => {
    const chain: string[] = [];
    let cur: TemplateCategory | undefined = cat;
    const guard = new Set<string>();
    while (cur && !guard.has(cur.key)) {
      guard.add(cur.key);
      chain.unshift(cur.key);
      if (!cur.parentKey) break;
      cur = categories.find((c) => c.key === cur!.parentKey && c.level === cur!.level - 1);
    }
    return chain;
  };

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmitTransition] = useTransition();
  const [pendingToggleKey, setPendingToggleKey] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [confirmDelete, setConfirmDelete] = useState<{ key: string; parentKey: string | null } | null>(null);
  const [deletingKey, setDeletingKey] = useState<string | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();
  const [reorderKey, setReorderKey] = useState<string | null>(null);
  const [reorderPending, startReorderTransition] = useTransition();

  // 打开新建对话框
  const openCreate = () => {
    setEditingKey(null);
    setForm(EMPTY_FORM);
    setIconFile(null);
    setError(null);
    setDialogOpen(true);
  };

  // 快速添加子分类：预填层级与祖先路径
  const openCreateChild = (parent: TemplateCategory) => {
    if (parent.level >= 4) return;
    const level = (parent.level + 1) as 1 | 2 | 3 | 4;
    setEditingKey(null);
    setForm({
      key: '',
      name: '',
      level,
      path: getAncestorKeys(parent),
      parentKey: parent.key,
      sortOrder: 0,
      isActive: true,
    });
    setIconFile(null);
    setError(null);
    setDialogOpen(true);
  };

  // 打开编辑对话框
  const openEdit = (cat: TemplateCategory) => {
    setEditingKey(cat.key);
    setForm({
      key: cat.key,
      name: cat.name,
      level: cat.level as 1 | 2 | 3 | 4,
      path: cat.level > 1 ? getAncestorKeys(cat).slice(0, -1) : [],
      parentKey: cat.parentKey ?? '',
      sortOrder: cat.sortOrder,
      isActive: cat.isActive,
    });
    setIconFile(null);
    setError(null);
    setDialogOpen(true);
  };

  // 关闭对话框时清理
  useEffect(() => {
    if (!dialogOpen) {
      const t = setTimeout(() => {
        setEditingKey(null);
        setIconFile(null);
        setError(null);
      }, 200);
      return () => clearTimeout(t);
    }
    return undefined;
  }, [dialogOpen]);

  // 切换层级时重置祖先路径与父分类
  const handleLevelChange = (level: 1 | 2 | 3 | 4) => {
    setForm({ ...form, level, path: [], parentKey: '' });
  };

  // 逐级选父：选择 path 第 index 位（level=index+1），清空其后路径
  const handlePathChange = (index: number, key: string) => {
    const path = [...form.path.slice(0, index), key];
    setForm({ ...form, path, parentKey: path[path.length - 1] ?? '' });
  };

  // 新建场景下的创建位置提示（面包屑）
  const getCreateContext = (f: FormState): string | null => {
    if (f.level === 1) return `将创建一级分类（题材）`;
    const parent = categories.find((c) => c.key === f.parentKey);
    if (!parent) {
      return `将创建${LEVEL_LABEL[f.level]}，请先选择父分类`;
    }
    const crumbs = f.path.map((key) => categories.find((c) => c.key === key)?.name ?? key);
    return `将创建「${crumbs.join(' › ')}」下的${LEVEL_LABEL[f.level]}`;
  };

  const handleSubmit = async () => {
    setError(null);
    if (!editingKey && !form.key.trim()) {
      setError('请填写分类 key');
      return;
    }
    if (!form.name.trim()) {
      setError('请填写分类名称');
      return;
    }
    if (form.level !== 1 && !form.parentKey) {
      setError('请选择父分类');
      return;
    }

    const meta: Record<string, unknown> = {
      name: form.name.trim(),
      level: form.level,
      parentKey: form.level === 1 ? null : form.parentKey,
      sortOrder: Number(form.sortOrder) || 0,
      isActive: form.isActive,
    };
    if (!editingKey) {
      meta.key = form.key.trim();
    }

    const fd = new FormData();
    fd.set('meta', JSON.stringify(meta));
    // 一二级分类支持上传图标（作为封面/图标展示）
    if (iconFile && form.level <= 2) fd.set('icon', iconFile);

    startSubmitTransition(async () => {
      // 二三级分类需传父分类 key 消歧（同名 key 可跨父级重复）
      const updateParentKey = form.level === 1 ? null : form.parentKey;
      const result = editingKey
        ? await updateCategory(editingKey, fd, updateParentKey)
        : await createCategory(fd);
      if (result?.error) {
        setError(result.error);
        return;
      }
      toast({
        title: editingKey ? '已更新' : '已创建',
        description: `分类「${form.name}」${editingKey ? '已更新' : '已创建'}`,
      });
      setDialogOpen(false);
      router.refresh();
    });
  };

  // 点击删除：先校验是否存在子分类，再弹出确认框
  const requestDelete = (cat: TemplateCategory) => {
    const hasChildren = categories.some((c) => c.parentKey === cat.key);
    if (hasChildren) {
      toast({
        variant: 'destructive',
        title: '无法删除',
        description: '该分类下存在子分类，请先删除子分类',
      });
      return;
    }
    setConfirmDelete({ key: cat.key, parentKey: cat.parentKey });
  };

  const handleDelete = async (target: { key: string; parentKey: string | null }) => {
    setDeletingKey(target.key);
    startDeleteTransition(async () => {
      const result = await deleteCategory(target.key, target.parentKey);
      setDeletingKey(null);
      if (result?.error) {
        toast({
          variant: 'destructive',
          title: '删除失败',
          description: result.error,
        });
      } else {
        toast({ title: '已删除', description: '分类已删除' });
        setConfirmDelete(null);
        router.refresh();
      }
    });
  };

  // 快速排序：与相邻兄弟节点交换 sortOrder
  const handleReorder = (cat: TemplateCategory, dir: -1 | 1) => {
    const siblings = categories
      .filter((x) => x.parentKey === cat.parentKey && x.level === cat.level)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.key.localeCompare(b.key));
    const idx = siblings.findIndex((s) => s.key === cat.key);
    const target = siblings[idx + dir];
    if (idx < 0 || !target) return;

    setReorderKey(cat.key);
    startReorderTransition(async () => {
      const fdA = new FormData();
      fdA.set('meta', JSON.stringify({ sortOrder: target.sortOrder }));
      const fdB = new FormData();
      fdB.set('meta', JSON.stringify({ sortOrder: cat.sortOrder }));
      const results = await Promise.all([
        updateCategory(cat.key, fdA, cat.parentKey),
        updateCategory(target.key, fdB, target.parentKey),
      ]);
      setReorderKey(null);
      const err = results.find((r) => r?.error);
      if (err) {
        toast({ variant: 'destructive', title: '排序失败', description: err.error });
      } else {
        router.refresh();
      }
    });
  };

  const toggleCollapse = (key: string) => {
    setCollapsedKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const toggleAll = () => {
    if (allCollapsed) {
      setCollapsedKeys(new Set());
    } else {
      // 收集所有层级（一/二/三/四）中有子级的节点，全部折叠
      setCollapsedKeys(new Set(allBranchKeys));
    }
  };

  // 按 (key, parentKey) 精确匹配分类（同名 key 可跨父级/层级重复，需复合定位）
  const findCategory = (key: string, parentKey: string | null) =>
    categories.find((c) => c.key === key && (c.parentKey ?? null) === parentKey);

  const editingCat = editingKey
    ? findCategory(editingKey, form.level === 1 ? null : form.parentKey)
    : null;
  const confirmCat = confirmDelete
    ? findCategory(confirmDelete.key, confirmDelete.parentKey)
    : null;
  const reorderDisabled = (key: string) => reorderPending && reorderKey === key;

  // 计算某分类在兄弟节点中的位置，用于禁用边界排序按钮
  const reorderBoundary = (cat: TemplateCategory) => {
    const siblings = categories
      .filter((x) => x.parentKey === cat.parentKey && x.level === cat.level)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.key.localeCompare(b.key));
    const idx = siblings.findIndex((s) => s.key === cat.key);
    return { canUp: idx > 0, canDown: idx >= 0 && idx < siblings.length - 1 };
  };

  return (
    <div className="space-y-5">
      {/* 页头：标题 + 搜索 + 操作 */}
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-baseline gap-2.5">
            <h2 className="text-lg font-semibold tracking-tight text-foreground">分类管理</h2>
            <span className="hidden text-xs text-muted-foreground md:inline">
              题材 → 风格 → 方式
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
                placeholder="搜索名称或 key"
                className="h-9 w-48 pl-8 sm:w-56"
              />
            </div>
            <Button variant="outline" size="sm" onClick={toggleAll} disabled={tree.length === 0}>
              {allCollapsed ? '全部展开' : '全部折叠'}
            </Button>
            <Button size="sm" onClick={openCreate}>
              <Plus size={16} className="mr-1" /> 新建分类
            </Button>
          </div>
        </div>

        {/* 层级统计胶囊 */}
        <div className="flex flex-wrap items-center gap-2">
          {[
            { label: '一级 · 题材', count: levelCounts[1], dot: 'bg-primary' },
            { label: '二级 · 大风格', count: levelCounts[2], dot: 'bg-success' },
            { label: '三级 · 子风格', count: levelCounts[3], dot: 'bg-warning' },
            { label: '四级 · 方法', count: levelCounts[4], dot: 'bg-accent' },
          ].map((s) => (
            <div
              key={s.label}
              className="flex items-center gap-2 rounded-full border border-border bg-card px-3.5 py-1.5"
            >
              <span className={cn('h-2 w-2 rounded-full', s.dot)} />
              <span className="text-sm font-semibold tabular-nums leading-none">
                {s.count}
              </span>
              <span className="text-xs text-muted-foreground">{s.label}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card shadow-sm">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/40 hover:bg-muted/40">
              <TableHead className="w-12"></TableHead>
              <TableHead className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                名称
              </TableHead>
              <TableHead className="w-24 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                层级
              </TableHead>
              <TableHead className="w-28 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                排序
              </TableHead>
              <TableHead className="w-24 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                类型
              </TableHead>
              <TableHead className="w-28 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                状态
              </TableHead>
              <TableHead className="w-32 text-right text-xs font-medium uppercase tracking-wide text-muted-foreground">
                操作
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredRows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="py-16 text-center">
                  <div className="mx-auto flex max-w-sm flex-col items-center gap-2">
                    <ImageSquare size={28} className="text-muted-foreground/40" />
                    <p className="text-sm text-muted-foreground">
                      {hasSearch
                        ? `未找到匹配「${search.trim()}」的分类`
                        : '暂无分类，点击右上角「新建分类」创建'}
                    </p>
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              filteredRows.map((row) => {
                const { node: c, depth, hasChildren, guides } = row;
                const icon = toAssetUrl(c.iconUrl, backendUrl);
                const isCollapsed = collapsedKeys.has(c.key);
                const levelBadge = LEVEL_BADGE[c.level as 1 | 2 | 3 | 4];
                const dot = LEVEL_DOT[c.level as 2 | 3 | 4];
                const { canUp, canDown } = reorderBoundary(c);
                return (
                  <TableRow key={`${c.parentKey ?? 'root'}|${c.key}`} className="group">
                    {/* 树形控制（连接线 + 缩进 + 折叠） */}
                    <TableCell className="py-2.5">
                      <div className="flex h-9 items-center">
                        {guides.map((show, i) => (
                          <span key={i} className="relative h-full w-5 shrink-0">
                            {show && (
                              <span className="absolute left-1/2 top-0 h-full w-px -translate-x-1/2 bg-border" />
                            )}
                          </span>
                        ))}
                        {depth > 0 && (
                          <span className="relative h-full w-5 shrink-0">
                            <span className="absolute left-0 top-1/2 h-px w-full bg-border" />
                          </span>
                        )}
                        {hasChildren ? (
                          <button
                            type="button"
                            onClick={() => toggleCollapse(c.key)}
                            className="inline-flex h-6 w-6 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                            title={isCollapsed ? '展开' : '折叠'}
                          >
                            {isCollapsed ? <CaretRight size={14} /> : <CaretDown size={14} />}
                          </button>
                        ) : (
                          <span className="w-6 shrink-0" />
                        )}
                      </div>
                    </TableCell>

                    {/* 名称：图标 / 层级色点 + 名称 + key */}
                    <TableCell className="py-2.5">
                      <div className="flex items-center gap-3">
                        {c.level <= 2 ? (
                          <div className="h-10 w-10 shrink-0 overflow-hidden rounded-lg border border-input bg-muted">
                            {icon ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img
                                src={icon}
                                alt={c.name}
                                className="h-full w-full object-cover"
                              />
                            ) : (
                              <span className="flex h-full w-full items-center justify-center">
                                <ImageSquare size={16} className="text-muted-foreground/60" />
                              </span>
                            )}
                          </div>
                        ) : (
                          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-border bg-background">
                            <span className={cn('h-2 w-2 rounded-full', dot)} />
                          </div>
                        )}
                        <div className="min-w-0">
                          <div className="flex items-center gap-2">
                            <span className="truncate text-sm font-medium text-foreground">
                              {c.name}
                            </span>
                          </div>
                          <code className="block max-w-[220px] truncate font-mono text-xs text-muted-foreground/70">
                            {c.key}
                          </code>
                        </div>
                      </div>
                    </TableCell>

                    {/* 层级徽标 */}
                    <TableCell className="py-2.5">
                      <span
                        className={cn(
                          'inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium',
                          levelBadge.className,
                        )}
                      >
                        {levelBadge.label}
                      </span>
                    </TableCell>

                    {/* 排序（数字 + 上移/下移） */}
                    <TableCell className="py-2.5">
                      <div className="flex items-center gap-2">
                        <span className="w-5 text-center text-sm font-medium tabular-nums text-muted-foreground">
                          {c.sortOrder}
                        </span>
                        <div className="flex flex-col gap-px">
                          <button
                            type="button"
                            title={canUp ? '上移' : '已是第一个'}
                            disabled={reorderDisabled(c.key) || !canUp}
                            onClick={() => handleReorder(c, -1)}
                            className="inline-flex h-4 w-6 items-center justify-center rounded-sm text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:pointer-events-none disabled:opacity-35"
                          >
                            <ArrowUp size={11} />
                          </button>
                          <button
                            type="button"
                            title={canDown ? '下移' : '已是最后一个'}
                            disabled={reorderDisabled(c.key) || !canDown}
                            onClick={() => handleReorder(c, 1)}
                            className="inline-flex h-4 w-6 items-center justify-center rounded-sm text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:pointer-events-none disabled:opacity-35"
                          >
                            <ArrowDown size={11} />
                          </button>
                        </div>
                      </div>
                    </TableCell>

                    {/* 类型 */}
                    <TableCell className="py-2.5">
                      {c.isSystem ? (
                        <Badge variant="secondary">
                          <Lock size={10} className="mr-1" /> 系统
                        </Badge>
                      ) : (
                        <Badge variant="outline">自定义</Badge>
                      )}
                    </TableCell>

                    {/* 状态 */}
                    <TableCell className="py-2.5">
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={c.isActive}
                          disabled={togglePending && pendingToggleKey === c.key}
                          onCheckedChange={() => {
                            setPendingToggleKey(c.key);
                            startToggleTransition(async () => {
                              const result = await toggleCategoryActive(c.key, c.parentKey);
                              setPendingToggleKey(null);
                              if (result?.error) {
                                toast({
                                  variant: 'destructive',
                                  title: '操作失败',
                                  description: result.error,
                                });
                              }
                            });
                          }}
                        />
                        <span className="text-xs text-muted-foreground">
                          {c.isActive ? '显示' : '隐藏'}
                        </span>
                      </div>
                    </TableCell>

                    {/* 操作（图标按钮） */}
                    <TableCell className="py-2.5 text-right">
                      <div className="flex items-center justify-end gap-0.5">
                        {c.level < 4 && (
                          <button
                            type="button"
                            title={`在「${c.name}」下添加子分类`}
                            onClick={() => openCreateChild(c)}
                            className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                          >
                            <FolderPlus size={15} />
                          </button>
                        )}
                        <button
                          type="button"
                          title="编辑"
                          onClick={() => openEdit(c)}
                          className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                        >
                          <PencilSimple size={15} />
                        </button>
                        {c.isSystem ? (
                          <span
                            title="系统分类不可删除"
                            className="inline-flex h-8 w-8 cursor-not-allowed items-center justify-center rounded-md text-muted-foreground/35"
                          >
                            <Lock size={15} />
                          </span>
                        ) : (
                          <button
                            type="button"
                            title="删除"
                            onClick={() => requestDelete(c)}
                            className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                          >
                            <Trash size={15} />
                          </button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>

      {/* 新建 / 编辑对话框 */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-left">
              {editingKey ? '编辑分类' : '新建分类'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingKey
                ? `修改分类「${editingKey}」的属性。系统分类的 key 不可更改。`
                : '分类支持四级树形结构：一级（题材）→ 二级（大风格）→ 三级（子风格）→ 四级（方法）。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            {/* 新建时的创建位置提示 */}
            {!editingKey && (
              <div className="rounded-md border-l-2 border-primary bg-muted/40 px-3 py-2 text-sm text-muted-foreground">
                {getCreateContext(form)}
              </div>
            )}

            {/* 层级选择 */}
            <div className="space-y-2">
              <Label>层级 *</Label>
              <Select
                value={String(form.level)}
                onValueChange={(v) => handleLevelChange(Number(v) as 1 | 2 | 3 | 4)}
                disabled={Boolean(editingKey)}
              >
                <SelectTrigger><SelectValue placeholder="选择层级" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="1">{LEVEL_LABEL[1]}</SelectItem>
                  <SelectItem value="2">{LEVEL_LABEL[2]}</SelectItem>
                  <SelectItem value="3">{LEVEL_LABEL[3]}</SelectItem>
                  <SelectItem value="4">{LEVEL_LABEL[4]}</SelectItem>
                </SelectContent>
              </Select>
              {editingKey && (
                <p className="text-xs text-muted-foreground">已有分类的层级不可修改。</p>
              )}
            </div>

            {/* 通用逐级选父：按层级依次选择祖先，最后一个即父分类 */}
            {form.level !== 1 && (
              <div className="space-y-3">
                {Array.from({ length: form.level - 1 }, (_, i) => {
                  const targetLevel = i + 1;
                  const options = getPathOptions(i);
                  const selected = form.path[i] ?? '';
                  const parentReady = i === 0 ? true : Boolean(form.path[i - 1]);
                  return (
                    <div key={targetLevel} className="space-y-2">
                      <Label>
                        所属{LEVEL_LABEL[targetLevel]}
                        {targetLevel === form.level - 1 && (
                          <span className="text-xs text-muted-foreground">（父分类）</span>
                        )}{' '}*
                      </Label>
                      <Select
                        value={selected}
                        onValueChange={(v) => handlePathChange(i, v)}
                        disabled={Boolean(editingKey) || !parentReady}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder={`选择${LEVEL_LABEL[targetLevel]}`} />
                        </SelectTrigger>
                        <SelectContent>
                          {options.map((c) => (
                            <SelectItem key={`${c.parentKey ?? 'root'}|${c.key}`} value={c.key}>
                              {c.name} ({c.key})
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      {!parentReady && (
                        <p className="text-xs text-muted-foreground">请先选择上一级分类。</p>
                      )}
                    </div>
                  );
                })}
              </div>
            )}

            <div className="space-y-2">
              <Label htmlFor="cat-key">Key *</Label>
              <Input
                id="cat-key"
                value={form.key}
                onChange={(e) => setForm({ ...form, key: e.target.value })}
                placeholder="如：portrait / japanese / normal"
                disabled={Boolean(editingKey)}
                className="font-mono"
              />
              {editingKey ? (
                <p className="text-xs text-muted-foreground">
                  {editingCat?.isSystem
                    ? '系统分类的 key 不可修改。'
                    : '已有分类的 key 不可修改。'}
                </p>
              ) : (
                <p className="text-xs text-muted-foreground">
                  唯一标识，建议使用小写英文 + 连字符。一级与 Flutter 内置 7 类对齐（portrait / landscape / food / street / night / macro / still-life）。
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="cat-name">显示名称 *</Label>
              <Input
                id="cat-name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="如：人像 / 日系 / 他拍"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="cat-sort">排序</Label>
                <Input
                  id="cat-sort"
                  type="number"
                  value={form.sortOrder}
                  onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                />
              </div>
              <div className="space-y-2">
                <Label>是否显示</Label>
                <div className="flex h-10 items-center gap-2">
                  <Switch
                    checked={form.isActive}
                    onCheckedChange={(checked) => setForm({ ...form, isActive: checked })}
                  />
                  <span className="text-sm text-muted-foreground">
                    {form.isActive ? '显示' : '隐藏'}
                  </span>
                </div>
              </div>
            </div>

            {/* 图标上传仅一二级分类显示（二级封面） */}
            {form.level <= 2 && (
              <FileUpload
                label="分类图标（可选）"
                accept="image/*"
                maxSize={5 * 1024 * 1024}
                value={iconFile}
                onChange={setIconFile}
                hint="建议 5MB 以内的 png/svg/jpg；一二级分类的图标会作为封面展示，为空时使用默认占位。"
                previewUrl={
                  editingKey
                    ? toAssetUrl(editingCat?.iconUrl, backendUrl) || undefined
                    : undefined
                }
              />
            )}
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
              {submitPending ? '保存中…' : editingKey ? '保存' : '创建'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 删除确认对话框 */}
      <Dialog
        open={confirmDelete !== null}
        onOpenChange={(open) => !open && setConfirmDelete(null)}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-left">删除分类</DialogTitle>
            <DialogDescription className="text-left">
              确定要删除分类「{confirmCat?.name}」({confirmCat?.key}) 吗？此操作不可撤销，
              引用该分类的模板需重新归类。
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => setConfirmDelete(null)}
              disabled={deletePending && deletingKey === confirmDelete?.key}
            >
              取消
            </Button>
            <Button
              variant="destructive"
              disabled={deletePending && deletingKey === confirmDelete?.key}
              onClick={() => confirmDelete && handleDelete(confirmDelete)}
            >
              {deletePending && deletingKey === confirmDelete?.key ? '删除中…' : '确认删除'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default CategoryManager;
