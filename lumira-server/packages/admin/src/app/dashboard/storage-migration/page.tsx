// src/app/dashboard/storage-migration/page.tsx
// 图片存储迁移到 Cloudflare R2：后台交互式发起 / 进度 / 停止，完成后逐实体全校验出报告，
// 迁移记录存数据库，失败明细从服务器本地读取并展示。

import { api } from '@/lib/api';
import { MigrationClient } from './migration-client';
import type { MigrationRecordView, MigrationRunningView } from '@/types/admin';

export const dynamic = 'force-dynamic';

export default async function StorageMigrationPage() {
  let initialList: MigrationRecordView[] = [];
  let initialStatus: MigrationRunningView = { running: false };
  try {
    initialList = await api.listMigrations();
    initialStatus = await api.getMigrationStatus();
  } catch {
    // 后端不可用等场景：页面仍渲染，操作时再报错
  }

  return <MigrationClient initialList={initialList} initialStatus={initialStatus} />;
}