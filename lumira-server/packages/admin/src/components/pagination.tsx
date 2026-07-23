// src/components/pagination.tsx
import { Button } from '@/components/ui/button';
import { CaretLeft, CaretRight } from '@phosphor-icons/react/dist/ssr';

export function Pagination({
  page,
  pageSize,
  total,
  basePath,
  searchParams,
}: {
  page: number;
  pageSize: number;
  total: number;
  basePath: string;
  searchParams: Record<string, string | undefined>;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const hasPrev = page > 1;
  const hasNext = page < totalPages;

  function buildUrl(pageNum: number): string {
    const params = new URLSearchParams();
    Object.entries(searchParams).forEach(([k, v]) => {
      if (v !== undefined && k !== 'page') params.set(k, v);
    });
    params.set('page', String(pageNum));
    params.set('pageSize', String(pageSize));
    return `${basePath}?${params.toString()}`;
  }

  return (
    <div className="flex items-center justify-between mt-4">
      <span className="text-sm text-muted-foreground">
        共 {total} 条 · 第 {page} / {totalPages} 页
      </span>
      <div className="flex gap-2">
        <Button asChild variant="outline" size="sm" disabled={!hasPrev}>
          <a href={buildUrl(page - 1)}>
            <CaretLeft size={14} className="mr-1" /> 上一页
          </a>
        </Button>
        <Button asChild variant="outline" size="sm" disabled={!hasNext}>
          <a href={buildUrl(page + 1)}>
            下一页 <CaretRight size={14} className="ml-1" />
          </a>
        </Button>
      </div>
    </div>
  );
}
