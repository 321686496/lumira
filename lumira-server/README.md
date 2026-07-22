# Lumira Server

如画 Lumira 轻量服务器 monorepo。

## 结构

- `packages/shared` — 共享 TypeScript 类型
- `packages/backend` — NestJS + Fastify 后端 API
- `packages/admin` — Next.js 运营后台（后续添加）

## 开发

```bash
# 安装依赖
npm install

# 构建 shared 包
npm run build:shared

# 启动后端开发服务器
npm run dev:backend

# 运行后端测试
npm run test:backend
```
