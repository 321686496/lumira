// src/app/dashboard/templates/page.tsx
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { Plus } from '@phosphor-icons/react/dist/ssr';
import { TemplateListTable } from '@/components/template-list-table';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function TemplatesPage() {
  let templates;
  try {
    const resp = await api.listTemplates({ pageSize: 200 });
    templates = resp.data;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button asChild>
          <Link href="/dashboard/templates/new">
            <Plus size={16} className="mr-1" /> 新建模板
          </Link>
        </Button>
      </div>
      <TemplateListTable templates={templates} backendUrl={BACKEND_URL} />
    </div>
  );
}
