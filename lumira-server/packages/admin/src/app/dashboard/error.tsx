'use client';

// dashboard 段级错误边界：客户端导航/渲染崩溃（如 RSC 拉取失败、
// 部署切换瞬间的 chunk 失配）时保留后台布局，提供重试与回首页。
import { useEffect } from 'react';
import Link from 'next/link';

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('[dashboard-error]', error);
  }, [error]);

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-6">
      <div className="w-full max-w-sm space-y-4 text-center">
        <h2 className="text-lg font-semibold text-foreground">页面加载失败</h2>
        <p className="text-sm text-muted-foreground">
          页面渲染时发生异常，可尝试重试；若刚完成发版，刷新页面即可恢复。
        </p>
        {error.digest ? (
          <p className="text-xs text-muted-foreground/70">
            错误标识：{error.digest}
          </p>
        ) : null}
        <div className="flex justify-center gap-2">
          <button
            type="button"
            onClick={reset}
            className="inline-flex h-9 items-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
          >
            重试
          </button>
          <Link
            href="/dashboard"
            className="inline-flex h-9 items-center rounded-md border border-input bg-background px-4 text-sm font-medium hover:bg-accent"
          >
            返回首页
          </Link>
        </div>
      </div>
    </div>
  );
}
