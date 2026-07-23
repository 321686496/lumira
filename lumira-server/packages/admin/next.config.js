/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@lumira/shared'],
  experimental: {
    typedRoutes: false,
  },
};

module.exports = nextConfig;
