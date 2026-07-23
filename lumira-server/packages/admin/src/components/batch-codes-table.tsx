// src/components/batch-codes-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import type { BatchDetail } from '@/types/admin';

export function BatchCodesTable({ codes }: { codes: BatchDetail['codes'] }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="font-mono">兑换码</TableHead>
            <TableHead className="w-40">使用次数</TableHead>
            <TableHead className="w-32">使用率</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {codes.length === 0 ? (
            <TableRow>
              <TableCell colSpan={3} className="text-center text-muted-foreground py-8">无码</TableCell>
            </TableRow>
          ) : (
            codes.map((c) => {
              const pct = c.maxUses > 0 ? Math.round((c.usedCount / c.maxUses) * 100) : 0;
              const fullyUsed = c.usedCount >= c.maxUses;
              return (
                <TableRow key={c.code}>
                  <TableCell className="font-mono">{c.code}</TableCell>
                  <TableCell className="text-sm">
                    {c.usedCount} / {c.maxUses}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 max-w-20 h-1.5 bg-muted rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full ${fullyUsed ? 'bg-success' : 'bg-primary'}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                      <span className="text-xs text-muted-foreground w-10">{pct}%</span>
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
