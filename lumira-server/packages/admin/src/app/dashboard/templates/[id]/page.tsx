// src/app/dashboard/templates/[id]/page.tsx
import { notFound, redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';
import TemplateForm from '@/components/template-form';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function TemplateDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const id = params.id;
  if (!id) notFound();

  let detail;
  let categories;
  try {
    [detail, categories] = await Promise.all([
      api.getTemplate(id),
      api.listCategories(),
    ]);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    if ((e as Error).message.includes('404')) notFound();
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Button asChild variant="ghost" size="sm">
        <Link href="/dashboard/templates">
          <ArrowLeft size={14} className="mr-1" /> 返回列表
        </Link>
      </Button>

      <Card>
        <CardHeader>
          <CardTitle className="text-left">
            编辑模板：{detail.name}
            <span className="ml-2 text-xs text-muted-foreground font-normal">{detail.id}</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <TemplateForm
            categories={categories.categories}
            initial={detail}
            templateId={detail.id}
            backendUrl={BACKEND_URL}
          />
        </CardContent>
      </Card>
    </div>
  );
}
