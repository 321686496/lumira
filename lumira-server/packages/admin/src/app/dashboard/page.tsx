// src/app/(dashboard)/dashboard/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { StatsCard } from '@/components/stats-card';
import { ChartCard } from '@/components/chart-card';
import { TrendPanel } from '@/components/trend-panel';
import { DistributionList } from '@/components/distribution-list';
import { DeviceMobile } from '@phosphor-icons/react/dist/ssr/DeviceMobile';
import { Users } from '@phosphor-icons/react/dist/ssr/Users';
import { ArrowUp } from '@phosphor-icons/react/dist/ssr/ArrowUp';
import { Ticket } from '@phosphor-icons/react/dist/ssr/Ticket';
import { Gift } from '@phosphor-icons/react/dist/ssr/Gift';
import { Database } from '@phosphor-icons/react/dist/ssr/Database';
import { CalendarCheck } from '@phosphor-icons/react/dist/ssr/CalendarCheck';
import { Coins } from '@phosphor-icons/react/dist/ssr/Coins';
import { PiggyBank } from '@phosphor-icons/react/dist/ssr/PiggyBank';
import { HandCoins } from '@phosphor-icons/react/dist/ssr/HandCoins';
import { Package } from '@phosphor-icons/react/dist/ssr/Package';
import { Star } from '@phosphor-icons/react/dist/ssr/Star';
import { FileText } from '@phosphor-icons/react/dist/ssr/FileText';
import { ShieldCheck } from '@phosphor-icons/react/dist/ssr/ShieldCheck';
import { Stack } from '@phosphor-icons/react/dist/ssr/Stack';

export default async function DashboardPage() {
  let stats;
  let trend;
  try {
    const [s, t] = await Promise.all([
      api.getStats(),
      api.getStatsTrend(30),
    ]);
    stats = s;
    trend = t;
  } catch (e) {
    if (e instanceof UnauthenticatedError) {
      redirect('/login');
    }
    return (
      <div className="text-destructive">加载统计数据失败：{(e as Error).message}</div>
    );
  }

  const toEntries = (obj: Record<string, number>) =>
    Object.entries(obj).sort((a, b) => b[1] - a[1]);

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

      {/* 活跃度 */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard label="今日日活 (DAU)" value={stats.dau} icon={Users} hint="今日活跃设备数" />
        <StatsCard label="近30日月活 (MAU)" value={stats.mau} icon={CalendarCheck} />
        <StatsCard label="本月注册" value={stats.newDevicesThisMonth} icon={DeviceMobile} hint="本月新增设备数" />
      </section>

      {/* 兑换码统计 - 1x3 grid */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard label="已生成码数" value={stats.totalCodesGenerated} icon={Ticket} />
        <StatsCard label="已使用码数" value={stats.totalCodesUsed} icon={Database} />
        <StatsCard label="剩余可用" value={stats.totalCodesRemaining} icon={Ticket} />
      </section>

      {/* 7/30 日趋势图（已实现） */}
      <TrendPanel data={trend.days} />

      {/* 平台分布 + 用户画像 */}
      <section className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <ChartCard title="平台分布" description="设备端平台构成占比">
          <DistributionList items={stats.platformBreakdown.map((p) => [p.platform, p.count])} />
        </ChartCard>
        <ChartCard title="用户性别" description="按性别分布">
          <DistributionList items={toEntries(stats.profileBreakdown.gender)} />
        </ChartCard>
        <ChartCard title="拍摄水平" description="按拍摄水平分布">
          <DistributionList items={toEntries(stats.profileBreakdown.skillLevel)} />
        </ChartCard>
      </section>

      {/* 积分健康 */}
      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <StatsCard label="累积分发" value={stats.totalPointsEarned} icon={Coins} />
        <StatsCard label="累计消耗" value={stats.totalPointsSpent} icon={HandCoins} />
        <StatsCard label="在库余额" value={stats.totalPointsBalance} icon={PiggyBank} hint="全部用户余额之和" />
        <StatsCard label="今日签到" value={stats.todaySignIns} icon={CalendarCheck} />
        <StatsCard label="今日积分事件" value={stats.todayPointEvents} icon={Coins} />
      </section>

      {/* 内容健康度 */}
      <section className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
        <StatsCard label="模板总数" value={stats.totalTemplates} icon={Package} />
        <StatsCard label="活跃模板" value={stats.activeTemplates} icon={Star} />
        <StatsCard label="付费模板" value={stats.paidTemplates} icon={Ticket} />
        <StatsCard label="待处理反馈" value={stats.pendingFeedbacks} icon={FileText} />
        <StatsCard label="邀请达成率" value={`${stats.inviteSuccessRate}%`} icon={ShieldCheck} />
        <StatsCard label="兑换码批次" value={stats.totalBatches} icon={Stack} />
      </section>

      {/* 拍摄频率 */}
      <ChartCard title="拍摄频率" description="用户自报的拍摄频率分布">
        <DistributionList items={toEntries(stats.profileBreakdown.shootFrequency)} />
      </ChartCard>
    </div>
  );
}