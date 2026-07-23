// src/components/dashboard-shell.tsx
'use client';

import { usePathname } from 'next/navigation';
import { Sidebar } from '@/components/sidebar';
import { Topbar } from '@/components/topbar';

const titleMap: Record<string, string> = {
  '/dashboard': '概览',
  '/dashboard/invites': '邀请记录',
  '/dashboard/redeem-batches': '兑换码批次',
  '/dashboard/rewards': '奖励明细',
};

function resolveTitle(pathname: string): string {
  if (titleMap[pathname]) return titleMap[pathname];
  if (pathname === '/dashboard/redeem-batches/new') return '创建批次';
  if (pathname.match(/\/dashboard\/redeem-batches\/\d+/)) return '批次详情';
  return 'Lumira 运营后台';
}

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const title = resolveTitle(pathname);

  return (
    <>
      <Sidebar activePath={pathname} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Topbar title={title} />
        <main className="flex-1 overflow-y-auto bg-background p-6">
          {children}
        </main>
      </div>
    </>
  );
}
