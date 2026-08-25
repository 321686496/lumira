import { notFound, redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ToggleSwitch } from '@/components/toggle-switch';
import { BatchCodesTable } from '@/components/batch-codes-table';
import { formatUnixTime } from '@/lib/utils';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import Link from 'next/link';

function parseRewardTemplates(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export default async function BatchDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const batchId = Number(params.id);
  if (Number.isNaN(batchId)) notFound();

  let detail;
  try {
    detail = await api.getBatchDetail(batchId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    if ((e as Error).message.includes('404')) notFound();
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  const active = detail.isActive === 1;
  const templateIds = parseRewardTemplates(detail.rewardTemplates);

  return (
    <div className="space-y-4">
      <Button asChild variant="ghost" size="sm">
        <Link href="/dashboard/redeem-batches">
          <ArrowLeft size={14} className="mr-1" /> 返回列表
        </Link>
      </Button>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-left">{detail.campaignName}</CardTitle>
            <p className="text-sm text-muted-foreground mt-1 text-left">
              批次 #{detail.batchId} · 创建于 {formatUnixTime(detail.createdAt)}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <Badge variant={active ? 'default' : 'destructive'}>
              {active ? '启用' : '已禁用'}
            </Badge>
            <ToggleSwitch batchId={detail.batchId} isActive={active} />
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <p className="text-muted-foreground">奖励积分</p>
              <p className="mt-1">{detail.rewardPoints > 0 ? `${detail.rewardPoints} 积分` : '无'}</p>
            </div>
            <div>
              <p className="text-muted-foreground">奖励模板</p>
              <p className="mt-1">
                {templateIds.length > 0
                  ? `${templateIds.length} 个模板`
                  : '无'}
              </p>
            </div>
            <div>
              <p className="text-muted-foreground">每码上限</p>
              <p className="mt-1">{detail.maxUsesPerCode} 次</p>
            </div>
            <div>
              <p className="text-muted-foreground">有效期</p>
              <p className="mt-1 text-xs">
                {detail.validFrom || detail.validUntil
                  ? `${detail.validFrom ? formatUnixTime(detail.validFrom) : '?'} ~ ${detail.validUntil ? formatUnixTime(detail.validUntil) : '永久'}`
                  : '永久'}
              </p>
            </div>
            <div>
              <p className="text-muted-foreground">总量/已用</p>
              <p className="mt-1">{detail.totalUsed} / {detail.totalGenerated}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <div>
        <h3 className="text-base font-medium text-foreground mb-3 text-left">码列表</h3>
        <BatchCodesTable codes={detail.codes} />
      </div>
    </div>
  );
}