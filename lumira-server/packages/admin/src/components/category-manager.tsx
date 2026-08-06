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
} from '@phosphor-icons/react/dist/ssr';
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
}

/** 树的最大递归深度（三级分类 + 余量）。超过即截断，防止异常数据导致栈溢出。 */
const MAX_TREE_DEPTH = 8;

/** 将树扁平化为带缩进层级的行，跳过折叠节点的子级。 */
function flattenTree(
  tree: TemplateCategoryTreeNode[],
  collapsedKeys: Set<string>,
): FlatRow[] {
  const rows: FlatRow[] = [];
  const walk = (nodes: TemplateCategoryTreeNode[], depth: number) => {
    if (depth > MAX_TREE_DEPTH) return;
    for (const n of nodes) {
      const hasChildren = n.children.length > 0;
      rows.push({ node: n, depth, hasChildren });
      if (hasChildren && !collapsedKeys.has(n.key)) {
        walk(n.children, depth + 1);
      }
    }
  };
  walk(tree, 0);
  return rows;
}

const LEVEL_LABEL: Record<number, string> = {
  1: '一级（题材）',
  2: '二级（风格）',
  3: '三级（方式）',
};

interface FormState {
  key: string;
  name: string;
  level: 1 | 2 | 3;
  parentKey: string;       // 实际父分类 key（一级为空）
  grandparentKey: string;  // 仅三级：用于筛选二级父分类的一级 key
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  key: '',
  name: '',
  level: 1,
  parentKey: '',
  grandparentKey: '',
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
  const allCollapsed = useMemo(
    () => tree.every((n) => n.children.length === 0 || collapsedKeys.has(n.key)),
    [tree, collapsedKeys],
  );

