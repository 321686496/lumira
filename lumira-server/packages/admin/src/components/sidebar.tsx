// src/components/sidebar.tsx
import Link from 'next/link';
import {
  ChartLineUp, Users, Ticket, Gift, ClipboardText,
  SquaresFour, GridFour, DeviceMobile, ChatCircleText,
} from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';

const navItems = [
  { href: '/dashboard', label: '概览', icon: ChartLineUp },
  { href: '/dashboard/devices', label: '设备统计', icon: DeviceMobile },
  { href: '/dashboard/invites', label: '邀请记录', icon: Users },
  { href: '/dashboard/redeem-batches', label: '兑换码', icon: Ticket },
  { href: '/dashboard/rewards', label: '奖励明细', icon: Gift },
  { href: '/dashboard/questionnaire', label: '问卷数据', icon: ClipboardText },
  { href: '/dashboard/feedbacks', label: '反馈管理', icon: ChatCircleText },
  { href: '/dashboard/templates', label: '模板管理', icon: SquaresFour },
  { href: '/dashboard/categories', label: '分类管理', icon: GridFour },
];

export function Sidebar({ activePath }: { activePath: string }) {
  return (
    <aside className="hidden md:flex flex-col w-56 bg-card border-r border-border">
      <div className="p-6">
        <span className="text-lg font-semibold text-foreground">Lumira</span>
      </div>
      <nav className="flex-1 px-3 space-y-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = item.href === '/dashboard'
            ? activePath === '/dashboard'
            : activePath === item.href || activePath.startsWith(item.href + '/');
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors',
                active
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:bg-accent/40 hover:text-foreground'
              )}
            >
              <Icon size={18} weight={active ? 'fill' : 'regular'} />
              <span className="text-left">{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
