// src/app/dashboard/templates/ai-tasks/[jobId]/page.tsx
// 生成任务详情页：数据由客户端组件 JobDetail 自行拉取并轮询，页面本身保持静态壳。
import { JobDetail } from '@/components/ai-create/job-detail';

export const dynamic = 'force-dynamic';

export default function AiTaskDetailPage({ params }: { params: { jobId: string } }) {
  return <JobDetail jobId={params.jobId} />;
}