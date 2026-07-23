// src/components/stats-card.tsx
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function StatsCard({
  label,
  value,
  icon: Icon,
  hint,
  className,
}: {
  label: string;
  value: number | string;
  icon?: React.ComponentType<{ size?: number | string; className?: string }>;
  hint?: string;
  className?: string;
}) {
  return (
    <Card className={cn('p-5', className)}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-muted-foreground text-left">{label}</p>
          <p className="mt-2 text-2xl font-semibold text-foreground text-left">{value}</p>
        </div>
        {Icon && (
          <div className="p-2 rounded-lg bg-primary/10 text-primary">
            <Icon size={20} />
          </div>
        )}
      </div>
      {hint && (
        <p className="mt-2 text-xs text-muted-foreground text-left">{hint}</p>
      )}
    </Card>
  );
}
