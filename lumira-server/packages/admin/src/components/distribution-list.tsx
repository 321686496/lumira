// src/components/distribution-list.tsx
// 通用占比条：展示若干个带标签+占比的横向条。

export function DistributionList({ items }: { items: Array<[string, number]> }) {
  const total = items.reduce((s, [, count]) => s + count, 0);
  if (!total || items.length === 0) {
    return <p className="text-sm text-muted-foreground text-left">暂无数据</p>;
  }
  return (
    <div className="space-y-2.5">
      {items.map(([label, count]) => {
        const pct = total > 0 ? Math.round((count / total) * 100) : 0;
        return (
          <div key={label}>
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground text-left">{label}</span>
              <span className="text-foreground">{count} · {pct}%</span>
            </div>
            <div className="mt-1 h-2 w-full rounded bg-muted">
              <div
                className="h-full rounded bg-primary"
                style={{ width: `${pct}%` }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}