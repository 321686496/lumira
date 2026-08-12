import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { MagnifyingGlass } from '@phosphor-icons/react/dist/ssr';
import { DevicesTable } from '@/components/devices-table';
import { Pagination } from '@/components/pagination';

export default async function DevicesPage({
  searchParams,
}: {
  searchParams: { page?: string; pageSize?: string; search?: string };
}) {
  const page = Number(searchParams.page) || 1;
  const pageSize = Number(searchParams.pageSize) || 20;
  const search = searchParams.search;

  let data;
  try {
    data = await api.getDevices({ page, pageSize, search });
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <form className="flex gap-2 items-end">
        <div className="flex-1 max-w-xs">
          <label className="text-sm text-muted-foreground mb-1 block">搜索设备</label>
          <Input
            name="search"
            defaultValue={search}
            placeholder="设备ID、用户名、别名、平台、型号"
          />
        </div>
        <Button type="submit" size="sm">
          <MagnifyingGlass size={14} className="mr-1" /> 搜索
        </Button>
      </form>

      <DevicesTable data={data} />

      <Pagination
        page={page}
        pageSize={pageSize}
        total={data.total}
        basePath="/dashboard/devices"
        searchParams={searchParams}
      />
    </div>
  );
}
