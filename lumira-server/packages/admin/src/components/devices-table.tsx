import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { DeviceListResponse } from '@/types/admin';

const platformLabels: Record<string, string> = {
  android: 'Android',
  ios: 'iOS',
  harmonyos: 'HarmonyOS',
};

export function DevicesTable({ data }: { data: DeviceListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead>设备ID</TableHead>
            <TableHead>别名</TableHead>
            <TableHead>平台</TableHead>
            <TableHead>系统版本</TableHead>
            <TableHead>设备型号</TableHead>
            <TableHead>应用版本</TableHead>
            <TableHead>首次注册</TableHead>
            <TableHead>最后活跃</TableHead>
            <TableHead>IP区域</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={9} className="text-center text-muted-foreground py-8">
                无设备记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => (
              <TableRow key={row.deviceId}>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.deviceId)}</TableCell>
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
                <TableCell className="text-sm">{row.appVersion || '—'}</TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.firstSeenAt)}</TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.lastSeenAt)}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.ipRegion || '—'}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}
