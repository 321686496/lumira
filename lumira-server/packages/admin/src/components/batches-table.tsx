// src/components/batches-table.tsx
import Link from 'next/link';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ToggleSwitch } from '@/components/toggle-switch';
import { formatUnixTime } from '@/lib/utils';
import { Eye } from '@phosphor-icons/react/dist/ssr';
import type { Batch } from '@/types/admin';

export function BatchesTable({ batches }: { batches: Batch[] }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>Campaign</TableHead>
            <TableHead>阶梯</TableHead>
            <TableHead className="w-32">使用情况</TableHead>
            <TableHead>有效期</TableHead>
            <TableHead>状态</TableHead>
            <TableHead className="w-40">操作</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {batches.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                无批次
              </TableCell>
            </TableRow>
          ) : (
            batches.map((b) => {
              const active = b.isActive === 1;
              const usedPct = b.totalGenerated > 0
                ? Math.round((b.totalUsed / b.totalGenerated) * 100)
                : 0;
              return (
                <TableRow key={b.batchId}>
                  <TableCell className="text-muted-foreground">{b.batchId}</TableCell>
                  <TableCell className="font-medium">{b.campaignName}</TableCell>
                  <TableCell>
                    <Badge variant="outline">Tier {b.rewardTier}</Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <span className="text-sm">{b.totalUsed}/{b.totalGenerated}</span>
                      <div className="flex-1 max-w-20 h-1.5 bg-muted rounded-full overflow-hidden">
                        <div
                          className="h-full bg-primary rounded-full"
                          style={{ width: `${usedPct}%` }}
                        />
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">
                    {b.validFrom || b.validUntil
                      ? `${b.validFrom ? formatUnixTime(b.validFrom) : '?'} ~ ${b.validUntil ? formatUnixTime(b.validUntil) : '永久'}`
                      : '永久'}
                  </TableCell>
                  <TableCell>
                    <Badge variant={active ? 'default' : 'destructive'}>
                      {active ? '启用' : '已禁用'}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/dashboard/redeem-batches/${b.batchId}`}>
                          <Eye size={14} className="mr-1" /> 详情
                        </Link>
                      </Button>
                      <ToggleSwitch batchId={b.batchId} isActive={active} />
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
