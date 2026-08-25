// src/components/topbar.tsx
import { SignOut } from '@phosphor-icons/react';
import { Button } from '@/components/ui/button';
import { logoutAction } from '@/actions/logout';

export function Topbar({ title }: { title: string }) {
  return (
    <header className="h-16 flex items-center justify-between px-6 bg-card border-b border-border">
      <h1 className="text-lg font-medium text-foreground text-left">{title}</h1>
      <form action={logoutAction}>
        <Button variant="ghost" size="sm" type="submit">
          <SignOut size={16} className="mr-2" />
          退出登录
        </Button>
      </form>
    </header>
  );
}
