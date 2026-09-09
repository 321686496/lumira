// src/app/dashboard/banners/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { BannerManager } from '@/components/banner-manager';

export default async function BannersPage() {
  let banners;
  try {
    banners = await api.listBanners();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <BannerManager banners={banners} />
    </div>
  );
}
