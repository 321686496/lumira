// src/app/(dashboard)/dashboard/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { StatsCard } from '@/components/stats-card';
import { ChartCard } from '@/components/chart-card';
import { TrendChart } from '@/components/trend-chart';
import { DeviceMobile } from '@phosphor-icons/react/dist/ssr/DeviceMobile';
import { Users } from '@phosphor-icons/react/dist/ssr/Users';
import { ArrowUp } from '@phosphor-icons/react/dist/ssr/ArrowUp';
import { Ticket } from '@phosphor-icons/react/dist/ssr/Ticket';
import { Gift } from '@phosphor-icons/react/dist/ssr/Gift';
import { Database } from '@phosphor-icons/react/dist/ssr/Database';

export default async function DashboardPage() {
  let stats;
  try {
    stats = await api.getStats();
  } catch (e) {
    return (
      <div className="text-destructive">加载统计数据失败：{(e as Error).message}</div>
    );
  }

  // 注：后端目前无 /admin/stats/trend 端点，趋势图先用空数据占位
  // 待后端扩展后改为：const trend = await api.getStatsTrend();
  const trend: { date: string; devices: number; invites: number }[] = [];

  return (
    <div className="space-y-6">
      {/* 业务统计 - 2x2 grid */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatsCard
          label="累计设备"
          value={stats.totalDevices}
          icon={DeviceMobile}
          hint={`今日新增 ${stats.todayNewDevices}`}
        />
        <StatsCard
          label="累计邀请"
          value={stats.totalInvites}
          icon={Users}
          hint={`今日 ${stats.todayNewInvites}`}
        />
        <StatsCard
          label="累计兑换"
          value={stats.totalRedemptions}
          icon={ArrowUp}
          hint={`今日 ${stats.todayRedeemed}`}
        />
        <StatsCard
          label="奖励解锁"
          value={stats.totalRewardUnlocks}
          icon={Gift}
        />
      </section>

      {/* 兑换码统计 - 1x3 grid */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard label="已生成码数" value={stats.totalCodesGenerated} icon={Ticket} />
        <StatsCard label="已使用码数" value={stats.totalCodesUsed} icon={Database} />
        <StatsCard label="剩余可用" value={stats.totalCodesRemaining} icon={Ticket} />
      </section>

      {/* 7 日趋势图（占位） */}
      <ChartCard
        title="近 7 日趋势"
        description="设备注册与邀请激活走势（数据接口待后端扩展）"
      >
        <TrendChart data={trend} />
      </ChartCard>
    </div>
  );
}
