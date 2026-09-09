// src/components/banner-manager.tsx
'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
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
import { Upload } from '@phosphor-icons/react/dist/csr/Upload';
import { X } from '@phosphor-icons/react/dist/csr/X';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { useToast } from '@/hooks/use-toast';
import { saveBanner, removeBanner, setBannerActive, uploadBannerImage } from '@/actions/banners';
import { toAssetUrl } from '@/lib/asset-url';
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

/** Banner 配图上传限制（与后端 BANNER_IMAGE_MIME_EXT / MAX_BYTES 一致） */
const IMAGE_ACCEPT = 'image/jpeg,image/png,image/webp';
const IMAGE_MAX_BYTES = 2 * 1024 * 1024;

interface FormState {
  id: string;
  title: string;
  subtitle: string;
  tag: string;
  route: string;
  condition: string;
  imageUrl: string;
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
  imageUrl: '',
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

  // ===== 配图上传（选中即传，保存时 URL 随 payload 落库）=====
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [localObjectUrl, setLocalObjectUrl] = useState<string | null>(null);
  const [uploadPending, startUploadTransition] = useTransition();

  // 新选文件 → 生成本地预览 URL（上传/保存都成功前先看效果）
  useEffect(() => {
    if (imageFile) {
      const url = URL.createObjectURL(imageFile);
      setLocalObjectUrl(url);
      return () => URL.revokeObjectURL(url);
    }
    setLocalObjectUrl(null);
    return undefined;
  }, [imageFile]);

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setImageFile(null);
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
      imageUrl: b.imageUrl || '',
      sortOrder: b.sortOrder,
      isActive: b.isActive === 1,
    });
    setImageFile(null);
    setError(null);
    setDialogOpen(true);
  };

  /** 选择配图：本地校验 → 立即上传 → 成功后记录 URL（预览用本地 objectURL，无网络延迟） */
  const handleImageSelect = (file: File | null) => {
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      toast({ variant: 'destructive', title: '格式不支持', description: '仅支持 jpg / png / webp 格式图片' });
      return;
    }
    if (file.size > IMAGE_MAX_BYTES) {
      toast({ variant: 'destructive', title: '文件过大', description: '图片不能超过 2MB' });
      return;
    }
    const fd = new FormData();
    fd.set('image', file);
    startUploadTransition(async () => {
      const result = await uploadBannerImage(fd);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '上传失败', description: result.error });
        setImageFile(null);
        return;
      }
      setImageFile(file);
      setForm((f) => ({ ...f, imageUrl: result.url }));
      toast({ title: '配图已上传', description: '保存 Banner 后生效' });
    });
  };

  /** 移除配图：清空已选/已传，保存时下发空串清除 */
  const clearImage = () => {
    if (fileInputRef.current) fileInputRef.current.value = '';
    setImageFile(null);
    setForm((f) => ({ ...f, imageUrl: '' }));
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
      // 空串 = 清除配图；未改动时为后端原值，原样传回
      imageUrl: form.imageUrl,
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
                      {b.imageUrl ? (
                        <img
                          src={toAssetUrl(b.imageUrl, '') ?? ''}
                          alt=""
                          className="h-9 w-14 shrink-0 rounded-md object-cover"
                        />
                      ) : (
                        <div className="flex h-9 w-14 shrink-0 items-center justify-center rounded-md bg-muted">
                          <ImageSquare size={16} className="text-muted-foreground" />
                        </div>
                      )}
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

          {/* App 效果实时预览：7:3 卡片版式 + 配图 contain 完整显示 */}
          <BannerCardPreview
            imageUrl={localObjectUrl || toAssetUrl(form.imageUrl, '')}
            tag={form.tag}
            title={form.title}
            subtitle={form.subtitle}
          />

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

            <div className="space-y-2">
              <Label>配图（可选）</Label>
              <div className="flex flex-wrap items-center gap-2">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept={IMAGE_ACCEPT}
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0] ?? null;
                    if (file) handleImageSelect(file);
                  }}
                />
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={uploadPending}
                  onClick={() => fileInputRef.current?.click()}
                >
                  <Upload size={14} className="mr-1" />
                  {uploadPending ? '上传中…' : form.imageUrl ? '更换图片' : '上传图片'}
                </Button>
                {form.imageUrl && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    disabled={uploadPending}
                    onClick={clearImage}
                  >
                    <X size={14} className="mr-1" /> 移除
                  </Button>
                )}
                <span className="text-xs text-muted-foreground">jpg / png / webp，≤ 2MB</span>
              </div>
              <p className="text-xs text-muted-foreground">
                配图在 App 卡片右侧 40% 区域以 contain 方式完整显示（不裁切），两侧留白用同图模糊填充；不上传则展示品牌渐变背景。
              </p>
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

