// src/app/dashboard/scenes/page.tsx
import { redirect } from 'next/navigation';
import { api, getUsageStats } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { SceneManager } from '@/components/scene-manager';

export default async function ScenesPage() {
  let scenes;
  try {
    const resp = await api.listScenes();
    scenes = resp?.scenes ?? [];
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  // 使用次数 best-effort 读取（失败返回空，不影响列表）
  const usageArr = await getUsageStats('scene');
  const usage = Object.fromEntries(usageArr.map((u) => [u.itemId, u]));

  return (
    <div className="space-y-4">
      <SceneManager scenes={scenes} usage={usage} />
    </div>
  );
}