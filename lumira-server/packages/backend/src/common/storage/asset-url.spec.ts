// lumira-server/packages/backend/src/common/storage/asset-url.spec.ts
// buildAssetUrl 单测：相对 key / 旧绝对 URL 跟随激活存储 / 外部 URL 原样返回。

import { buildAssetUrl } from './asset-url';
import { seedAdapter, setRuntimeConfig } from './runtime-storage';
import { LocalStorageAdapter } from './local-storage.adapter';

const OLD_DOMAIN = 'https://lumira.iwtle.top';
const QINIU_DOMAIN = 'https://lumiraoss.iwtle.top';

/** setRuntimeConfig 切换远端存储前需已有适配器（生产由 StorageConfigService seed），测试占位 */
function activateQiniu(): void {
  seedAdapter('qiniu', new LocalStorageAdapter());
  setRuntimeConfig('qiniu', QINIU_DOMAIN);
}

describe('buildAssetUrl', () => {
  const envBackup = process.env.BACKEND_PUBLIC_URL;

  beforeEach(() => {
    process.env.BACKEND_PUBLIC_URL = OLD_DOMAIN;
  });

  afterAll(() => {
    if (envBackup === undefined) delete process.env.BACKEND_PUBLIC_URL;
    else process.env.BACKEND_PUBLIC_URL = envBackup;
    setRuntimeConfig('local', OLD_DOMAIN);
  });

  it('空值 → 空字符串', () => {
    expect(buildAssetUrl(null)).toBe('');
    expect(buildAssetUrl(undefined)).toBe('');
    expect(buildAssetUrl('')).toBe('');
  });

  it('相对 key：激活=本地 → 拼 BACKEND_PUBLIC_URL', () => {
    setRuntimeConfig('local', OLD_DOMAIN);
    expect(buildAssetUrl('/uploads/templates/a/cover.jpg')).toBe(
      `${OLD_DOMAIN}/uploads/templates/a/cover.jpg`,
    );
  });

  it('相对 key：激活=七牛 → 拼七牛公网 URL', () => {
    activateQiniu();
    expect(buildAssetUrl('/uploads/templates/a/cover.jpg')).toBe(
      `${QINIU_DOMAIN}/uploads/templates/a/cover.jpg`,
    );
  });

  it('旧绝对 URL（自己后端域名）：激活=本地 → 保持不变', () => {
    setRuntimeConfig('local', OLD_DOMAIN);
    expect(buildAssetUrl(`${OLD_DOMAIN}/uploads/templates/a/cover.jpg`)).toBe(
      `${OLD_DOMAIN}/uploads/templates/a/cover.jpg`,
    );
  });

  it('旧绝对 URL（自己后端域名）：激活=七牛 → 重建为七牛域名', () => {
    activateQiniu();
    expect(buildAssetUrl(`${OLD_DOMAIN}/uploads/templates/a/cover.jpg`)).toBe(
      `${QINIU_DOMAIN}/uploads/templates/a/cover.jpg`,
    );
    expect(buildAssetUrl(`${OLD_DOMAIN}/uploads/categories/portrait/icon.png`)).toBe(
      `${QINIU_DOMAIN}/uploads/categories/portrait/icon.png`,
    );
  });

  it('localhost 旧绝对 URL：激活=七牛 → 重建为七牛域名', () => {
    activateQiniu();
    expect(buildAssetUrl('http://localhost:3000/uploads/templates/a/cover.jpg')).toBe(
      `${QINIU_DOMAIN}/uploads/templates/a/cover.jpg`,
    );
  });

  it('外部完整 URL（非自己域名）→ 原样返回', () => {
    activateQiniu();
    expect(buildAssetUrl('https://cdn.example.com/other.png')).toBe('https://cdn.example.com/other.png');
    // 自己域名但非 /uploads/ 路径 → 原样返回（后端 API 地址仍有效）
    expect(buildAssetUrl(`${OLD_DOMAIN}/api/v1/thumbs/x`)).toBe(`${OLD_DOMAIN}/api/v1/thumbs/x`);
  });
});