/**
 * App 首页 Banner 卡片效果预览（1:1 复刻 App 版式）。
 *
 * - 卡片比例 7:3（App 端 350×150 逻辑像素），圆角 16
 * - 无配图：品牌渐变背景 + 装饰圆（App 实际颜色随用户主题变化，此处用代表色）
 * - 有配图：右侧 40% 区域 contain 完整显示（不裁切），底层同图 cover + 模糊填充留白
 * - 文案：角标胶囊 + 主标题（单行截断）+ 副标题（两行截断），右侧箭头圆钮
 */
function BannerCardPreview({
  imageUrl,
  tag,
  title,
  subtitle,
}: {
  imageUrl: string | null;
  tag: string;
  title: string;
  subtitle: string;
}) {
  const [natural, setNatural] = useState<{ w: number; h: number } | null>(null);
  const hasImage = Boolean(imageUrl);

  return (
    <div className="space-y-1.5">
      <div
        className="relative w-full select-none overflow-hidden rounded-2xl shadow-md"
        style={{ aspectRatio: '7 / 3' }}
      >
        {/* 背景渐变（App 端为用户主题色板，此处为代表色） */}
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-700 via-indigo-500 to-violet-400" />

        {/* 无配图时的装饰圆 */}
        {!hasImage && (
          <>
            <div className="absolute -right-5 -top-5 h-[100px] w-[100px] rounded-full bg-white/8" />
            <div className="absolute -bottom-7 -left-3 h-20 w-20 rounded-full bg-white/6" />
          </>
        )}

        {/* 文案区（左侧 60%） */}
        <div className="absolute inset-y-0 left-0 flex w-[60%] flex-col justify-center gap-1.5 px-5">
          {tag && (
            <span className="w-fit rounded-full bg-white/20 px-2 py-0.5 text-[10px] font-semibold leading-4 text-white">
              {tag}
            </span>
          )}
          <p className="truncate text-[17px] font-bold leading-tight text-white" title={title}>
            {title || '主标题预览'}
          </p>
          <p className="line-clamp-2 text-[11px] leading-snug text-white/85" title={subtitle}>
            {subtitle || '副标题说明文案预览'}
          </p>
        </div>

        {/* 配图区（右侧 40%）：同图模糊填充 + contain 完整显示 */}
        {hasImage && (
          <div className="absolute inset-y-0 right-0 w-[40%] overflow-hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={imageUrl ?? ''}
              alt=""
              aria-hidden
              className="absolute inset-0 h-full w-full scale-125 object-cover opacity-60 blur-xl"
            />
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={imageUrl ?? ''}
              alt="Banner 配图预览"
              className="absolute inset-0 h-full w-full object-contain"
              onLoad={(e) => {
                const img = e.currentTarget;
                setNatural({ w: img.naturalWidth, h: img.naturalHeight });
              }}
            />
          </div>
        )}

        {/* 右下角箭头圆钮 */}
        <div className="absolute bottom-4 right-4 flex h-7 w-7 items-center justify-center rounded-full bg-white/20">
          <ArrowRight size={14} className="text-white" weight="bold" />
        </div>
      </div>

      <p className="text-xs text-muted-foreground">
        {hasImage
          ? natural
            ? `原图 ${natural.w} × ${natural.h}（${(natural.w / natural.h).toFixed(2)}:1）· App 卡片 7:3 · 右侧 contain 完整显示不裁切`
            : 'App 卡片 7:3 · 右侧 contain 完整显示不裁切'
          : '未上传配图：App 端展示品牌渐变背景（实际颜色随用户主题变化）'}
      </p>
    </div>
  );
}

export default BannerManager;
