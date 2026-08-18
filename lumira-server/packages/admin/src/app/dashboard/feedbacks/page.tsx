// src/app/dashboard/feedbacks/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { FeedbackManager } from '@/components/feedback-manager';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function FeedbacksPage() {
  let data;
  try {
    data = await api.listFeedbacks({ page: 1, pageSize: 20 });
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }
  return (
    <div className="space-y-4">
      <FeedbackManager initialData={data} backendUrl={BACKEND_URL} />
    </div>
  );
}