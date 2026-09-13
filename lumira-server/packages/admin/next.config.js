/** @type {import('next').NextConfig} */
const deploymentId =
  process.env.VERCEL_DEPLOYMENT_ID ||
  process.env.NEXT_PUBLIC_VERCEL_DEPLOYMENT_ID ||
  process.env.NEXT_DEPLOYMENT_ID ||
  process.env.VERCEL_GIT_COMMIT_SHA;

const nextConfig = {
  deploymentId,
  transpilePackages: ['@lumira/shared'],
  experimental: {
    typedRoutes: false,
    // Vercel Serverless 请求体硬限制约 4.5MB；图片必须在浏览器端压缩。
    serverActions: {
      bodySizeLimit: '4mb',
    },
  },
  async headers() {
    return [
      {
        source: '/dashboard/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'private, no-store, must-revalidate',
          },
          {
            key: 'Clear-Site-Data',
            value: '"cache"',
          },
        ],
      },
    ];
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
      {
        source: '/api/v1/thumbs/:path*',
        destination: `${assetBase}/api/v1/thumbs/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
