// src/app/dashboard/categories/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { CategoryManager } from '@/components/category-manager';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function CategoriesPage() {
  let categories;
  try {
    const resp = await api.listCategories();
    categories = resp.categories;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <CategoryManager categories={categories} backendUrl={BACKEND_URL} />
    </div>
  );
}
