// src/app/dashboard/notifications/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { NotificationManager } from '@/components/notification-manager';

export default async function NotificationsPage() {
  let notifications;
  try {
    notifications = await api.listNotifications();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <NotificationManager notifications={notifications} />
    </div>
  );
}