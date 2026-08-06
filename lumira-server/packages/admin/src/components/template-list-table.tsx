// src/components/template-list-table.tsx
'use client';

import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Eye, PencilSimple, Trash } from '@phosphor-icons/react/dist/ssr';
import { formatUnixTime } from '@/lib/utils';
import { toAssetUrl } from '@/lib/asset-url';
import { useToast } from '@/hooks/use-toast';
import { toggleTemplateActive, deleteTemplate } from '@/actions/templates';
import type { AdminTemplateListItem } from '@/types/admin';

export function TemplateListTable({
  templates,
  backendUrl = 'http://localhost:3000',
}: {
  templates: AdminTemplateListItem[];
  /** 后端基础 URL，用于拼接静态资源地址（由服务端页面传入）。 */
  backendUrl?: string;
}) {
  const router = useRouter();
  const { toast } = useToast();
  const [pendingToggleId, setPendingToggleId] = useState<string | null>(null);
  const [togglePending, startToggleTransition] = useTransition();
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [deletePending, startDeleteTransition] = useTransition();
  const [confirmId, setConfirmId] = useState<string | null>(null);

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    startDeleteTransition(async () => {
      const result = await deleteTemplate(id);
      setDeletingId(null);
      if (result?.error) {
        toast({
          variant: 'destructive',
          title: '删除失败',
          description: result.error,
        });
      } else {
        toast({ title: '已删除', description: '模板已删除' });
        setConfirmId(null);
        router.refresh();
      }
    });
  };

  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-20">封面</TableHead>
            <TableHead>名称</TableHead>
            <TableHead className="w-32">分类</TableHead>
            <TableHead className="w-24">价格</TableHead>
            <TableHead className="w-24">排序</TableHead>
            <TableHead className="w-24">状态</TableHead>
            <TableHead className="w-40">更新时间</TableHead>
            <TableHead className="w-56">操作</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {templates.length === 0 ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                暂无模板，点击右上角“新建模板”创建
              </TableCell>
            </TableRow>
          ) : (
            templates.map((t) => {
              const cover = toAssetUrl(t.coverUrl, backendUrl);
              return (
                <TableRow key={t.id}>
                  <TableCell>
                    <div className="h-12 w-12 overflow-hidden rounded-md bg-muted border border-input">
                      {cover ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={cover} alt={t.name} className="h-full w-full object-cover" />
                      ) : (
                        <span className="flex h-full w-full items-center justify-center text-[10px] text-muted-foreground">无</span>
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="font-medium">
                    <span title={t.id} className="block truncate max-w-[200px]">
                      {t.name}
                    </span>
                    <span className="block text-xs text-muted-foreground truncate max-w-[200px]">
                      {t.id}
                    </span>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">{t.categoryName || t.category}</Badge>
                  </TableCell>
                  <TableCell>
                    {t.price > 0 ? (
                      <span className="text-sm">{t.price}</span>
                    ) : (
                      <span className="text-xs text-muted-foreground">免费</span>
                    )}
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">{t.sortOrder}</TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Switch
                        checked={t.isActive}
                        disabled={togglePending && pendingToggleId === t.id}
                        onCheckedChange={(checked) => {
                          setPendingToggleId(t.id);
                          startToggleTransition(async () => {
                            const result = await toggleTemplateActive(t.id);
                            setPendingToggleId(null);
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
                        {t.isActive ? '上架' : '下架'}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">
                    {formatUnixTime(t.updatedAt)}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1">
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/dashboard/templates/${t.id}`}>
                          <Eye size={14} className="mr-1" /> 查看
                        </Link>
                      </Button>
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/dashboard/templates/${t.id}`}>
                          <PencilSimple size={14} className="mr-1" /> 编辑
                        </Link>
                      </Button>
                      {confirmId === t.id ? (
                        <>
                          <Button
                            size="sm"
                            variant="destructive"
                            disabled={deletePending && deletingId === t.id}
                            onClick={() => handleDelete(t.id)}
                          >
                            确认删除
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setConfirmId(null)}
                            disabled={deletePending && deletingId === t.id}
                          >
                            取消
                          </Button>
                        </>
                      ) : (
                        <Button
                          size="sm"
                          variant="ghost"
                          className="text-destructive hover:text-destructive"
                          onClick={() => setConfirmId(t.id)}
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
  );
}

export default TemplateListTable;
