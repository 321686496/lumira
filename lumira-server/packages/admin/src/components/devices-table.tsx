import Link from 'next/link';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import { toAssetUrl } from '@/lib/asset-url';
import { genderLabels } from '@/lib/profile-labels';
import { Coins, UserCircle } from '@phosphor-icons/react/dist/ssr';
import type { DeviceListResponse, DeviceRecord } from '@/types/admin';

const platformLabels: Record<string, string> = {
  android: 'Android',
  ios: 'iOS',
  harmonyos: 'HarmonyOS',
};

function AvatarCell({ row, backendUrl }: { row: DeviceRecord; backendUrl: string }) {
  const avatar = toAssetUrl(row.avatarUrl, backendUrl);
  const initial = (row.username || '?').trim().charAt(0).toUpperCase() || '?';
  return avatar ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={avatar}
      alt={row.username || '头像'}
      className="h-8 w-8 rounded-full object-cover ring-1 ring-border"
    />
  ) : (
    <span className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-muted text-sm font-medium text-muted-foreground ring-1 ring-border">
      {initial}
    </span>
  );
}

export function DevicesTable({
  data,
  backendUrl,
}: {
  data: DeviceListResponse;
  backendUrl: string;
}) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead>设备ID</TableHead>
            <TableHead className="w-10"></TableHead>
            <TableHead>用户名</TableHead>
            <TableHead>性别</TableHead>
            <TableHead>别名</TableHead>
            <TableHead>平台</TableHead>
            <TableHead>系统版本</TableHead>
            <TableHead>设备型号</TableHead>
            <TableHead>积分</TableHead>
            <TableHead>首次注册</TableHead>
            <TableHead>最后活跃</TableHead>
            <TableHead>IP区域</TableHead>
            <TableHead>操作</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={13} className="text-center text-muted-foreground py-8">
                无设备记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => (
              <TableRow key={row.deviceId}>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.deviceId)}</TableCell>
                <TableCell><AvatarCell row={row} backendUrl={backendUrl} /></TableCell>
                <TableCell className="text-sm">{row.username || '—'}</TableCell>
                <TableCell>
                  {row.gender ? (
                    <Badge variant="secondary">{genderLabels[row.gender] || row.gender}</Badge>
                  ) : (
                    <span className="text-muted-foreground text-xs">未填</span>
                  )}
                </TableCell>
                <TableCell className="text-sm">{row.alias || '—'}</TableCell>
                <TableCell>
                  {row.platform ? (
                    <Badge variant="secondary">
                      {platformLabels[row.platform] || row.platform}
                    </Badge>
                  ) : (
                    <span className="text-muted-foreground">—</span>
                  )}
                </TableCell>
                <TableCell className="text-sm">{row.osVersion || '—'}</TableCell>
                <TableCell className="text-sm">{row.deviceModel || '—'}</TableCell>
                <TableCell>
                  <span className="inline-flex items-center gap-1 text-sm font-medium">
                    <Coins size={14} className="text-amber-500" />
                    {row.pointsBalance ?? 0}
                  </span>
                </TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.firstSeenAt)}</TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.lastSeenAt)}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.ipRegion || '—'}</TableCell>
                <TableCell>
                  <div className="flex items-center gap-2">
                    <Link href={`/dashboard/devices/${row.deviceId}/profile`}>
                      <Button variant="outline" size="sm">
                        <UserCircle size={14} className="mr-1" /> 资料
                      </Button>
                    </Link>
                    <Link href={`/dashboard/devices/${row.deviceId}/points`}>
                      <Button variant="outline" size="sm">
                        <Coins size={14} className="mr-1" /> 积分
                      </Button>
                    </Link>
                  </div>
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}
