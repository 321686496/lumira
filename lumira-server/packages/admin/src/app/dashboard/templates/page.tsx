// src/app/dashboard/templates/page.tsx
import { redirect } from 'next/navigation';
import { api, getUsageStats, getBuiltinTemplates } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { TemplateCardGrid } from '@/components/template-card-grid';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function TemplatesPage() {
  let templates;
  let categories;
  try {
    const [tplResp, catResp] = await Promise.all([
      api.listTemplates({ pageSize: 200 }),
      api.listCategories(),
    ]);
    templates = tplResp.data;
    categories = catResp.categories;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  // 使用次数 best-effort 读取（失败返回空，不影响卡片展示）
  const usageArr = await getUsageStats('template');
  const usage = Object.fromEntries(usageArr.map((u) => [u.itemId, u]));

  // 内置模板（App 同步注册）；best-effort，失败返回空数组
  const builtinArr = await getBuiltinTemplates();

  return (
    <div>
      <TemplateCardGrid
        templates={templates}
        categories={categories}
        backendUrl={BACKEND_URL}
        usage={usage}
        builtinTemplates={builtinArr}
      />
    </div>
  );
}