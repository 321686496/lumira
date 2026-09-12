// src/lib/asset-url.ts
// 静态资源 URL 解析（纯函数，无副作用）。
//
// 背景：后端返回的图片 URL 是绝对地址（如 http://localhost:3000/uploads/...，
// 见后端 buildPublicUrl）。后台部署在 Vercel（HTTPS）时，直接加载 http:// 图片
// 会被浏览器以 Mixed Content 阻止（"This request was not upgraded to HTTPS..."）。
//
// 方案：HTTPS 后端直接加载绝对 HTTPS URL；仅 HTTP 后端（含本地开发）才转为
// 同源相对路径并由 next.config.js 代理，避免 Mixed Content 和 Vercel 中转开销。

export function toAssetUrl(
  url: string | null | undefined,
  backendUrl: string,
): string | null {
  if (!url) return null;
  if (url.startsWith('https://')) {
    return url;
  }
  if (url.startsWith('http://')) {
    const idx = url.indexOf('/uploads/');
    if (idx >= 0) return url.slice(idx);
    return url;
  }
  if (url.startsWith('/')) {
    return backendUrl.startsWith('https://') ? `${backendUrl}${url}` : url;
  }
  return `${backendUrl}${url.startsWith('/') ? '' : '/'}${url}`;
}

export function toTemplateThumbUrl(
  url: string | null | undefined,
  backendUrl: string,
  width = 480,
): string | null {
  if (!url) return null;
  const marker = '/uploads/templates/';
  const idx = url.indexOf(marker);
  if (idx < 0) return toAssetUrl(url, backendUrl);

  const cleanPath = url.slice(idx + marker.length).split(/[?#]/)[0];
  const parts = cleanPath.split('/').filter(Boolean);
  if (parts.length !== 2) return toAssetUrl(url, backendUrl);
  const [templateId, filename] = parts;
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(templateId)) return toAssetUrl(url, backendUrl);
  if (!/^[a-z0-9][a-z0-9._-]*$/i.test(filename)) return toAssetUrl(url, backendUrl);

  const path = `/api/v1/thumbs/templates/${templateId}/${filename}?w=${width}`;
  return backendUrl.startsWith('https://') ? `${backendUrl}${path}` : path;
}

export function toCategoryThumbUrl(
  url: string | null | undefined,
  backendUrl: string,
  width = 320,
): string | null {
  if (!url) return null;
  const marker = '/uploads/categories/';
  const idx = url.indexOf(marker);
  if (idx < 0) return toAssetUrl(url, backendUrl);

  const cleanPath = url.slice(idx + marker.length).split(/[?#]/)[0];
  const parts = cleanPath.split('/').filter(Boolean);
  if (parts.length !== 2) return toAssetUrl(url, backendUrl);
  const [key] = parts;
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(key)) return toAssetUrl(url, backendUrl);

  const path = `/api/v1/thumbs/categories/${key}?w=${width}`;
  return backendUrl.startsWith('https://') ? `${backendUrl}${path}` : path;
}
