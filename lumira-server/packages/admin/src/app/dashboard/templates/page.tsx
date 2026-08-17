// src/app/dashboard/templates/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
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

  return (
    <div>
      <TemplateCardGrid
        templates={templates}
        categories={categories}
        backendUrl={BACKEND_URL}
      />
    </div>
  );
}