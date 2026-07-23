// src/components/chart-card.tsx
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function ChartCard({
  title,
  description,
  children,
  className,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn('p-6', className)}>
      <div className="mb-4">
        <h3 className="text-base font-medium text-foreground text-left">{title}</h3>
        {description && (
          <p className="mt-1 text-sm text-muted-foreground text-left">{description}</p>
        )}
      </div>
      {children}
    </Card>
  );
}
