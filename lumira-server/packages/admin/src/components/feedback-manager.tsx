// src/components/feedback-manager.tsx
'use client';

import { useState } from 'react';
import { api } from '@/lib/api';
import { toAssetUrl } from '@/lib/asset-url';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogClose,
} from '@/components/ui/dialog';
import type { FeedbackAdminItem, FeedbackListResponse } from '@/types/admin';

const TYPE_LABEL: Record<string, string> = {
  bug: '漏洞Bug', inconvenience: '使用不便', feature: '功能建议',
  template: '模板建议', scene: '场景建议', other: '其他',
};

export function FeedbackManager({ initialData, backendUrl }: {
  initialData: FeedbackListResponse;
  backendUrl: string;
}) {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState<string>('all');
  const [type, setType] = useState<string>('all');
  const [data, setData] = useState<FeedbackListResponse>(initialData);
  const [loading, setLoading] = useState(false);

  async function refresh(nextPage = 1) {
    setLoading(true);
    try {
      const resp = await api.listFeedbacks({
        page: nextPage,
        pageSize: 20,
        type: type !== 'all' ? type : undefined,
        status: status !== 'all' ? status : undefined,
      });
      setData(resp);
      setPage(resp.page);
    } finally {
      setLoading(false);
    }
  }

  async function toggle(item: FeedbackAdminItem) {
    const next = item.status === 'handled' ? 'pending' : 'handled';
    await api.updateFeedbackStatus(item.id, next);
    setData((prev) => ({
      ...prev,
      data: prev.data.map((x) => (x.id === item.id ? { ...x, status: next } : x)),
      total: prev.total,
      page: prev.page,
      pageSize: prev.pageSize,
    }));
  }

  const totalPages = Math.max(1, Math.ceil(data.total / data.pageSize));

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <select
          className="h-9 rounded-md border border-input px-3 text-sm"
          value={status}
          onChange={(e) => { setStatus(e.target.value); refresh(1); }}
        >
          <option value="all">全部状态</option>
          <option value="pending">未处理</option>
          <option value="handled">已处理</option>
        </select>
        <select
          className="h-9 rounded-md border border-input px-3 text-sm"
          value={type}
          onChange={(e) => { setType(e.target.value); refresh(1); }}
        >
          <option value="all">全部类型</option>
          {Object.entries(TYPE_LABEL).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </select>
        <span className="text-sm text-muted-foreground">共 {data.total} 条</span>
        {loading && <span className="text-sm text-muted-foreground">加载中…</span>}
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>类型</TableHead>
            <TableHead>反馈内容</TableHead>
            <TableHead>联系方式</TableHead>
            <TableHead>状态</TableHead>
            <TableHead>提交时间</TableHead>
            <TableHead className="text-right">操作</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.map((item) => (
            <TableRow key={item.id}>
              <TableCell>
                <Badge variant={item.status === 'handled' ? 'secondary' : 'default'}>
                  {TYPE_LABEL[item.type] ?? item.type}
                </Badge>
              </TableCell>
              <TableCell className="max-w-[280px] truncate">{item.content}</TableCell>
              <TableCell>{item.contact || '—'}</TableCell>
              <TableCell>
                <Badge variant={item.status === 'handled' ? 'secondary' : 'default'}>
                  {item.status === 'handled' ? '已处理' : '未处理'}
                </Badge>
              </TableCell>
              <TableCell>{new Date(item.createdAt * 1000).toLocaleString()}</TableCell>
              <TableCell className="text-right">
                <Dialog>
                  <DialogTrigger asChild>
                    <Button variant="outline" size="sm">详情</Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>反馈详情</DialogTitle>
                    </DialogHeader>
                    <div className="space-y-3 text-sm">
                      <div><span className="text-muted-foreground">类型：</span>{TYPE_LABEL[item.type] ?? item.type}</div>
                      <div><span className="text-muted-foreground">设备：</span>{item.deviceId}</div>
                      <div><span className="text-muted-foreground">联系方式：</span>{item.contact || '—'}</div>
                      <div><span className="text-muted-foreground">IP：</span>{item.clientIp || '—'}</div>
                      <div><span className="text-muted-foreground">时间：</span>{new Date(item.createdAt * 1000).toLocaleString()}</div>
                      <div><span className="text-muted-foreground">内容：</span>{item.content}</div>
                      {item.screenshots.length > 0 && (
                        <div className="flex flex-wrap gap-2">
                          {item.screenshots.map((u) => (
                            <a key={u} href={u} target="_blank" rel="noreferrer">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={toAssetUrl(u, backendUrl) ?? ''}
                                alt="截图"
                                className="h-24 w-24 rounded-md border object-cover hover:opacity-80"
                              />
                            </a>
                          ))}
                        </div>
                      )}
                    </div>
                    <DialogClose asChild>
                      <Button variant="ghost" className="w-full mt-2">关闭</Button>
                    </DialogClose>
                  </DialogContent>
                </Dialog>
                <Button
                  variant={item.status === 'handled' ? 'secondary' : 'default'}
                  size="sm"
                  className="ml-2"
                  onClick={() => toggle(item)}
                >
                  {item.status === 'handled' ? '恢复未处理' : '标记已处理'}
                </Button>
              </TableCell>
            </TableRow>
          ))}
          {data.data.length === 0 && (
            <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground">暂无反馈</TableCell></TableRow>
          )}
        </TableBody>
      </Table>

      <div className="flex items-center justify-between">
        <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => refresh(page - 1)}>
          上一页
        </Button>
        <span className="text-sm text-muted-foreground">第 {page} / {totalPages} 页</span>
        <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => refresh(page + 1)}>
          下一页
        </Button>
      </div>
    </div>
  );
}

export default FeedbackManager;