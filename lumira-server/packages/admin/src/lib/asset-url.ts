// src/lib/asset-url.ts
// 静态资源 URL 解析（纯函数，无副作用）。
//
// 背景：后端返回的图片 URL 是绝对地址（激活存储的公网域名，见后端 buildAssetUrl）。
// 后台部署在 Vercel（HTTPS）时，直接加载 http:// 图片会被浏览器以 Mixed Content
// 阻止（"This request was not upgraded to HTTPS..."）。
//
// 方案：HTTPS 资源直接加载绝对 HTTPS URL；仅 HTTP 资源（含本地开发）才转为
// 同源相对路径并由 next.config.js 代理，避免 Mixed Content 和 Vercel 中转开销。
//
// 缩略图（2026-09 存储直连改造）：
// 后台原先统一走后端动态端点 /api/v1/thumbs/*，URL 暴露后端域名且占用后端算力。
// 现改为「存储域名直连」：缩略图由后端在写入时预生成到激活存储，客户端按固定
// 键规则推导直连 URL（键规则与后端 ThumbsService、Flutter image_cache 三端一致）：
//   模板：{origin}/uploads/thumbs/templates/{templateId}/{源文件主名}.w{width}.webp
//   分类：{origin}/uploads/thumbs/categories/{key}/w{width}.jpg
// 旧数据尚未预生成时直连 URL 会 404，由调用方用 toXxxThumbFallbackUrl（后端动态
// 端点，按需生成并持久化）兜底，命中后即转为直连。

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

/** 缩略图宽度阶梯：与后端 THUMB_WIDTH_LADDER 保持一致（改必须三端同步） */
const THUMB_WIDTH_LADDER = [160, 320, 480, 640, 800, 1080];

/** 把请求宽度吸附到阶梯（差距最小；距离相等取较小值） */
export function snapThumbWidth(width: number): number {
  const w = Math.round(width);
  let best = THUMB_WIDTH_LADDER[0];
  for (const v of THUMB_WIDTH_LADDER) {
    if (Math.abs(w - v) < Math.abs(w - best)) best = v;
  }
  return best;
}

/** 提取绝对 URL 的 origin（协议+主机，无尾斜杠）；非绝对 URL 返回 null */
function originOf(url: string): string | null {
  const m = /^https?:\/\/[^/]+/i.exec(url);
  return m ? m[0] : null;
}

/** 从任意图片值中提取 /uploads/templates/{templateId}/{filename} 两段 */
function parseTemplateSource(url: string): { templateId: string; filename: string } | null {
  const marker = '/uploads/templates/';
  const idx = url.indexOf(marker);
  if (idx < 0) return null;

  const cleanPath = url.slice(idx + marker.length).split(/[?#]/)[0];
  const parts = cleanPath.split('/').filter(Boolean);
  if (parts.length !== 2) return null;
  const [templateId, filename] = parts;
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(templateId)) return null;
  if (!/^[a-z0-9][a-z0-9._-]*$/i.test(filename)) return null;
  return { templateId, filename };
}

/** 从任意图片值中提取 /uploads/categories/{key}/{filename} 两段 */
function parseCategorySource(url: string): { key: string; filename: string } | null {
  const marker = '/uploads/categories/';
  const idx = url.indexOf(marker);
  if (idx < 0) return null;

  const cleanPath = url.slice(idx + marker.length).split(/[?#]/)[0];
  const parts = cleanPath.split('/').filter(Boolean);
  if (parts.length !== 2) return null;
  const [key, filename] = parts;
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(key)) return null;
  if (!/^[a-z0-9][a-z0-9._-]*$/i.test(filename)) return null;
  return { key, filename };
}

/**
 * 存储直连缩略图 URL 拼接：源 URL 为 HTTPS 绝对地址时用其 origin（即激活存储
 * 公网域名）直连；HTTP（本地开发）或相对路径时退化为同源相对路径，由
 * next.config.js 代理到资产源（同时规避 Mixed Content）。
 */
function storageThumbUrl(sourceUrl: string, thumbPath: string): string {
  const origin = originOf(sourceUrl);
  if (origin && /^https:\/\//i.test(origin)) return `${origin}${thumbPath}`;
  return thumbPath;
}

export function toTemplateThumbUrl(
  url: string | null | undefined,
  backendUrl: string,
  width = 480,
): string | null {
  if (!url) return null;
  const parsed = parseTemplateSource(url);
  if (!parsed) return toAssetUrl(url, backendUrl);

  const snapped = snapThumbWidth(width);
  const base = parsed.filename.replace(/\.[^.]+$/, '');
  const thumbPath = `/uploads/thumbs/templates/${parsed.templateId}/${base}.w${snapped}.webp`;
  return storageThumbUrl(url, thumbPath);
}

/** 模板缩略图兜底 URL：后端动态端点（直连 URL 404 时按需生成并持久化，走同源代理） */
export function toTemplateThumbFallbackUrl(
  url: string | null | undefined,
  width = 480,
): string | null {
  if (!url) return null;
  const parsed = parseTemplateSource(url);
  if (!parsed) return null;
  const snapped = snapThumbWidth(width);
  return `/api/v1/thumbs/templates/${parsed.templateId}/${parsed.filename}?w=${snapped}`;
}

export function toCategoryThumbUrl(
  url: string | null | undefined,
  backendUrl: string,
  width = 320,
): string | null {
  if (!url) return null;
  const parsed = parseCategorySource(url);
  if (!parsed) return toAssetUrl(url, backendUrl);

  const snapped = snapThumbWidth(width);
  const thumbPath = `/uploads/thumbs/categories/${parsed.key}/w${snapped}.jpg`;
  return storageThumbUrl(url, thumbPath);
}

/** 分类缩略图兜底 URL：后端动态端点（直连 URL 404 时按需生成并持久化，走同源代理） */
export function toCategoryThumbFallbackUrl(
  url: string | null | undefined,
  width = 320,
): string | null {
  if (!url) return null;
  const parsed = parseCategorySource(url);
  if (!parsed) return null;
  const snapped = snapThumbWidth(width);
  return `/api/v1/thumbs/categories/${parsed.key}?w=${snapped}`;
}
