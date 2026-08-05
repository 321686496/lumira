// src/components/questionnaire-table.tsx
import Link from 'next/link';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { QuestionnaireListResponse } from '@/types/admin';

const sourceLabels: Record<string, string> = {
  app_store: '应用商店',
  social_media: '社交媒体',
  friend: '朋友推荐',
  search: '搜索引擎',
  article: '文章博客',
  other: '其他',
};

const skillLabels: Record<string, string> = {
  beginner: '新手',
  intermediate: '进阶',
  advanced: '高级',
  pro: '专业',
};

const categoryLabels: Record<string, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

function parseAnswers(json: string): Record<string, unknown> | null {
  try {
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function QuestionnaireTable({ data }: { data: QuestionnaireListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>设备</TableHead>
            <TableHead>别名</TableHead>
            <TableHead>提交时间</TableHead>
            <TableHead>渠道</TableHead>
            <TableHead>偏好分类</TableHead>
            <TableHead>摄影水平</TableHead>
            <TableHead>IP</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                无问卷记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => {
              const answers = parseAnswers(row.answersJson);
              const source = answers?.source as string | null | undefined;
              const favCats = (answers?.favorite_categories as string[]) || [];
              const skillLevel = answers?.skill_level as string | null | undefined;
              return (
                <TableRow key={row.id}>
                  <TableCell className="text-muted-foreground">{row.id}</TableCell>
                  <TableCell>
                    <Link
                      href={`/dashboard/questionnaire/${row.deviceId}`}
                      className="font-mono text-xs text-primary hover:underline"
                    >
                      {truncateDeviceId(row.deviceId)}
                    </Link>
                  </TableCell>
                  <TableCell className="text-sm">{row.deviceAlias || '—'}</TableCell>
                  <TableCell className="text-sm">{formatUnixTime(row.submittedAt)}</TableCell>
                  <TableCell>
                    {source ? (
                      <Badge variant="secondary">{sourceLabels[source] || source}</Badge>
                    ) : (
                      <span className="text-muted-foreground text-xs">跳过</span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs">
                    {favCats.length > 0
                      ? favCats.map((c) => categoryLabels[c] || c).join('、')
                      : '—'}
                  </TableCell>
                  <TableCell>
                    {skillLevel ? (
                      <Badge variant="outline">{skillLabels[skillLevel] || skillLevel}</Badge>
                    ) : (
                      <span className="text-muted-foreground text-xs">跳过</span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">{row.clientIp || '—'}</TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