  const flatRows = useMemo(() => flattenTree(tree, collapsedKeys), [tree, collapsedKeys]);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmitTransition] = useTransition();
  const [pendingToggleKey, setPendingToggleKey] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [confirmDeleteKey, setConfirmDeleteKey] = useState<string | null>(null);
  const [deletingKey, setDeletingKey] = useState<string | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();

  // 一级分类列表（用于二三级父分类选择）
  const level1Categories = useMemo(
    () => categories.filter((c) => c.level === 1).sort((a, b) => a.sortOrder - b.sortOrder),
    [categories],
  );
  // 二级分类列表（按 grandparentKey 筛选，用于三级的父分类选择）
  const level2ByGrandparent = useMemo(
    () => categories.filter((c) => c.level === 2 && c.parentKey === form.grandparentKey),
    [categories, form.grandparentKey],
  );

  // 打开新建对话框
  const openCreate = () => {
    setEditingKey(null);
    setForm(EMPTY_FORM);
    setIconFile(null);
    setError(null);
    setDialogOpen(true);
  };

  // 打开编辑对话框
  const openEdit = (cat: TemplateCategory) => {
    setEditingKey(cat.key);
    let grandparentKey = '';
    if (cat.level === 3 && cat.parentKey) {
      const parent = categories.find((c) => c.key === cat.parentKey);
      grandparentKey = parent?.parentKey ?? '';
    }
    setForm({
      key: cat.key,
      name: cat.name,
      level: cat.level as 1 | 2 | 3,
      parentKey: cat.parentKey ?? '',
      grandparentKey,
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

  // 切换层级时重置父分类
  const handleLevelChange = (level: 1 | 2 | 3) => {
    setForm({ ...form, level, parentKey: '', grandparentKey: '' });
  };

  // 三级：切换一级分类时重置二级父分类
  const handleGrandparentChange = (grandparentKey: string) => {
    setForm({ ...form, grandparentKey, parentKey: '' });
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
    if (iconFile && form.level === 1) fd.set('icon', iconFile);

    startSubmitTransition(async () => {
      const result = editingKey
        ? await updateCategory(editingKey, fd)
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

  const handleDelete = async (key: string) => {
    // 客户端预校验：有子分类则禁止删除
    const hasChildren = categories.some((c) => c.parentKey === key);
    if (hasChildren) {
      toast({
        variant: 'destructive',
        title: '无法删除',
        description: '请先删除子分类',
      });
      setConfirmDeleteKey(null);
      return;
    }
    setDeletingKey(key);
    startDeleteTransition(async () => {
      const result = await deleteCategory(key);
      setDeletingKey(null);
      if (result?.error) {
        toast({
          variant: 'destructive',
          title: '删除失败',
          description: result.error,
        });
      } else {
        toast({ title: '已删除', description: '分类已删除' });
        setConfirmDeleteKey(null);
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
      setCollapsedKeys(new Set(tree.filter((n) => n.children.length > 0).map((n) => n.key)));
    }
  };

  const editingCat = editingKey ? categories.find((c) => c.key === editingKey) : null;

  return (
    <div className="space-y-4">
      <div className="flex justify-end gap-2">
        <Button variant="outline" size="sm" onClick={toggleAll} disabled={tree.length === 0}>
          {allCollapsed ? '全部展开' : '全部折叠'}
        </Button>
        <Button onClick={openCreate}>
          <Plus size={16} className="mr-1" /> 新建分类
        </Button>
      </div>

      <div className="rounded-md border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/30 hover:bg-muted/30">
              <TableHead className="w-10"></TableHead>
              <TableHead className="w-16">图标</TableHead>
              <TableHead className="w-40">Key</TableHead>
              <TableHead>名称</TableHead>
              <TableHead className="w-20">层级</TableHead>
              <TableHead className="w-24">排序</TableHead>
              <TableHead className="w-24">类型</TableHead>
              <TableHead className="w-32">状态</TableHead>
              <TableHead className="w-44">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {flatRows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={9} className="text-center text-muted-foreground py-8">
                  暂无分类
                </TableCell>
              </TableRow>
            ) : (
              flatRows.map(({ node: c, depth, hasChildren }) => {
                const icon = toAssetUrl(c.iconUrl, backendUrl);
                const isCollapsed = collapsedKeys.has(c.key);
                return (
                  <TableRow key={c.key}>
                    <TableCell>
                      {hasChildren ? (
                        <button
                          type="button"
                          onClick={() => toggleCollapse(c.key)}
                          className="inline-flex h-6 w-6 items-center justify-center rounded hover:bg-muted"
                          title={isCollapsed ? '展开' : '折叠'}
                          style={{ marginLeft: depth * 20 }}
                        >
                          {isCollapsed ? <CaretRight size={14} /> : <CaretDown size={14} />}
                        </button>
                      ) : (
                        <span style={{ display: 'inline-block', width: 24, marginLeft: depth * 20 }} />
                      )}
                    </TableCell>
                    <TableCell>
                      {c.level === 1 ? (
                        <div className="h-8 w-8 overflow-hidden rounded-md bg-muted border border-input flex items-center justify-center">
                          {icon ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img src={icon} alt={c.name} className="h-full w-full object-cover" />
                          ) : (
                            <span className="text-[10px] text-muted-foreground">默认</span>
                          )}
                        </div>
                      ) : (
                        <span className="text-xs text-muted-foreground">—</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <code className="text-xs font-mono bg-muted/40 px-1.5 py-0.5 rounded">
                        {c.key}
                      </code>
                    </TableCell>
                    <TableCell className="font-medium">{c.name}</TableCell>
                    <TableCell>
                      <span className="text-xs text-muted-foreground">{c.level}级</span>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">{c.sortOrder}</TableCell>
                    <TableCell>
                      {c.isSystem ? (
                        <Badge variant="secondary">
                          <Lock size={10} className="mr-1" /> 系统
                        </Badge>
                      ) : (
                        <Badge variant="outline">自定义</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={c.isActive}
                          disabled={togglePending && pendingToggleKey === c.key}
                          onCheckedChange={() => {
                            setPendingToggleKey(c.key);
                            startToggleTransition(async () => {
                              const result = await toggleCategoryActive(c.key);
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
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Button size="sm" variant="ghost" onClick={() => openEdit(c)}>
                          <PencilSimple size={14} className="mr-1" /> 编辑
                        </Button>
                        {c.isSystem ? (
                          <span
                            title="系统分类不可删除"
                            className="inline-flex items-center text-xs text-muted-foreground px-2 py-1 cursor-not-allowed"
                          >
                            <Lock size={12} className="mr-1" /> 不可删
                          </span>
                        ) : confirmDeleteKey === c.key ? (
                          <>
                            <Button
                              size="sm"
                              variant="destructive"
                              disabled={deletePending && deletingKey === c.key}
                              onClick={() => handleDelete(c.key)}
                            >
                              确认删除
                            </Button>
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => setConfirmDeleteKey(null)}
                              disabled={deletePending && deletingKey === c.key}
                            >
                              取消
                            </Button>
                          </>
                        ) : (
                          <Button
                            size="sm"
                            variant="ghost"
                            className="text-destructive hover:text-destructive"
                            onClick={() => setConfirmDeleteKey(c.key)}
                          >
                            <Trash size={14} className="mr-1" /> 删除
                          </Button>
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

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-left">
              {editingKey ? '编辑分类' : '新建分类'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingKey
                ? `修改分类「${editingKey}」的属性。系统分类的 key 不可更改。`
                : '分类支持三级树形结构：一级（题材）→ 二级（风格）→ 三级（方式）。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            {/* 层级选择 */}
            <div className="space-y-2">
              <Label>层级 *</Label>
              <Select
                value={String(form.level)}
                onValueChange={(v) => handleLevelChange(Number(v) as 1 | 2 | 3)}
                disabled={Boolean(editingKey)}
              >
                <SelectTrigger><SelectValue placeholder="选择层级" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="1">{LEVEL_LABEL[1]}</SelectItem>
                  <SelectItem value="2">{LEVEL_LABEL[2]}</SelectItem>
                  <SelectItem value="3">{LEVEL_LABEL[3]}</SelectItem>
                </SelectContent>
              </Select>
              {editingKey && (
                <p className="text-xs text-muted-foreground">已有分类的层级不可修改。</p>
              )}
            </div>

            {/* 三级：先选一级（祖父），再选二级（父） */}
            {form.level === 3 && (
              <div className="space-y-2">
                <Label>所属一级分类 *</Label>
                <Select
                  value={form.grandparentKey}
                  onValueChange={handleGrandparentChange}
                  disabled={Boolean(editingKey)}
                >
                  <SelectTrigger><SelectValue placeholder="选择一级分类" /></SelectTrigger>
                  <SelectContent>
                    {level1Categories.map((c) => (
                      <SelectItem key={c.key} value={c.key}>
                        {c.name} ({c.key})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {editingKey && (
                  <p className="text-xs text-muted-foreground">已有分类的所属一级不可修改。</p>
                )}
              </div>
            )}

            {/* 二三级：父分类选择 */}
            {form.level !== 1 && (
              <div className="space-y-2">
                <Label>
                  父分类 * {form.level === 3 && <span className="text-xs text-muted-foreground">（二级）</span>}
                </Label>
                <Select
                  value={form.parentKey}
                  onValueChange={(v) => setForm({ ...form, parentKey: v })}
                  disabled={form.level === 3 && !form.grandparentKey}
                >
                  <SelectTrigger><SelectValue placeholder="选择父分类" /></SelectTrigger>
                  <SelectContent>
                    {(form.level === 2 ? level1Categories : level2ByGrandparent).map((c) => (
                      <SelectItem key={c.key} value={c.key}>
                        {c.name} ({c.key})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {form.level === 3 && !form.grandparentKey && (
                  <p className="text-xs text-muted-foreground">请先选择一级分类。</p>
                )}
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
                <div className="flex items-center gap-2 h-10">
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

            {/* 图标上传仅一级分类显示 */}
            {form.level === 1 && (
              <FileUpload
                label="分类图标（可选）"
                accept="image/*"
                maxSize={5 * 1024 * 1024}
                value={iconFile}
                onChange={setIconFile}
                hint="建议 5MB 以内的 png/svg/jpg；为空时使用 Flutter 内置图标映射。"
                previewUrl={
                  editingKey
                    ? toAssetUrl(
                        categories.find((c) => c.key === editingKey)?.iconUrl,
                        backendUrl,
                      ) || undefined
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
    </div>
  );
}

export default CategoryManager;
