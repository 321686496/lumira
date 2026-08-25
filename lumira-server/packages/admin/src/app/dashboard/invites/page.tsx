// src/app/(dashboard)/invites/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { MagnifyingGlass } from '@phosphor-icons/react/dist/ssr/MagnifyingGlass';
import { InvitesTable } from '@/components/invites-table';
import { Pagination } from '@/components/pagination';

export default async function InvitesPage({
  searchParams,
}: {
  searchParams: { page?: string; pageSize?: string; deviceId?: string };
}) {
  const page = Number(searchParams.page) || 1;
  const pageSize = Number(searchParams.pageSize) || 20;
  const deviceId = searchParams.deviceId;

  let data;
  try {
    data = await api.getInvites({ page, pageSize, deviceId });
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <form className="flex gap-2 items-end">
        <div className="flex-1 max-w-xs">
          <label className="text-sm text-muted-foreground mb-1 block">按设备 ID 筛选</label>
          <Input
            name="deviceId"
            defaultValue={deviceId}
            placeholder="输入完整或部分 device_id"
          />
        </div>
        <Button type="submit" size="sm">
          <MagnifyingGlass size={14} className="mr-1" /> 搜索
        </Button>
      </form>

      <InvitesTable data={data} />

      <Pagination
        page={page}
        pageSize={pageSize}
        total={data.total}
        basePath="/dashboard/invites"
        searchParams={searchParams}
      />
    </div>
  );
}
