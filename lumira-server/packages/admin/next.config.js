/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@lumira/shared'],
  experimental: {
    typedRoutes: false,
    // Server Actions 请求体上限：模板提交含多文件（封面 8MB + 剪影 8MB + .pptpl ≤25MB），
    // 默认 1MB 会在 Next.js 层拦截导致 413
    serverActions: {
      bodySizeLimit: '32mb',
    },
  },
  async rewrites() {
    // 静态资源代理：后端返回 http:// 绝对 URL，HTTPS 页面直接加载会被浏览器
    // Mixed Content 阻止。这里把 /uploads/* 在服务端代理到后端（服务端到服务端
    // 无 Mixed Content 限制），前端统一用同源相对路径加载图片。
    const assetBase =
      process.env.BACKEND_PUBLIC_URL || process.env.BACKEND_URL || 'http://localhost:3000';
    return [
      {
        source: '/uploads/:path*',
        destination: `${assetBase}/uploads/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
