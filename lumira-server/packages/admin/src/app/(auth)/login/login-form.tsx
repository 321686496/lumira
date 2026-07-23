// src/app/(auth)/login/login-form.tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { loginAction } from '@/actions/login';

export default function LoginForm({ redirectTo }: { redirectTo?: string }) {
  const router = useRouter();
  const [token, setToken] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await loginAction(token, redirectTo);
      if (result?.error) {
        setError(result.error);
      }
    });
  }

  return (
    <form onSubmit={handleSubmit} className="bg-card p-6 rounded-xl shadow-sm border border-border space-y-4">
      <div className="space-y-2">
        <Label htmlFor="adminToken" className="text-left block">管理员 Token</Label>
        <Input
          id="adminToken"
          type="password"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="输入 ADMIN_TOKEN"
          autoComplete="current-password"
          required
          autoFocus
        />
      </div>
      {error && (
        <p className="text-sm text-destructive" role="alert">{error}</p>
      )}
      <Button type="submit" disabled={isPending || !token} className="w-full">
        {isPending ? '验证中…' : '登录'}
      </Button>
    </form>
  );
}
