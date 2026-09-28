// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.spec.ts
import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import sharp from 'sharp';
import { hashBuffer, hashUrl, cleanupResearchImages, writeResearchImage, readResearchImage, researchDir } from './research-image-store';

/** 生成一张纯色 PNG（指定边长） */
async function makePng(size: number): Promise<Buffer> {
  return sharp({ create: { width: size, height: size, channels: 3, background: { r: 200, g: 120, b: 80 } } })
    .png()
    .toBuffer();
}

describe('research-image-store', () => {
  const originalUploadDir = process.env.UPLOAD_DIR;
  let tmp: string;

  beforeEach(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-research-'));
    process.env.UPLOAD_DIR = tmp;
  });

  afterEach(async () => {
    if (originalUploadDir === undefined) delete process.env.UPLOAD_DIR;
    else process.env.UPLOAD_DIR = originalUploadDir;
    await fs.rm(tmp, { recursive: true, force: true });
  });

  it('hashUrl 稳定且为 16 位 hex', () => {
    expect(hashUrl('https://a.com/1.jpg')).toBe(hashUrl('https://a.com/1.jpg'));
    expect(hashUrl('https://a.com/1.jpg')).toMatch(/^[0-9a-f]{16}$/);
  });

  it('内容哈希与 URL 哈希不同键', () => {
    expect(hashBuffer(Buffer.from('abc'))).not.toBe(hashBuffer(Buffer.from('abd')));
  });

  it('尺寸达标的图压缩落盘为 jpg，长边 ≤1280', async () => {
    const id = 'id-ok';
    const written = await writeResearchImage(id, await makePng(800));
    expect(written).not.toBeNull();
    expect(written!.url).toContain('/uploads/research/id-ok.jpg');
    expect(Math.max(written!.width, written!.height)).toBeLessThanOrEqual(1280);
    const back = await readResearchImage(id);
    expect(back).not.toBeNull();
  });

  it('长边超 1280 会被下采样', async () => {
    const written = await writeResearchImage('id-big', await makePng(2400));
    expect(written!.width).toBeLessThanOrEqual(1280);
    expect(written!.height).toBeLessThanOrEqual(1280);
  });

  it('任一边 <400px → null（画面太小不用）', async () => {
    expect(await writeResearchImage('id-small', await makePng(200))).toBeNull();
  });

  it('cleanupResearchImages 删过期保留未过期', async () => {
    const dir = researchDir();
    await fs.mkdir(dir, { recursive: true });
    const oldFile = path.join(dir, 'old.jpg');
    const newFile = path.join(dir, 'new.jpg');
    await fs.writeFile(oldFile, Buffer.from('x'));
    await fs.writeFile(newFile, Buffer.from('y'));
    const past = new Date(Date.now() - 10 * 24 * 3600 * 1000);
    await fs.utimes(oldFile, past, past);

    const removed = await cleanupResearchImages(7);
    expect(removed).toBe(1);
    await expect(fs.stat(oldFile)).rejects.toThrow();
    await expect(fs.stat(newFile)).resolves.toBeTruthy();
  });
});
