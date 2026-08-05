# Agent Instructions

## Project Status Notice

### uni-app 项目已废弃（仅作原型参考）

`lumira-app/` 目录下的 uni-app 项目是**技术选型后被遗弃的旧项目**，当前**不再维护、不再开发新功能**。

- **当前主项目**：`lumira_app_flutter/`（Flutter，HarmonyOS 兼容，Dart 2.19.6 / Flutter 3.7.12）
- **后端**：`lumira-server/`（NestJS + Fastify + Drizzle ORM + SQLite，pnpm monorepo 含 admin Next.js）
- **uni-app 的作用**：仅作为**视觉规格与交互原型参考**，不可作为运行时或修改目标

### 处理原则

1. **不要修改 `lumira-app/` 下的任何代码**，除非用户明确要求
2. 需要参考设计稿、配色、组件样式、交互流程时，可阅读 uni-app 源码作为参考
3. 新功能、Bug 修复一律在 `lumira_app_flutter/` 实现
4. 后端相关改动在 `lumira-server/` 实现
5. 涉及两端协同时，Flutter 端为主，后端提供 API 支持

### 技术栈速查

| 层 | 技术 | 位置 |
|---|---|---|
| 客户端 | Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records 语法） | `lumira_app_flutter/` |
| 后端 | NestJS + Fastify + Drizzle ORM + better-sqlite3 | `lumira-server/packages/backend/` |
| 后台 | Next.js (App Router) + Tailwind + shadcn/ui | `lumira-server/packages/admin/` |
| 共享类型 | TypeScript | `lumira-server/packages/shared/` |
| 状态管理（Flutter） | flutter_riverpod 2.3.6 + sqflite v11（离线优先） | `lumira_app_flutter/lib/` |
| 路由（Flutter） | GoRouter 6.5.7 | `lumira_app_flutter/lib/app/router.dart` |
