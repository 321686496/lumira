'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { grantPointsAction } from '@/actions/points';

export default function PointsForm({ deviceId }: { deviceId: string }) {
  const [delta, setDelta] = useState('');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState<number | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess(null);

    const amount = parseInt(delta, 10);
    if (!amount || amount <= 0) {
      setError('请输入有效的正整数积分');
      return;
    }
    if (!reason.trim()) {
      setError('请填写充值原因');
      return;
    }

    setLoading(true);
    try {
      const result = await grantPointsAction(deviceId, amount, reason.trim());
      if (result.error) {
        setError(result.error);
      } else {
        setSuccess(result.balance!);
        setDelta('');
        setReason('');
      }
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="delta">充值积分</Label>
          <Input
            id="delta"
            type="number"
            min={1}
            placeholder="输入积分数量"
            value={delta}
            onChange={(e) => setDelta(e.target.value)}
            disabled={loading}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="reason">充值原因</Label>
          <Input
            id="reason"
            placeholder="如：活动奖励、补偿等"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            disabled={loading}
          />
        </div>
      </div>

      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}

      {success !== null && (
        <p className="text-sm text-emerald-600">
          充值成功！当前积分余额：{success}
        </p>
      )}

      <Button type="submit" disabled={loading}>
        {loading ? '充值中...' : '确认充值'}
      </Button>
    </form>
  );
}