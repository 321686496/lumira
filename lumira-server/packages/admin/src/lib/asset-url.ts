// src/lib/asset-url.ts
// 静态资源 URL 解析（纯函数，无副作用）。
//
// 背景：后端返回的图片 URL 是绝对地址（如 http://localhost:3000/uploads/...，
// 见后端 buildPublicUrl）。后台部署在 Vercel（HTTPS）时，直接加载 http:// 图片
// 会被浏览器以 Mixed Content 阻止（"This request was not upgraded to HTTPS..."）。
//
// 方案：提取 URL 中的 /uploads/ 部分转为同源相对路径，由 next.config.js 的
// rewrites 在服务端代理到真实后端 —— 服务端到服务端无 Mixed Content 限制，
// 浏览器加载的是 HTTPS 同源资源。

export function toAssetUrl(
  url: string | null | undefined,
  backendUrl: string,
): string | null {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    const idx = url.indexOf('/uploads/');
    if (idx >= 0) return url.slice(idx);
    return url;
  }
  if (url.startsWith('/')) return url;
  return `${backendUrl}${url.startsWith('/') ? '' : '/'}${url}`;
}
