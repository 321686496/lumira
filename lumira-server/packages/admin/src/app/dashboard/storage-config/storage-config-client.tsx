'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { STORAGE_OPTIONS } from '@/types/admin';
import type { StorageConfigView, StorageConfigPayload, StorageId } from '@/types/admin';
import { listStorageConfigAction, saveStorageConfigAction } from './actions';

const IS_S3 = (id: StorageId) => id !== 'local';

export default function StorageConfigClient({ initial }: { initial: StorageConfigView[] }) {
  const router = useRouter();
  const [items, setItems] = useState<StorageConfigView[]>(initial);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [okMsg, setOkMsg] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const res = await listStorageConfigAction();
    if (res.ok) setItems(res.data);
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const [drafts, setDrafts] = useState<Record<string, StorageConfigPayload>>({});
  const [activeDraft, setActiveDraft] = useState<StorageId | null>(null);

  const draft = (id: StorageId): StorageConfigPayload =>
    drafts[id] ?? {
      endpoint: items.find((i) => i.id === id)?.endpoints.endpoint ?? '',
      bucket: items.find((i) => i.id === id)?.endpoints.bucket ?? '',
      region: items.find((i) => i.id === id)?.endpoints.region ?? '',
      publicUrl: items.find((i) => i.id === id)?.endpoints.publicUrl ?? '',
    };

  const setField = (id: StorageId, key: keyof StorageConfigPayload, value: string) =>
    setDrafts((d) => ({ ...d, [id]: { ...draft(id), [key]: value } }));

  const save = async (id: StorageId, asActive: boolean) => {
    setBusy(true); setErr(null); setOkMsg(null);
    const payload = draft(id);
    const res = await saveStorageConfigAction(id, { ...payload, active: asActive });
    setBusy(false);
    if (!res.ok) {
      setErr(`${STORAGE_OPTIONS.find((o) => o.value === id)?.label}: ${res.error}`);
      return;
    }
    setOkMsg(`${STORAGE_OPTIONS.find((o) => o.value === id)?.label} 已保存`);
    setDrafts((d) => ({ ...d, [id]: {} as StorageConfigPayload }));
    await refresh();
    router.refresh();
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">存储配置</h1>
        <p className="text-sm text-muted-foreground">
          在此填写各厂商的对象存储凭证，并选择「当前激活存储」与图片公网 URL。
          保存即生效（无需改服务器 .env，也无需重启）。新上传写入激活存储；图片 URL 由激活存储公网 URL 生成。
        </p>
      </div>

      {err && (
        <div className="rounded-lg border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm text-destructive">
          {err}
        </div>
      )}
      {okMsg && (
        <div className="rounded-lg border border-green-500/40 bg-green-500/10 px-4 py-3 text-sm text-green-700">
          {okMsg}
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        {STORAGE_OPTIONS.map(({ value, label }) => {
          const item = items.find((i) => i.id === value);
          const v = item ?? { id: value, isActive: false, configured: false, endpoints: {}, hasCredentials: value === 'local', secretMasked: '', updatedAt: null };
          const d = draft(value);
          const isS3 = IS_S3(value);
          return (
            <Card key={value} className={cn(v.isActive && 'ring-2 ring-primary')}>
              <CardHeader>
                <CardTitle className="flex items-center justify-between text-base">
                  {label}
                  {v.isActive && <Badge>当前激活</Badge>}
                </CardTitle>
                <CardDescription>
                  {v.configured ? `已配置${v.updatedAt ? ` · ${new Date(v.updatedAt * 1000).toLocaleString()}` : ''}` : '未配置'}
                  {isS3 && (v.hasCredentials ? ` · 密钥${v.secretMasked ? ` ${v.secretMasked}` : ''}` : ' · 未填密钥')}
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {isS3 && (
                  <>
                    <div className="space-y-1">
                      <Label>Endpoint</Label>
                      <Input value={d.endpoint ?? ''} placeholder="https://s3-xxx.qiniucs.com" onChange={(e) => setField(value, 'endpoint', e.target.value)} />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                        <Label>AccessKey ID</Label>
                        <Input type="password" value={d.accessKeyId ?? ''} placeholder="AK / SecretId" onChange={(e) => setField(value, 'accessKeyId', e.target.value)} />
                      </div>
                      <div className="space-y-1">
                        <Label>SecretKey</Label>
                        <Input type="password" value={d.secretAccessKey ?? ''} placeholder="SK / SecretKey" onChange={(e) => setField(value, 'secretAccessKey', e.target.value)} />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                        <Label>Bucket</Label>
                        <Input value={d.bucket ?? ''} placeholder="空间名" onChange={(e) => setField(value, 'bucket', e.target.value)} />
                      </div>
                      <div className="space-y-1">
                        <Label>Region（可选）</Label>
                        <Input value={d.region ?? ''} placeholder="cn-east-1 / auto" onChange={(e) => setField(value, 'region', e.target.value)} />
                      </div>
                    </div>
                  </>
                )}
                <div className="space-y-1">
                  <Label>{isS3 ? '图片公网 URL' : '本地对外 URL（如后端域名）'}</Label>
                  <Input value={d.publicUrl ?? ''} placeholder="https://cdn.example.com" onChange={(e) => setField(value, 'publicUrl', e.target.value)} />
                </div>
                <div className="flex justify-end gap-2 pt-1">
                  <Button variant="outline" disabled={busy} onClick={() => save(value, false)}>保存</Button>
                  <Button disabled={busy} onClick={() => save(value, true)}>保存并设为激活</Button>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}