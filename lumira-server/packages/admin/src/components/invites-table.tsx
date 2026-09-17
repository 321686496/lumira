// src/components/invites-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime, cn } from '@/lib/utils';
import type { InviteListResponse } from '@/types/admin';

const channelLabels: Record<string, string> = {
  direct: '直接',
  share_card: '分享卡片',
  qrcode: '二维码',
};

const statusMeta = {
  pending: { label: '待成片', className: 'bg-amber-100 text-amber-800 hover:bg-amber-100' },
  success: { label: '已达成', className: 'bg-emerald-100 text-emerald-800 hover:bg-emerald-100' },
};

const DeviceIdCell = ({ value }: { value: string }) => (
  <TableCell className="font-mono text-xs" title={value}>
    {truncateDeviceId(value)}
  </TableCell>
);

export function InvitesTable({ data }: { data: InviteListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>邀请人</TableHead>
            <TableHead>被邀请人</TableHead>
            <TableHead className="font-mono">邀请码</TableHead>
            <TableHead>渠道</TableHead>
            <TableHead>状态</TableHead>
            <TableHead>邀请时间</TableHead>
            <TableHead>达成时间</TableHead>
            <TableHead>邀请人 IP</TableHead>
            <TableHead>被邀请人 IP</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={10} className="text-center text-muted-foreground py-8">
                无邀请记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => {
              const meta = statusMeta[row.status as keyof typeof statusMeta] ?? statusMeta.pending;
              return (
                <TableRow key={row.id}>
                  <TableCell className="text-muted-foreground">{row.id}</TableCell>
                  <DeviceIdCell value={row.inviterDeviceId} />
                  <DeviceIdCell value={row.inviteeDeviceId} />
                  <TableCell className="font-mono">{row.inviteCode}</TableCell>
                  <TableCell>
                    <Badge variant="secondary">{channelLabels[row.channel] || row.channel}</Badge>
                  </TableCell>
                  <TableCell>
                    <span
                      className={cn(
                        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
                        meta.className,
                      )}
                      title={row.status === 'success' ? '被邀请人已首次成片，奖励已发放' : '被邀请人尚未首次成片，邀请人奖励未发放'}
                    >
                      {meta.label}
                    </span>
                  </TableCell>
                  <TableCell className="text-sm">{formatUnixTime(row.activatedAt)}</TableCell>
                  <TableCell className="text-sm">{row.achievedAt ? formatUnixTime(row.achievedAt) : '—'}</TableCell>
                  <TableCell className="text-xs text-muted-foreground">{row.inviterIp || '—'}</TableCell>
                  <TableCell className="text-xs text-muted-foreground">{row.inviteeIp || '—'}</TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
