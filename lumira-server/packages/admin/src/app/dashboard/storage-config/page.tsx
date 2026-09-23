import { listStorageConfigAction } from './actions';
import StorageConfigClient from './storage-config-client';

export const metadata = {
  title: '存储配置',
};

export default async function StorageConfigPage() {
  const res = await listStorageConfigAction();
  const initial = res.ok ? res.data : [];
  return <StorageConfigClient initial={initial} />;
}