import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import sharp from 'sharp';
import { NotFoundException } from '@nestjs/common';
import { ThumbsService } from './thumbs.service';

describe('ThumbsService template variants', () => {
  let uploadDir: string;
  let service: ThumbsService;

  beforeEach(() => {
    uploadDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lumira-thumbs-'));
    process.env.UPLOAD_DIR = uploadDir;
    service = new ThumbsService({} as never);
  });

  afterEach(() => {
    fs.rmSync(uploadDir, { recursive: true, force: true });
  });

  it('generates and caches a webp variant with the requested width', async () => {
    const sourceDir = path.join(uploadDir, 'templates', 'srv_test');
    fs.mkdirSync(sourceDir, { recursive: true });
    await sharp({
      create: { width: 300, height: 200, channels: 3, background: 'red' },
    })
      .png()
      .toFile(path.join(sourceDir, 'image_0.png'));

    const first = await service.templateImage('srv_test', 'image_0.png', '220');
    expect(first.type).toBe('image/webp');
    expect((await sharp(first.data).metadata()).width).toBe(220);
    expect(
    fs.existsSync(path.join(uploadDir, 'thumbs', 'templates', 'srv_test', 'image_0.w220.webp')),
    ).toBe(true);

    const second = await service.templateImage('srv_test', 'image_0.png', '220');
    expect(second.data.equals(first.data)).toBe(true);
  });

  it('rejects path traversal', async () => {
    await expect(
      service.templateImage('srv_test', '../other/image_0.png', '220'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
