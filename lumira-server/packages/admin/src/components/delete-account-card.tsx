'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { deleteDeviceAction } from '@/actions/devices';

export function DeleteAccountCard({
  deviceId,
  username,
}: {
  deviceId: string;
  username?: string | null;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [loginKey, setLoginKey] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleDelete = async () => {
    setError('');
    if (!loginKey.trim()) {
      setError('请输入登录 key');
      return;
    }

    setLoading(true);
    try {
      const result = await deleteDeviceAction(deviceId, loginKey);
      if (result.error) {
        setError(result.error);
        return;
      }
      setOpen(false);
      router.push('/dashboard/devices');
      router.refresh();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="border-destructive/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm text-destructive">危险操作</CardTitle>
        <CardDescription>
          删除后该用户资料、积分、兑换、邀请、反馈和使用记录将全部清除，操作不可撤销。
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Button variant="destructive" onClick={() => { setLoginKey(''); setError(''); setOpen(true); }}>
          删除该用户账号
        </Button>
      </CardContent>

      <Dialog open={open} onOpenChange={(next) => { if (!loading) setOpen(next); }}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-left text-destructive">永久删除用户账号</DialogTitle>
            <DialogDescription className="text-left">
              即将永久删除「{username || '未命名用户'}」（{deviceId}）的全部关联数据。此操作不可撤销，必须输入登录 key。
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-2">
            <Label htmlFor="delete-login-key">登录 key</Label>
            <Input
              id="delete-login-key"
              type="password"
              autoComplete="off"
              value={loginKey}
              onChange={(e) => setLoginKey(e.target.value)}
              disabled={loading}
              placeholder="输入后台登录 key"
            />
            {error && <p className="text-sm text-destructive">{error}</p>}
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={loading}>
              取消
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={loading}>
              {loading ? '删除中...' : '确认永久删除'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
