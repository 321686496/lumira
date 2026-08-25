// src/app/dashboard/devices/[deviceId]/profile/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import { toAssetUrl } from '@/lib/asset-url';
import {
  genderLabels,
  categoryLabels,
  painTypeLabels,
  skillLevelLabels,
  expectationLabels,
  sceneLabels,
  frequencyLabels,
} from '@/lib/profile-labels';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import type { DeviceRecord } from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

const prefBlocks: Array<{
  key: keyof DeviceRecord;
  title: string;
  multi: boolean;
  map?: Record<string, string>;
}> = [
  { key: 'gender', title: '性别', multi: false, map: genderLabels },
  { key: 'favoriteCategories', title: '喜欢拍什么', multi: true, map: categoryLabels },
  { key: 'painPoints', title: '拍摄烦恼', multi: true, map: painTypeLabels },
  { key: 'skillLevel', title: '摄影水平', multi: false, map: skillLevelLabels },
  { key: 'expectations', title: '期望收获', multi: true, map: expectationLabels },
  { key: 'commonScenes', title: '常用场景', multi: true, map: sceneLabels },
  { key: 'shootFrequency', title: '拍摄频率', multi: false, map: frequencyLabels },
];

function PreferenceRow({
  rec,
  block,
}: {
  rec: DeviceRecord;
  block: (typeof prefBlocks)[number];
}) {
  const value = rec[block.key] as string | string[] | null | undefined;
  const isEmpty = value == null || (Array.isArray(value) && value.length === 0);
  const lab = (v: string) => (block.map?.[v] ? block.map[v] : v);

  return (
    <div className="border-b border-border/50 py-3 last:border-0">
      <div className="text-xs text-muted-foreground">{block.title}</div>
      <div className="mt-1">
        {isEmpty ? (
          <span className="text-muted-foreground text-xs">未填写</span>
        ) : Array.isArray(value) ? (
          <div className="flex flex-wrap gap-1.5">
            {value.map((v) => (
              <Badge key={v} variant="secondary">
                {lab(v)}
              </Badge>
            ))}
          </div>
        ) : (
          <Badge variant="outline">{lab(value as string)}</Badge>
        )}
      </div>
    </div>
  );
}

export default async function DeviceProfilePage({
  params,
}: {
  params: { deviceId: string };
}) {
  const { deviceId } = params;

  let rec: DeviceRecord | null = null;
  try {
    const list = await api.getDevices({ page: 1, pageSize: 1, search: deviceId });
    rec = list.data[0] || null;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  if (!rec) {
    return <div className="text-muted-foreground py-8 text-center">未找到该设备</div>;
  }

  const avatar = toAssetUrl(rec.avatarUrl, BACKEND_URL);
  const initial = (rec.username || '?').trim().charAt(0).toUpperCase() || '?';

  return (
    <div className="space-y-6">
      <Link href="/dashboard/devices">
        <Button variant="ghost" size="sm">
          <ArrowLeft size={16} className="mr-1" /> 返回设备列表
        </Button>
      </Link>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-muted-foreground">个人资料</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-start gap-4">
            {avatar ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={avatar}
                alt={rec.username || '头像'}
                className="h-16 w-16 rounded-full object-cover ring-1 ring-border"
              />
            ) : (
              <span className="inline-flex h-16 w-16 items-center justify-center rounded-full bg-muted text-xl font-medium text-muted-foreground ring-1 ring-border">
                {initial}
              </span>
            )}
            <div className="space-y-0.5">
              <p className="text-lg font-semibold">{rec.username || '—'}</p>
              <p className="font-mono text-xs text-muted-foreground">
                设备 ID：{truncateDeviceId(deviceId)}
              </p>
              <p className="text-xs text-muted-foreground">
                资料更新时间：{rec.profileUpdatedAt ? formatUnixTime(rec.profileUpdatedAt) : '—'}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-0">
          <CardTitle className="text-left text-sm">摄影偏好</CardTitle>
        </CardHeader>
        <CardContent className="pt-2">
          {prefBlocks.map((block) => (
            <PreferenceRow key={block.key} rec={rec} block={block} />
          ))}
        </CardContent>
      </Card>
    </div>
  );
}