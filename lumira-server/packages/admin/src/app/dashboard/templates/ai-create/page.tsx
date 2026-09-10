// src/app/dashboard/templates/ai-create/page.tsx
// AI 一键建模向导页：上传示例图 → 识别回填 → 封面/剪影决策 → 提交
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { AiCreateWizard } from '@/components/ai-create/wizard';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

/**
 * Vercel serverless 函数时长上限（秒）：本页 server action 链路含 AI 生图（120s 请求
 * + 60s 轮询）与剪影 ONNX CPU 推理，默认时长（10~15s）会被掐断 → 前端永久"生成中"。
 */
export const maxDuration = 60;

export default async function AiCreatePage() {
  let categories;
  try {
    categories = (await api.listCategories()).categories;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <AiCreateWizard categories={categories} backendUrl={BACKEND_URL} />
    </div>
  );
}
