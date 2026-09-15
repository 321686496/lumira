'use client';

// 全局兜底错误边界：捕获根布局以下的客户端异常（含 React #482 等
// App Router 内部渲染崩溃），避免整站白屏 "Application error"。
// 渲染在 <html>/<body> 之外，必须自带 html/body 标签。
import { useEffect } from 'react';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('[global-error]', error);
  }, [error]);

  return (
    <html lang="zh-CN">
      <body className="flex min-h-screen items-center justify-center bg-background p-6">
        <div className="w-full max-w-sm space-y-4 text-center">
          <h2 className="text-lg font-semibold text-foreground">页面出错了</h2>
          <p className="text-sm text-muted-foreground">
            客户端渲染发生异常，请重试；若持续出现可尝试刷新或重新登录。
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
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="inline-flex h-9 items-center rounded-md border border-input bg-background px-4 text-sm font-medium hover:bg-accent"
            >
              刷新页面
            </button>
          </div>
        </div>
      </body>
    </html>
  );
}
