// src/app/dashboard/redeem-batches/new/page.tsx
import { redirect } from 'next/navigation';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import BatchForm from '@/components/batch-form';

export default async function NewBatchPage() {
  let templates: Awaited<ReturnType<typeof api.getBatchTemplates>> = [];
  try {
    templates = await api.getBatchTemplates();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
  }

  return (
    <Card className="max-w-3xl">
      <CardHeader>
        <CardTitle className="text-left">创建兑换码批次</CardTitle>
      </CardHeader>
      <CardContent>
        <BatchForm templates={templates} />
      </CardContent>
    </Card>
  );
}
