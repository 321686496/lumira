// src/lib/image-compress.ts
// 客户端图片压缩：将大图压缩到指定最长边 + JPEG 质量，显著减小上传体积。
// 背景：Vercel Serverless Function 有 4.5MB 请求体平台硬限制（FUNCTION_PAYLOAD_TOO_LARGE），
// 大尺寸封面/剪影原图会导致模板提交失败，必须在客户端先压缩。

/**
 * 压缩图片文件。
 * - SVG：矢量文件通常很小，原样返回
 * - PNG：限制最长边（保留透明通道），不压缩质量
 * - JPEG/WebP：限制最长边 + 质量压缩
 * - 小文件（< 512KB）原样返回，避免无意义重编码
 */
export async function compressImage(
  file: File,
  opts: { maxDim?: number; quality?: number } = {},
): Promise<File> {
  const { maxDim = 1280, quality = 0.82 } = opts;
  if (file.type === 'image/svg+xml' || file.size <= 512 * 1024) return file;

  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, maxDim / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      bitmap.close();
      return file;
    }
    ctx.drawImage(bitmap, 0, 0, width, height);
    bitmap.close();

    const isPng = file.type === 'image/png';
    const mime = isPng ? 'image/png' : 'image/jpeg';
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, mime, isPng ? undefined : quality),
    );
    if (!blob || blob.size >= file.size) return file;
    return new File([blob], file.name, { type: blob.type });
  } catch {
    // 解码失败（如损坏文件）时回退原文件
    return file;
  }
}
