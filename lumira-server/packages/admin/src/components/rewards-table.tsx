// src/components/rewards-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { RewardListResponse } from '@/types/admin';

const sourceLabels: Record<string, { label: string; variant: 'default' | 'secondary' }> = {
  invite: { label: '邀请', variant: 'default' },
  redemption: { label: '兑换码', variant: 'secondary' },
};

export function RewardsTable({ data }: { data: RewardListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>设备 ID</TableHead>
            <TableHead>阶梯</TableHead>
            <TableHead>来源</TableHead>
            <TableHead>来源详情</TableHead>
            <TableHead>解锁时间</TableHead>
            <TableHead>状态</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                无奖励解锁记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((r) => {
              const src = sourceLabels[r.source] || { label: r.source, variant: 'secondary' as const };
              const claimed = r.status === 'claimed';
              return (
                <TableRow key={r.id}>
                  <TableCell className="text-muted-foreground">{r.id}</TableCell>
                  <TableCell className="font-mono text-xs">{truncateDeviceId(r.deviceId)}</TableCell>
                  <TableCell><Badge variant="outline">Tier {r.tier}</Badge></TableCell>
                  <TableCell>
                    <Badge variant={src.variant}>{src.label}</Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {r.sourceDetail || '—'}
                  </TableCell>
                  <TableCell className="text-sm">{formatUnixTime(r.unlockedAt)}</TableCell>
                  <TableCell>
                    <Badge variant={claimed ? 'default' : 'outline'}>
                      {claimed ? '已领取' : '已解锁'}
                    </Badge>
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
