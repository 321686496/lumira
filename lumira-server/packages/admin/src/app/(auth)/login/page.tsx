// src/app/(auth)/login/page.tsx
import { Suspense } from 'react';
import LoginForm from './login-form';
import { ChartLineUp } from '@phosphor-icons/react/dist/ssr/ChartLineUp';

export default async function LoginPage({
  searchParams,
}: {
  searchParams: { from?: string };
}) {
  return (
    <main className="min-h-screen flex items-center justify-center bg-gradient-to-br from-background to-secondary">
      <div className="w-full max-w-md mx-4">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 text-primary mb-4">
            <ChartLineUp size={28} weight="duotone" />
          </div>
          <h1 className="text-2xl font-semibold text-foreground text-left">Lumira 运营后台</h1>
          <p className="mt-2 text-sm text-muted-foreground text-left">请输入管理员 Token 登录</p>
        </div>
        <Suspense fallback={<div className="text-center text-muted-foreground">加载中…</div>}>
          <LoginForm redirectTo={searchParams.from} />
        </Suspense>
      </div>
    </main>
  );
}
