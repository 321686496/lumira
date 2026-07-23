// src/components/trend-chart.tsx
'use client';

import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';

export interface TrendDataPoint {
  date: string;       // "MM-DD"
  devices: number;
  invites: number;
}

export function TrendChart({ data }: { data: TrendDataPoint[] }) {
  if (!data.length) {
    return (
      <div className="h-72 flex items-center justify-center text-sm text-muted-foreground">
        暂无趋势数据
      </div>
    );
  }
  return (
    <div className="h-72 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
          <XAxis dataKey="date" stroke="hsl(var(--muted-foreground))" fontSize={12} />
          <YAxis stroke="hsl(var(--muted-foreground))" fontSize={12} allowDecimals={false} />
          <Tooltip
            contentStyle={{
              backgroundColor: 'hsl(var(--card))',
              border: '1px solid hsl(var(--border))',
              borderRadius: '8px',
              color: 'hsl(var(--foreground))',
            }}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="devices"
            stroke="hsl(var(--chart-1))"
            name="设备注册"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
          <Line
            type="monotone"
            dataKey="invites"
            stroke="hsl(var(--chart-2))"
            name="邀请激活"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
