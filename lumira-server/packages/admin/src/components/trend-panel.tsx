// src/components/trend-panel.tsx
'use client';

import { useMemo, useState } from 'react';
import { ChartCard } from '@/components/chart-card';
import { TrendChart } from '@/components/trend-chart';
import { Button } from '@/components/ui/button';
import type { TrendPoint } from '@/types/admin';

// 服务端一次性拉取近 30 日数据传入；近 7 日 = 30 日序列的末 7 个点，
// 客户端本地切片切换即可，无需二次请求（避免 client 组件依赖服务端 cookies）。
export function TrendPanel({ data }: { data: TrendPoint[] }) {
  const [range, setRange] = useState<7 | 30>(7);
  const display = useMemo(() => (range === 30 ? data : data.slice(-7)), [range, data]);

  return (
    <ChartCard title="趋势" description="设备注册 / 日活 / 邀请激活走势">
      <div className="mb-4 flex items-center justify-end gap-2">
        <Button
          size="sm"
          variant={range === 7 ? 'default' : 'outline'}
          onClick={() => setRange(7)}
        >
          近7日
        </Button>
        <Button
          size="sm"
          variant={range === 30 ? 'default' : 'outline'}
          onClick={() => setRange(30)}
        >
          近30日
        </Button>
      </div>
      <TrendChart data={display} />
    </ChartCard>
  );
}