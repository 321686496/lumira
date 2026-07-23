// src/components/invites-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { InviteListResponse } from '@/types/admin';

const channelLabels: Record<string, string> = {
  direct: '直接',
  share_card: '分享卡片',
  qrcode: '二维码',
};

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
            <TableHead>激活时间</TableHead>
            <TableHead>邀请人 IP</TableHead>
            <TableHead>被邀请人 IP</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                无邀请记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => (
              <TableRow key={row.id}>
                <TableCell className="text-muted-foreground">{row.id}</TableCell>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.inviterDeviceId)}</TableCell>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.inviteeDeviceId)}</TableCell>
                <TableCell className="font-mono">{row.inviteCode}</TableCell>
                <TableCell>
                  <Badge variant="secondary">{channelLabels[row.channel] || row.channel}</Badge>
                </TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.activatedAt)}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.inviterIp || '—'}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.inviteeIp || '—'}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}
