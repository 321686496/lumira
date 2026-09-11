// lumira-server/packages/backend/src/common/storage/image-compression.service.ts

import { BadRequestException, Injectable } from '@nestjs/common';
import sharp from 'sharp';

export interface CompressedImage {
  buffer: Buffer;
  ext: string;
  changed: boolean;
}

export interface ImageCompressionOptions {
  maxDim?: number;
  quality?: number;
  skipBytes?: number;
}

const DEFAULT_MAX_DIM = 1600;
const DEFAULT_QUALITY = 80;
const DEFAULT_SKIP_BYTES = 256 * 1024;

const IMAGE_MIME_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/svg+xml': 'svg',
  'image/gif': 'gif',
};

const LOSSLESS_EXTS = new Set(['svg', 'gif']);

/** 后端图片上传统一压缩：位图重编码为 WebP，矢量/动图与过小文件保持原样。 */
@Injectable()
export class ImageCompressionService {
  async compress(
    buffer: Buffer,
    filename: string,
    mimetype: string,
    options: ImageCompressionOptions = {},
  ): Promise<CompressedImage> {
    const ext = this.resolveExt(filename, mimetype);
    if (LOSSLESS_EXTS.has(ext) || buffer.length === 0) {
      return { buffer, ext, changed: false };
    }

    try {
      const image = sharp(buffer, { failOn: 'error' });
      const metadata = await image.metadata();
      if (!metadata.width || !metadata.height) {
        throw new Error('Missing image dimensions');
      }

      const skipBytes = options.skipBytes ?? DEFAULT_SKIP_BYTES;
      if (buffer.length <= skipBytes) {
        return { buffer, ext, changed: false };
      }

      const maxDim = options.maxDim ?? DEFAULT_MAX_DIM;
      const quality = options.quality ?? DEFAULT_QUALITY;
      const output = await image
        .rotate()
        .resize({ width: maxDim, height: maxDim, fit: 'inside', withoutEnlargement: true })
        .webp({ quality })
        .toBuffer();

      return { buffer: output, ext: 'webp', changed: true };
    } catch {
      throw new BadRequestException('图片解码失败，请上传有效的 jpg/png/webp 图片');
    }
  }

  private resolveExt(filename: string, mimetype: string): string {
    const dot = filename.lastIndexOf('.');
    if (dot >= 0) {
      const ext = filename.slice(dot + 1).toLowerCase();
      if (/^[a-z0-9]+$/.test(ext)) return ext;
    }
    return IMAGE_MIME_EXT[mimetype] || 'bin';
  }
}
