// src/lib/image-compress.ts
// 客户端图片压缩：将大图压缩到指定最长边并转为高压缩格式，显著减小上传体积。
//
// 背景：模板提交链路中存在多个请求体大小瓶颈 ——
//   - Vercel Serverless Function 平台限制 4.5MB（FUNCTION_PAYLOAD_TOO_LARGE）
//   - Nginx client_max_body_size 默认 1MB（413 Request Entity Too Large）
// 因此必须在浏览器端把图片压到足够小（典型 <300KB/张）。
//
// 压缩策略：
//   - SVG：矢量文件通常很小，原样返回
//   - PNG（可能带透明通道）：转 WebP（支持 alpha + 高压缩率），体积可缩小 70%+
//   - JPEG/WebP：转 JPEG（无损化 JPEG 无收益，统一转 JPEG 有损）
//   - 小文件（< 256KB）原样返回，避免无意义重编码
//   - 若压缩结果不理想，用更低质量二次压缩兜底
export async function compressImage(
  file: File,
  opts: { maxDim?: number; quality?: number } = {},
): Promise<File> {
  const { maxDim = 1024, quality = 0.8 } = opts;
  if (file.type === 'image/svg+xml' || file.size <= 256 * 1024) return file;

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

    // PNG（可能带透明）优先转 WebP；JPEG/WebP 转 JPEG
    const preferWebp = file.type === 'image/png';
    let blob = await canvasToBlob(canvas, preferWebp ? 'image/webp' : 'image/jpeg', quality);
    if (!blob) {
      // 浏览器不支持 WebP → 回退 JPEG（有损）
      blob = await canvasToBlob(canvas, 'image/jpeg', quality);
    }
    if (!blob || blob.size >= file.size) {
      // 压缩效果不理想 → 更激进参数再压一次
      blob = await canvasToBlob(canvas, 'image/jpeg', 0.6);
    }
    if (!blob) return file;

    const ext = blob.type === 'image/webp' ? 'webp' : blob.type === 'image/png' ? 'png' : 'jpg';
    const baseName = file.name.replace(/\.[^.]+$/, '');
    return new File([blob], `${baseName}.${ext}`, { type: blob.type });
  } catch {
    // 解码失败（如损坏文件）时回退原文件
    return file;
  }
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
