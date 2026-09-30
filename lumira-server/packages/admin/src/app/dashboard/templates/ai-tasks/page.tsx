// src/app/dashboard/templates/ai-tasks/page.tsx
// 生成任务队列页：统一查看 AI 生成任务的排队/执行/失败状态。
// 数据由客户端组件 JobList 自行拉取（需轮询），故页面本身保持静态壳。
import { JobList } from '@/components/ai-create/job-list';

export const dynamic = 'force-dynamic';

export default function AiTasksPage() {
  return (
    <div className="space-y-4">
      <div className="space-y-1">
        <h1 className="text-2xl font-semibold">生成任务</h1>
        <p className="text-sm text-muted-foreground">
          这里汇总所有 AI 一键生成任务，可查看排队位次与执行进度，并停止、继续或删除任务。
        </p>
      </div>
      <JobList />
    </div>
  );
}