/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@lumira/shared'],
  experimental: {
    typedRoutes: false,
    // Server Actions 请求体上限：模板提交含多文件（封面 5MB + 剪影 5MB + .pptpl ≤25MB），
    // 默认 1MB 会在 Next.js 层拦截导致 413
    serverActions: {
      bodySizeLimit: '32mb',
    },
  },
};

module.exports = nextConfig;
