// src/app/dashboard/questionnaire/[deviceId]/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Badge } from '@/components/ui/badge';
import { formatUnixTime } from '@/lib/utils';
import Link from 'next/link';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';

const labelMaps: Record<string, Record<string, string>> = {
  source: {
    app_store: '应用商店', social_media: '社交媒体', friend: '朋友推荐',
    search: '搜索引擎', article: '文章博客', other: '其他',
  },
  favorite_categories: {
    portrait: '人像', landscape: '风光', food: '美食', street: '街拍',
    night: '夜景', macro: '微距', 'still-life': '静物',
  },
  pain_points: {
    composition: '构图困难', lighting: '光线处理', posing: '摆姿不自然',
    camera_settings: '参数设置', post_processing: '后期修图',
    no_subject: '找不到拍摄对象', no_time: '没时间拍',
  },
  skill_level: {
    beginner: '新手', intermediate: '进阶', advanced: '高级', pro: '专业',
  },
  expectations: {
    learn_photo: '学摄影', inspiration: '找灵感', better_composition: '提升构图',
    master_camera: '玩转相机', share_works: '分享作品', record_life: '记录生活',
  },
  common_scenes: {
    indoor_home: '家中', cafe: '咖啡馆', outdoor_park: '户外公园',
    street: '街头', travel: '旅行', office: '办公室', studio: '影棚',
  },
  shoot_frequency: {
    rarely: '偶尔', monthly: '每月', weekly: '每周', daily: '每天',
  },
};

const questionTitles: Record<string, string> = {
  source: '了解渠道',
  favorite_categories: '喜欢拍什么',
  pain_points: '拍摄烦恼',
  skill_level: '摄影水平',
  expectations: '期望收获',
  common_scenes: '常用场景',
  shoot_frequency: '拍摄频率',
};

function renderValue(field: string, value: unknown): React.ReactNode {
  if (value === null || value === undefined) {
    return <span className="text-muted-foreground text-xs">跳过</span>;
  }
  const map = labelMaps[field];
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return <span className="text-muted-foreground text-xs">跳过</span>;
    }
    return (
      <div className="flex flex-wrap gap-1">
        {value.map((v) => (
          <Badge key={v} variant="secondary">
            {map?.[v] || v}
          </Badge>
        ))}
      </div>
    );
  }
  return <Badge variant="outline">{map?.[value as string] || (value as string)}</Badge>;
}

export default async function QuestionnaireDetailPage({
  params,
}: {
  params: { deviceId: string };
}) {
  let data;
  try {
    data = await api.getQuestionnaireHistory(params.deviceId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Link
        href="/dashboard/questionnaire"
        className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={14} className="mr-1" /> 返回列表
      </Link>

      <div className="text-sm text-muted-foreground">
        设备 ID: <span className="font-mono">{params.deviceId}</span> · 共 {data.total} 次提交
      </div>

      {data.data.length === 0 ? (
        <div className="text-center text-muted-foreground py-8">该设备无问卷记录</div>
      ) : (
        <div className="space-y-6">
          {data.data.map((record, idx) => {
            let answers: Record<string, unknown> | null = null;
            try {
              answers = JSON.parse(record.answersJson) as Record<string, unknown>;
            } catch {
              // 忽略解析失败
            }
            return (
              <div key={record.id} className="rounded-md border border-border bg-card p-4">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-sm font-semibold">
                    第 {data.total - idx} 次提交
                    {idx === 0 && (
                      <Badge variant="default" className="ml-2">最新</Badge>
                    )}
                  </h3>
                  <span className="text-xs text-muted-foreground">
                    {formatUnixTime(record.submittedAt)} · IP: {record.clientIp || '—'}
                  </span>
                </div>
                {answers ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {Object.entries(questionTitles).map(([field, title]) => (
                      <div key={field} className="space-y-1">
                        <div className="text-xs text-muted-foreground">{title}</div>
                        <div>
                          {renderValue(field, answers![field])}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-destructive text-sm">答案解析失败</div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
