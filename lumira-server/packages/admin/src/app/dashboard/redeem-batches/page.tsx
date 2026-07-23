// src/app/dashboard/redeem-batches/page.tsx
import Link from 'next/link';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Plus } from '@phosphor-icons/react/dist/ssr';
import { BatchesTable } from '@/components/batches-table';

export default async function RedeemBatchesPage() {
  let batches;
  try {
    batches = await api.getBatches();
  } catch (e) {
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button asChild>
          <Link href="/dashboard/redeem-batches/new">
            <Plus size={16} className="mr-1" /> 创建批次
          </Link>
        </Button>
      </div>
      <BatchesTable batches={batches} />
    </div>
  );
}
