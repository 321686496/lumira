export default function DashboardLoading() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="rounded-lg border border-border bg-card p-6 space-y-3">
            <div className="h-4 bg-muted animate-pulse rounded w-20" />
            <div className="h-8 bg-muted animate-pulse rounded w-16" />
            <div className="h-3 bg-muted animate-pulse rounded w-24" />
          </div>
        ))}
      </div>
      <div className="rounded-lg border border-border bg-card p-6 space-y-4">
        <div className="h-5 bg-muted animate-pulse rounded w-32" />
        <div className="h-64 bg-muted animate-pulse rounded" />
      </div>
    </div>
  );
}
