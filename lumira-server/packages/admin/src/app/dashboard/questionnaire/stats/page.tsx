// src/app/dashboard/questionnaire/stats/page.tsx
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import type { QuestionnaireStats } from '@/types/admin';

const questionConfig: Array<{
  field: keyof Omit<QuestionnaireStats, 'totalRespondents'>;
  title: string;
  labels: Record<string, string>;
}> = [
  {
    field: 'source',
    title: '了解渠道',
    labels: {
      app_store: '应用商店', social_media: '社交媒体', friend: '朋友推荐',
      search: '搜索引擎', article: '文章博客', other: '其他',
    },
  },
  {
    field: 'favorite_categories',
    title: '喜欢拍什么',
    labels: {
      portrait: '人像', landscape: '风光', food: '美食', street: '街拍',
      night: '夜景', macro: '微距', 'still-life': '静物',
    },
  },
  {
    field: 'pain_points',
    title: '拍摄烦恼',
    labels: {
      composition: '构图困难', lighting: '光线处理', posing: '摆姿不自然',
      camera_settings: '参数设置', post_processing: '后期修图',
      no_subject: '找不到拍摄对象', no_time: '没时间拍',
    },
  },
  {
    field: 'skill_level',
    title: '摄影水平',
    labels: {
      beginner: '新手', intermediate: '进阶', advanced: '高级', pro: '专业',
    },
  },
  {
    field: 'expectations',
    title: '期望收获',
    labels: {
      learn_photo: '学摄影', inspiration: '找灵感', better_composition: '提升构图',
      master_camera: '玩转相机', share_works: '分享作品', record_life: '记录生活',
    },
  },
  {
    field: 'common_scenes',
    title: '常用场景',
    labels: {
      indoor_home: '家中', cafe: '咖啡馆', outdoor_park: '户外公园',
      street: '街头', travel: '旅行', office: '办公室', studio: '影棚',
    },
  },
  {
    field: 'shoot_frequency',
    title: '拍摄频率',
    labels: {
      rarely: '偶尔', monthly: '每月', weekly: '每周', daily: '每天',
    },
  },
];

function DistributionCard({
  title,
  distribution,
  labels,
  totalRespondents,
}: {
  title: string;
  distribution: Record<string, number>;
  labels: Record<string, string>;
  totalRespondents: number;
}) {
  const entries = Object.entries(distribution).sort((a, b) => b[1] - a[1]);
  const max = entries.length > 0 ? entries[0][1] : 1;

  return (
    <div className="rounded-md border border-border bg-card p-4">
      <h3 className="text-sm font-semibold mb-3">{title}</h3>
      {entries.length === 0 ? (
        <div className="text-muted-foreground text-xs">暂无数据</div>
      ) : (
        <div className="space-y-2">
          {entries.map(([key, count]) => {
            const pct = totalRespondents > 0 ? (count / totalRespondents) * 100 : 0;
            const barWidth = max > 0 ? (count / max) * 100 : 0;
            return (
              <div key={key} className="flex items-center gap-2">
                <div className="w-20 text-xs text-muted-foreground shrink-0">
                  {labels[key] || key}
                </div>
                <div className="flex-1 h-5 bg-muted rounded relative overflow-hidden">
                  <div
                    className="h-full bg-primary/30 transition-all"
                    style={{ width: `${barWidth}%` }}
                  />
                </div>
                <div className="w-16 text-xs text-right shrink-0">
                  {count} ({pct.toFixed(1)}%)
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default async function QuestionnaireStatsPage() {
  let stats: QuestionnaireStats;
  try {
    stats = await api.getQuestionnaireStats();
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

      <div className="rounded-md border border-border bg-card p-6">
        <div className="text-sm text-muted-foreground mb-1">总响应人数</div>
        <div className="text-3xl font-bold">{stats.totalRespondents}</div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {questionConfig.map((config) => (
          <DistributionCard
            key={config.field}
            title={config.title}
            distribution={stats[config.field]}
            labels={config.labels}
            totalRespondents={stats.totalRespondents}
          />
        ))}
      </div>
    </div>
  );
}
