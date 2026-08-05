// src/components/category-manager.tsx
'use client';

import { useState, useTransition, useEffect } from 'react';
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
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog';
import { Plus, PencilSimple, Trash, Lock } from '@phosphor-icons/react/dist/ssr';
import { useToast } from '@/hooks/use-toast';
import { FileUpload } from '@/components/ui/file-upload';
import {
  createCategory, updateCategory, deleteCategory, toggleCategoryActive,
} from '@/actions/categories';
import type { TemplateCategory } from '@/types/admin';

function resolveAssetUrl(url: string | null | undefined, backendUrl: string): string | null {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `${backendUrl}${url.startsWith('/') ? '' : '/'}${url}`;
}

interface FormState {
  key: string;
  name: string;
  sortOrder: number;
  isActive: boolean;
}

const EMPTY_FORM: FormState = {
  key: '',
  name: '',
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
    setForm({
      key: cat.key,
      name: cat.name,
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
      // 等动画结束后再清理，避免抖动
      const t = setTimeout(() => {
        setEditingKey(null);
        setIconFile(null);
        setError(null);
      }, 200);
      return () => clearTimeout(t);
    }
    return undefined;
  }, [dialogOpen]);

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

    const meta: Record<string, unknown> = {
      name: form.name.trim(),
      sortOrder: Number(form.sortOrder) || 0,
      isActive: form.isActive,
    };
    if (!editingKey) {
      meta.key = form.key.trim();
    }

    const fd = new FormData();
    fd.set('meta', JSON.stringify(meta));
    if (iconFile) fd.set('icon', iconFile);

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

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button onClick={openCreate}>
          <Plus size={16} className="mr-1" /> 新建分类
        </Button>
      </div>

      <div className="rounded-md border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/30 hover:bg-muted/30">
              <TableHead className="w-16">图标</TableHead>
              <TableHead className="w-40">Key</TableHead>
              <TableHead>名称</TableHead>
              <TableHead className="w-24">排序</TableHead>
              <TableHead className="w-24">类型</TableHead>
              <TableHead className="w-32">状态</TableHead>
              <TableHead className="w-44">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {categories.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                  暂无分类
                </TableCell>
              </TableRow>
            ) : (
              categories.map((c) => {
                const icon = resolveAssetUrl(c.iconUrl, backendUrl);
                return (
                  <TableRow key={c.key}>
                    <TableCell>
                      <div className="h-8 w-8 overflow-hidden rounded-md bg-muted border border-input flex items-center justify-center">
                        {icon ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={icon} alt={c.name} className="h-full w-full object-cover" />
                        ) : (
                          <span className="text-[10px] text-muted-foreground">默认</span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      <code className="text-xs font-mono bg-muted/40 px-1.5 py-0.5 rounded">
                        {c.key}
                      </code>
                    </TableCell>
                    <TableCell className="font-medium">{c.name}</TableCell>
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
                : '自定义分类可在创建后用于模板归类。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="cat-key">Key *</Label>
              <Input
                id="cat-key"
                value={form.key}
                onChange={(e) => setForm({ ...form, key: e.target.value })}
                placeholder="如：portrait / landscape / my-custom"
                disabled={Boolean(editingKey)}
                className="font-mono"
              />
              {editingKey ? (
                <p className="text-xs text-muted-foreground">
                  {categories.find((c) => c.key === editingKey)?.isSystem
                    ? '系统分类的 key 不可修改。'
                    : '已有分类的 key 不可修改。'}
                </p>
              ) : (
                <p className="text-xs text-muted-foreground">
                  唯一标识，建议使用小写英文 + 连字符，与 Flutter 内置 7 类对齐（portrait / landscape / food / street / night / macro / still-life）。
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="cat-name">显示名称 *</Label>
              <Input
                id="cat-name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="如：人像"
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

            <FileUpload
              label="分类图标（可选）"
              accept="image/*"
              maxSize={1024 * 1024}
              value={iconFile}
              onChange={setIconFile}
              hint="建议 1MB 以内的 png/svg/jpg；为空时使用 Flutter 内置图标映射。"
              previewUrl={
                editingKey
                  ? resolveAssetUrl(
                      categories.find((c) => c.key === editingKey)?.iconUrl,
                      backendUrl,
                    ) || undefined
                  : undefined
              }
            />
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
