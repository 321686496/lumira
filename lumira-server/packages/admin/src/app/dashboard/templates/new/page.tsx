// src/app/dashboard/templates/new/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';
import TemplateForm from '@/components/template-form';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function NewTemplatePage() {
  let categories;
  try {
    const resp = await api.listCategories();
    categories = resp.categories;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">分类加载失败：{(e as Error).message}</div>;
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
          <CardTitle className="text-left">新建模板</CardTitle>
        </CardHeader>
        <CardContent>
          <TemplateForm categories={categories} backendUrl={BACKEND_URL} />
        </CardContent>
      </Card>
    </div>
  );
}
