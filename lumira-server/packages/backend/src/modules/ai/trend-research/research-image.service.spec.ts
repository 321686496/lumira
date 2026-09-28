import * as os from 'node:os';
import * as path from 'node:path';
import { promises as fs } from 'node:fs';
import sharp from 'sharp';
import { ResearchImageService } from './research-image.service';
import { DEFAULT_RESEARCH_IMAGES_CONFIG } from './research-image';
import type { ResearchImagesConfig } from './research-image';
import type { ResearchItem } from './research-item';

/** 最小 AiConfigService 替身：TTL 用默认 */
const fakeConfig = { getSearchConfig: async () => null } as never;

async function makePng(size = 800): Promise<Buffer> {
  return sharp({ create: { width: size, height: size, channels: 3, background: { r: 10, g: 20, b: 30 } } })
    .png()
    .toBuffer();
}

function item(partial: Partial<ResearchItem>): ResearchItem {
  return { source: 'searxng', title: 't', snippet: 's', keywords: [], ...partial };
}

const cfg = (over: Partial<ResearchImagesConfig> = {}): ResearchImagesConfig => ({
  ...DEFAULT_RESEARCH_IMAGES_CONFIG,
  enabled: true,
  ...over,
});

describe('ResearchImageService.collect', () => {
  let tmp: string;
  const originalUploadDir = process.env.UPLOAD_DIR;

  beforeEach(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-rimg-'));
    process.env.UPLOAD_DIR = tmp;
  });
  afterEach(async () => {
    if (originalUploadDir === undefined) delete process.env.UPLOAD_DIR;
    else process.env.UPLOAD_DIR = originalUploadDir;
    await fs.rm(tmp, { recursive: true, force: true });
  });

  it('第一层：条目 imgUrl 命中并落盘', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg', url: 'https://a.com/p' })],
      queries: ['旗袍'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('metadata');
    expect(res.images[0].source).toBe('searxng');
    expect(res.images[0].query).toBe('旗袍');
  });

  it('同一 URL 只保留一张（URL 去重）', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/1.jpg' })],
      queries: ['x'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
  });

  it('max 截断：命中上限后不再抓后续层', async () => {
    const svc = new ResearchImageService(fakeConfig);
    let called = 0;
    // 两张图内容需不同：内容哈希去重会把同内容的图合并为一张
    svc.fetchImage = async () => {
      called += 1;
      return { buffer: await makePng(800 + called), mime: 'image/png' };
    };
    svc.fetchPage = async () => '<html></html>';
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/2.jpg' }), item({ url: 'https://b.com/p' })],
      queries: ['x'],
      cfg: cfg({ max: 2 }),
    });
    expect(res.images).toHaveLength(2);
    expect(called).toBe(2);
  });

  it('第二层：条目无图时抓页面 og:image', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => '<meta property="og:image" content="https://cdn.b.com/o.jpg">';
    const res = await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['x'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('page');
    expect(res.images[0].pageUrl).toBe('https://b.com/p');
  });

  it('第二层抓页失败：记 errors 且不阻断', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => {
      throw new Error('页面抓取失败（HTTP 403）');
    };
    const res = await svc.collect({ items: [item({ url: 'https://b.com/p' })], queries: ['x'], cfg: cfg() });
    expect(res.images).toHaveLength(0);
    expect(res.errors.length).toBeGreaterThan(0);
  });

  it('第三层：图片搜索兜底（仅在前两层不足时触发）', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => 'no-image-here';
    let searchQuery = '';
    const res = await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['旗袍'],
      imagesSearch: async (q) => {
        searchQuery = q;
        return [item({ imgUrl: 'https://img.c.com/x.jpg', source: 'searxng' })];
      },
      cfg: cfg(),
    });
    expect(searchQuery).toBe('旗袍');
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('image-search');
  });

  it('第三层关闭时不调用图片搜索', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => 'no-image';
    let called = false;
    await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['x'],
      imagesSearch: async () => {
        called = true;
        return [];
      },
      cfg: cfg({ searchFallback: false }),
    });
    expect(called).toBe(false);
  });

  it('单张图拦截（SSRF / 类型）静默跳过且不记 errors', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => {
      throw new Error('目标地址位于内网，已拦截');
    };
    const res = await svc.collect({ items: [item({ imgUrl: 'https://a.com/1.jpg' })], queries: ['x'], cfg: cfg() });
    expect(res.images).toHaveLength(0);
    expect(res.errors).toHaveLength(0);
  });

  it('软预算耗尽后停止抓取并使用已得结果', async () => {
    const svc = new ResearchImageService(fakeConfig);
    let t = 0;
    svc.fetchImage = async () => {
      t += 15_000;
      return { buffer: await makePng(), mime: 'image/png' };
    };
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/2.jpg' }), item({ imgUrl: 'https://a.com/3.jpg' })],
      queries: ['x'],
      cfg: cfg(),
      now: () => t,
    });
    expect(res.images.length).toBeLessThanOrEqual(2);
  });
});

describe('ResearchImageService.readBase64', () => {
  it('读回 jpeg base64', async () => {
    const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-rimg2-'));
    const original = process.env.UPLOAD_DIR;
    process.env.UPLOAD_DIR = tmp;
    try {
      const svc = new ResearchImageService(fakeConfig);
      svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
      const res = await svc.collect({ items: [item({ imgUrl: 'https://a.com/1.jpg' })], queries: ['x'], cfg: cfg() });
      const id = res.images[0].id;
      const loaded = await svc.readBase64(id);
      expect(loaded?.mime).toBe('image/jpeg');
      expect(loaded?.base64.length).toBeGreaterThan(100);
      expect(await svc.readBase64('0000000000000000')).toBeNull();
    } finally {
      if (original === undefined) delete process.env.UPLOAD_DIR;
      else process.env.UPLOAD_DIR = original;
      await fs.rm(tmp, { recursive: true, force: true });
    }
  });
});
