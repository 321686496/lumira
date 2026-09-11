import sharp from 'sharp';
import { randomBytes } from 'crypto';
import { BadRequestException } from '@nestjs/common';
import { ImageCompressionService } from './image-compression.service';

async function createPng(width: number, height: number): Promise<Buffer> {
  if (width >= 2000) {
    return sharp(randomBytes(width * height * 3), {
      raw: { width, height, channels: 3 },
    }).png().toBuffer();
  }
  return sharp({
    create: { width, height, channels: 3, background: { r: 96, g: 128, b: 192 } },
  }).png().toBuffer();
}

describe('ImageCompressionService', () => {
  it('large bitmaps are re-encoded as webp and limited to the max dimension', async () => {
    const service = new ImageCompressionService();
    const source = await createPng(2400, 1200);
    const result = await service.compress(source, 'cover.png', 'image/png');

    expect(result.ext).toBe('webp');
    expect(result.changed).toBe(true);
    const metadata = await sharp(result.buffer).metadata();
    expect(metadata.format).toBe('webp');
    expect(metadata.width).toBe(1600);
    expect(metadata.height).toBe(800);
  });

  it('small images keep their original bytes and extension', async () => {
    const service = new ImageCompressionService();
    const source = await createPng(64, 48);
    const result = await service.compress(source, 'icon.png', 'image/png');

    expect(result.buffer).toBe(source);
    expect(result.ext).toBe('png');
    expect(result.changed).toBe(false);
  });

  it('svg files are stored unchanged', async () => {
    const service = new ImageCompressionService();
    const source = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"/>');
    const result = await service.compress(source, 'icon.svg', 'image/svg+xml');

    expect(result.buffer).toBe(source);
    expect(result.ext).toBe('svg');
    expect(result.changed).toBe(false);
  });

  it('rejects buffers that cannot be decoded as bitmaps', async () => {
    const service = new ImageCompressionService();
    const source = Buffer.alloc(300 * 1024, 1);

    await expect(service.compress(source, 'image.png', 'image/png'))
      .rejects.toThrow(BadRequestException);
  });
});
