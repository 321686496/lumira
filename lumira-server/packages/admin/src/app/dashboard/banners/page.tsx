// src/app/dashboard/banners/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { BannerManager } from '@/components/banner-manager';
import type { AdminTemplateListItem } from '@/types/admin';

export default async function BannersPage() {
  let banners;
  try {
    banners = await api.listBanners();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  // 运营 Banner 可配「跳转到指定模板详情页」，提供启用模板列表供可视化选择
  let templates: AdminTemplateListItem[] = [];
  try {
    const list = await api.listTemplates({ pageSize: 200, isActive: true });
    templates = list.data;
  } catch {
    // 模板列表拉取失败不阻塞 Banner 管理（仅模板详情路由选择器不可用）
  }

  return (
    <div className="space-y-4">
      <BannerManager banners={banners} templates={templates} />
    </div>
  );
}
