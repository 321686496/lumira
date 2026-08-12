import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import { ArrowLeft, Coins, TrendUp, TrendDown } from '@phosphor-icons/react/dist/ssr';
import PointsForm from '@/components/points-form';

const transactionTypeLabels: Record<string, string> = {
  invite: '邀请奖励',
  sign_in: '签到',
  share: '分享',
  redeem_code: '兑换码',
  exchange_template: '兑换模板',
  ad: '广告',
  admin_grant: '管理员充值',
  shoot_daily: '每日首拍',
  challenge: '挑战完成',
};

export default async function DevicePointsPage({
  params,
}: {
  params: { deviceId: string };
}) {
  const { deviceId } = params;

  let userPoints;
  let deviceInfo;

  try {
    const [deviceList, points] = await Promise.all([
      api.getDevices({ page: 1, pageSize: 1, search: deviceId }),
      api.getUserPoints(deviceId),
    ]);
    userPoints = points;
    deviceInfo = deviceList.data[0] || null;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return (
      <div className="text-destructive">
        加载失败：{(e as Error).message}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Link href="/dashboard/devices">
          <Button variant="ghost" size="sm">
            <ArrowLeft size={16} className="mr-1" /> 返回设备列表
          </Button>
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">设备信息</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-1">
              <p className="font-mono text-xs">{truncateDeviceId(deviceId)}</p>
              {deviceInfo && (
                <>
                  <p className="text-sm">用户名：{deviceInfo.username || '—'}</p>
                  <p className="text-sm">别名：{deviceInfo.alias || '—'}</p>
                  {deviceInfo.platform && (
                    <Badge variant="secondary" className="mt-1">
                      {deviceInfo.platform}
                    </Badge>
                  )}
                </>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">积分概况</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Coins size={20} className="text-amber-500" />
                <span className="text-2xl font-bold">{userPoints.balance}</span>
              </div>
              <div className="flex gap-4 text-sm text-muted-foreground">
                <span className="flex items-center gap-1">
                  <TrendUp size={14} className="text-emerald-500" />
                  累计获得 {userPoints.totalEarned}
                </span>
                <span className="flex items-center gap-1">
                  <TrendDown size={14} className="text-red-500" />
                  累计消耗 {userPoints.totalSpent}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">积分充值</CardTitle>
          </CardHeader>
          <CardContent>
            <PointsForm deviceId={deviceId} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-left">积分流水明细</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-muted/30">
                  <th className="text-left px-4 py-2 text-sm font-medium text-muted-foreground">时间</th>
                  <th className="text-left px-4 py-2 text-sm font-medium text-muted-foreground">类型</th>
                  <th className="text-right px-4 py-2 text-sm font-medium text-muted-foreground">变动</th>
                  <th className="text-left px-4 py-2 text-sm font-medium text-muted-foreground">参考ID</th>
                </tr>
              </thead>
              <tbody>
                {userPoints.transactions.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="text-center text-muted-foreground py-8 px-4">
                      暂无流水记录
                    </td>
                  </tr>
                ) : (
                  userPoints.transactions.map((tx) => (
                    <tr key={tx.id} className="border-b border-border/50 hover:bg-muted/10">
                      <td className="px-4 py-2 text-sm">{formatUnixTime(tx.createdAt)}</td>
                      <td className="px-4 py-2 text-sm">
                        {transactionTypeLabels[tx.type] || tx.type}
                      </td>
                      <td className={`px-4 py-2 text-sm text-right font-medium ${tx.delta > 0 ? 'text-emerald-600' : 'text-red-500'}`}>
                        {tx.delta > 0 ? `+${tx.delta}` : tx.delta}
                      </td>
                      <td className="px-4 py-2 text-sm text-muted-foreground font-mono text-xs">
                        {tx.refId || '—'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}