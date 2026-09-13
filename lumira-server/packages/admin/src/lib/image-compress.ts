// 客户端图片压缩：把上传图缩放到指定最长边，并按目标体积逐步降质。
export function compressImage(
  file: File,
  opts: { maxDim?: number; quality?: number; maxBytes?: number } = {},
): Promise<File> {
  const { maxDim = 1024, quality = 0.8, maxBytes } = opts;
  const belowThreshold = maxBytes ? file.size <= maxBytes : file.size <= 256 * 1024;
  if (file.type === 'image/svg+xml' || belowThreshold) {
    return Promise.resolve(file);
  }

  return (async () => {
    let bitmap: ImageBitmap;
    try {
      bitmap = await createImageBitmap(file);
    } catch {
      return file;
    }

    try {
      let scale = Math.min(1, maxDim / Math.max(bitmap.width, bitmap.height));
      let currentQuality = quality;
      let best: { blob: Blob; ext: string } | null = null;

      for (let attempt = 0; attempt < 6; attempt += 1) {
        const width = Math.max(1, Math.round(bitmap.width * scale));
        const height = Math.max(1, Math.round(bitmap.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        if (!ctx) break;

        ctx.drawImage(bitmap, 0, 0, width, height);

        // PNG 和 WebP 优先转 WebP，保留透明通道；其他格式转 JPEG。
        const preferWebp = file.type === 'image/png' || file.type === 'image/webp';
        const mime = preferWebp ? 'image/webp' : 'image/jpeg';
        const blob = await canvasToBlob(canvas, mime, currentQuality)
          ?? (preferWebp ? await canvasToBlob(canvas, 'image/jpeg', currentQuality) : null);
        if (blob) {
          const candidate = { blob, ext: blob.type === 'image/webp' ? 'webp' : 'jpg' };
          if (!best || candidate.blob.size < best.blob.size) best = candidate;
          if (!maxBytes || blob.size <= maxBytes) return toCompressedFile(file, candidate);
        }

        scale *= 0.82;
        currentQuality = Math.max(0.42, currentQuality * 0.88);
        if (Math.max(width, height) <= 240) break;
      }

      return best && best.blob.size < file.size ? toCompressedFile(file, best) : file;
    } finally {
      bitmap.close();
    }
  })();
}

function toCompressedFile(file: File, candidate: { blob: Blob; ext: string }): File {
  const baseName = file.name.replace(/\.[^.]+$/, '');
  return new File([candidate.blob], `${baseName}.${candidate.ext}`, {
    type: candidate.blob.type,
  });
}

function canvasToBlob(
  canvas: HTMLCanvasElement,
  mime: string,
  quality?: number,
): Promise<Blob | null> {
  return new Promise((resolve) => {
    if (quality !== undefined) {
      canvas.toBlob(resolve, mime, quality);
    } else {
      canvas.toBlob(resolve, mime);
    }
  });
}
