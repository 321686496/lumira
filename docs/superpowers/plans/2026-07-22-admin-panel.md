# 后台管理面板实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为运营人员提供 Next.js 14 Web 后台，调用已就绪的 lumira-server Admin API 管理邀请、兑换码、奖励。

**Architecture:** Next.js 14 App Router + Server Components/Actions + shadcn/ui + Tailwind（Morandi 主题）。后台作为 monorepo 子包 `packages/admin`，部署到 Vercel。

**Tech Stack:** Next.js 14、React 18、Tailwind CSS 3、shadcn/ui (Radix UI)、@phosphor-icons/react、react-hook-form + zod、@tanstack/react-table、shadcn/ui Charts (recharts)、Vitest。

## Global Constraints

- **代码位置**：`lumira-server/packages/admin/`（与 backend/shared 同级）
- **Git 仓库**：使用 `d:\app\projects\photo_post\.git` 主仓库，不创建独立仓库
- **包名**：`@lumira/admin`，在根 `package.json` 的 workspaces 中已包含 `packages/*`
- **后端依赖**：HEAD `ae8a4758` 已提供 7 个 admin 端点 + 完整 e2e 测试
- **共享类型**：`@lumira/shared` 已定义 `InviteRecord`/`RedemptionCodeBatch`/`RedemptionRecord`/`RewardTier`/`UnlockedReward` 等，admin 直接复用
- **后端 API 前缀**：`/api/v1/admin/`（7 端点见 spec §3.9）
- **认证机制**：后端 AdminAuthGuard 接受 Bearer token，与 `process.env.ADMIN_TOKEN` 字符串比较
- **环境变量**：`BACKEND_URL`（后端 API 地址，开发时 `http://localhost:3000`），`ADMIN_TOKEN`（仅 /login 用于校验）
- **CSS 单位**：Web 项目用 `px`/`rem`（不是 rpx，那是 uni-app 专用）
- **图标**：`@phosphor-icons/react`，不用 emoji
- **标题栏文本左对齐**（用户偏好）
- **Morandi 色系**：详见 spec §6
- **TypeScript strict mode**：开启
- **无 `enableImplicitConversion`**：后端 final review 已移除此选项（class-transformer 0.5.1 对 Boolean 类型隐式转换会破坏校验）；前端 react-hook-form + zod 不涉及此问题，但需知后端期望显式类型

---

## Task 0.1: 脚手架与基础配置

**Files:**
- Create: `lumira-server/packages/admin/package.json`
- Create: `lumira-server/packages/admin/next.config.js`
- Create: `lumira-server/packages/admin/tsconfig.json`
- Create: `lumira-server/packages/admin/tailwind.config.ts`
- Create: `lumira-server/packages/admin/postcss.config.js`
- Create: `lumira-server/packages/admin/components.json`
- Create: `lumira-server/packages/admin/.env.example`
- Create: `lumira-server/packages/admin/src/app/layout.tsx`
- Create: `lumira-server/packages/admin/src/app/globals.css`
- Create: `lumira-server/packages/admin/src/app/page.tsx`（占位重定向到 /dashboard）
- Create: `lumira-server/packages/admin/src/lib/utils.ts`（cn 工具函数）
- Create: `lumira-server/packages/admin/next-env.d.ts`
- Modify: `lumira-server/package.json`（确保 workspaces 包含 `packages/*`）

**Interfaces:**
- Produces: `@lumira/admin` npm workspace package，可启动 `npm run dev`（即使没有页面内容）

- [ ] **Step 1: 创建 package.json**

```json
{
  "name": "@lumira/admin",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001",
    "lint": "next lint",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@lumira/shared": "*",
    "@phosphor-icons/react": "^2.1.7",
    "@radix-ui/react-avatar": "^1.1.1",
    "@radix-ui/react-dialog": "^1.1.2",
    "@radix-ui/react-dropdown-menu": "^2.1.2",
    "@radix-ui/react-label": "^2.1.0",
    "@radix-ui/react-select": "^2.1.2",
    "@radix-ui/react-slot": "^1.1.0",
    "@radix-ui/react-switch": "^1.1.1",
    "@radix-ui/react-toast": "^1.2.2",
    "@tanstack/react-table": "^8.20.5",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.1",
    "next": "14.2.15",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hook-form": "^7.53.0",
    "tailwind-merge": "^2.5.4",
    "tailwindcss-animate": "^1.0.7",
    "zod": "^3.23.8",
    "@hookform/resolvers": "^3.9.0",
    "recharts": "^2.13.0"
  },
  "devDependencies": {
    "@testing-library/react": "^16.0.1",
    "@testing-library/jest-dom": "^6.5.0",
    "@types/node": "^20.16.11",
    "@types/react": "^18.3.11",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.2",
    "autoprefixer": "^10.4.20",
    "eslint": "^8.57.1",
    "eslint-config-next": "14.2.15",
    "jsdom": "^25.0.1",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "typescript": "^5.6.3",
    "vitest": "^2.1.2"
  }
}
```

- [ ] **Step 2: 创建 next.config.js**

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@lumira/shared'],
  experimental: {
    typedRoutes: false,
  },
};

module.exports = nextConfig;
```

- [ ] **Step 3: 创建 tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 4: 创建 tailwind.config.ts（Morandi 主题色 + shadcn/ui 变量）**

```typescript
import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class'],
  content: [
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    container: {
      center: true,
      padding: '2rem',
      screens: { '2xl': '1400px' },
    },
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',
          foreground: 'hsl(var(--accent-foreground))',
        },
        popover: {
          DEFAULT: 'hsl(var(--popover))',
          foreground: 'hsl(var(--popover-foreground))',
        },
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))',
        },
        chart: {
          '1': 'hsl(var(--chart-1))',
          '2': 'hsl(var(--chart-2))',
          '3': 'hsl(var(--chart-3))',
          '4': 'hsl(var(--chart-4))',
        },
        success: 'hsl(var(--success))',
        warning: 'hsl(var(--warning))',
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'monospace'],
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};

export default config;
```

- [ ] **Step 5: 创建 postcss.config.js**

```javascript
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- [ ] **Step 6: 创建 globals.css（Morandi CSS 变量 + Tailwind 指令）**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 30 20% 96%;
    --foreground: 0 0% 24%;

    --card: 0 0% 100%;
    --card-foreground: 0 0% 24%;

    --popover: 0 0% 100%;
    --popover-foreground: 0 0% 24%;

    --primary: 210 14% 54%;
    --primary-foreground: 30 20% 98%;

    --secondary: 30 15% 90%;
    --secondary-foreground: 0 0% 24%;

    --muted: 30 15% 92%;
    --muted-foreground: 0 0% 40%;

    --accent: 20 22% 70%;
    --accent-foreground: 0 0% 24%;

    --destructive: 0 15% 60%;
    --destructive-foreground: 30 20% 98%;

    --border: 30 10% 88%;
    --input: 30 10% 88%;
    --ring: 210 14% 54%;

    --success: 130 15% 60%;
    --warning: 35 25% 65%;

    --chart-1: 210 14% 54%;
    --chart-2: 20 22% 70%;
    --chart-3: 130 15% 60%;
    --chart-4: 35 25% 65%;

    --radius: 0.75rem;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
    font-feature-settings: 'rlig' 1, 'calt' 1;
  }
}
```

- [ ] **Step 7: 创建 components.json（shadcn/ui 配置）**

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "stone",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
```

- [ ] **Step 8: 创建 lib/utils.ts**

```typescript
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// 截断 UUID 显示（前 8 位 + …）
export function truncateDeviceId(id: string): string {
  return id.length > 12 ? `${id.slice(0, 8)}…` : id;
}

// Unix 秒 → YYYY-MM-DD HH:mm
export function formatUnixTime(unix: number): string {
  const d = new Date(unix * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// datetime-local 字符串 → Unix 秒
export function toUnixSeconds(localDatetime: string): number {
  return Math.floor(new Date(localDatetime).getTime() / 1000);
}
```

- [ ] **Step 9: 创建 next-env.d.ts**

```typescript
/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.
```

- [ ] **Step 10: 创建 .env.example**

```
# 后端 API 地址（开发环境指向本地 NestJS）
BACKEND_URL=http://localhost:3000

# 仅用于本地开发登录测试（生产环境通过 /login 页面输入）
# 不要把真实 ADMIN_TOKEN 提交到仓库
```

- [ ] **Step 11: 创建根 layout.tsx**

```tsx
// src/app/layout.tsx
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });

export const metadata: Metadata = {
  title: 'Lumira 运营后台',
  description: '如画 App 运营管理面板',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body className={`${inter.variable} font-sans antialiased`}>
        {children}
      </body>
    </html>
  );
}
```

- [ ] **Step 12: 创建根 page.tsx（占位重定向）**

```tsx
// src/app/page.tsx
import { redirect } from 'next/navigation';

export default function Home() {
  redirect('/dashboard');
}
```

- [ ] **Step 13: 检查并修改根 lumira-server/package.json 的 workspaces**

读 `lumira-server/package.json`，确认 `workspaces` 字段为 `["packages/*"]`（应已包含 admin）。如未包含则添加。如已包含则不修改。

- [ ] **Step 14: 安装依赖并验证构建**

```bash
cd lumira-server
npm install
cd packages/admin
npx next build --no-lint
```

Expected: build 成功（即使有 lint warning 也可），不报 TypeScript 错误。

- [ ] **Step 15: 提交**

```bash
cd d:\app\projects\photo_post
git add lumira-server/packages/admin/ lumira-server/package.json lumira-server/package-lock.json
git commit -m "feat(admin): scaffold Next.js 14 app with Tailwind + shadcn/ui config"
```

---

## Task 1.0: shadcn/ui 基础组件 + 认证 + 布局

**Files:**
- Create: `lumira-server/packages/admin/src/components/ui/*`（shadcn/ui 生成的基础组件：button, card, input, label, table, badge, dialog, select, switch, sonner/toast, form, separator, dropdown-menu）
- Create: `lumira-server/packages/admin/src/lib/auth.ts`
- Create: `lumira-server/packages/admin/src/lib/api.ts`
- Create: `lumira-server/packages/admin/src/middleware.ts`
- Create: `lumira-server/packages/admin/src/app/(auth)/login/page.tsx`
- Create: `lumira-server/packages/admin/src/actions/login.ts`
- Create: `lumira-server/packages/admin/src/actions/logout.ts`
- Create: `lumira-server/packages/admin/src/app/(dashboard)/layout.tsx`
- Create: `lumira-server/packages/admin/src/components/sidebar.tsx`
- Create: `lumira-server/packages/admin/src/components/topbar.tsx`
- Create: `lumira-server/packages/admin/src/types/admin.ts`
- Test: `lumira-server/packages/admin/src/lib/__tests__/utils.test.ts`
- Test: `lumira-server/packages/admin/src/lib/__tests__/api.test.ts`

**Interfaces:**
- Consumes: 后端 `GET /api/v1/admin/stats` 用于登录校验
- Produces: `api` 客户端（`api.getStats/getInvites/getBatches/createBatch/getBatchDetail/toggleBatch/getRewards`）、`loginAction`、`logoutAction`、`Sidebar`、`Topbar`、`(dashboard)/layout.tsx`

- [ ] **Step 1: 生成 shadcn/ui 基础组件**

shadcn/ui 是源码复制式，不能用 `npx shadcn-ui add` 命令（交互式输入不适合 subagent）。改用直接创建每个组件的源码文件。需要创建的组件清单（从 shadcn/ui 官方源码 verbatim 复制到 `src/components/ui/`）：

- `button.tsx`、`card.tsx`、`input.tsx`、`label.tsx`、`table.tsx`、`badge.tsx`、`dialog.tsx`、`select.tsx`、`switch.tsx`、`separator.tsx`、`dropdown-menu.tsx`、`form.tsx`、`toast.tsx`、`toaster.tsx`、`use-toast.ts`

每个文件从 https://ui.shadcn.com/docs/components/{name} 复制最新源码。所有组件使用项目已配置的 `cn()` 工具和 Tailwind 变量。**注**：shadcn/ui 源码使用 `@radix-ui/react-*` 依赖，已在 Task 0.1 的 package.json 中列出。

- [ ] **Step 2: 创建 types/admin.ts**

```typescript
// src/types/admin.ts
// 后台专用类型（与 @lumira/shared 互补）

export interface StatsResponse {
  totalDevices: number;
  todayNewDevices: number;
  totalInvites: number;
  todayNewInvites: number;
  totalRedemptions: number;
  todayRedeemed: number;
  totalRewardUnlocks: number;
  totalCodesGenerated: number;
  totalCodesUsed: number;
  totalCodesRemaining: number;
}

export interface InviteListResponse {
  data: Array<{
    id: number;
    inviterDeviceId: string;
    inviteeDeviceId: string;
    inviteCode: string;
    channel: string;
    activatedAt: number;
    inviterIp: string | null;
    inviteeIp: string | null;
  }>;
  total: number;
  page: number;
  pageSize: number;
}

export interface Batch {
  batchId: number;
  campaignName: string;
  rewardTier: number;
  maxUsesPerCode: number;
  totalGenerated: number;
  totalUsed: number;
  validFrom: number | null;
  validUntil: number | null;
  isActive: number;
  createdAt: number;
}

export interface BatchDetail extends Batch {
  codes: Array<{
    code: string;
    batchId: number;
    usedCount: number;
    maxUses: number;
  }>;
}

export interface CreateBatchResponse {
  batchId: number;
  campaignName: string;
  totalGenerated: number;
}

export interface RewardListResponse {
  data: Array<{
    id: number;
    deviceId: string;
    tier: number;
    source: string;
    sourceDetail: string | null;
    status: string;
    unlockedAt: number;
    claimedAt: number | null;
  }>;
  total: number;
  page: number;
  pageSize: number;
}

export interface CreateBatchInput {
  campaignName: string;
  codes: string[];
  rewardTier: number;
  maxUsesPerCode: number;
  validFrom?: number;
  validUntil?: number;
}
```

- [ ] **Step 3: 创建 lib/auth.ts**

```typescript
// src/lib/auth.ts
import { cookies } from 'next/headers';

export const AUTH_COOKIE_NAME = 'admin_token';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30; // 30 天

export function getAuthToken(): string | undefined {
  return cookies().get(AUTH_COOKIE_NAME)?.value;
}

export function setAuthToken(token: string): void {
  cookies().set(AUTH_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: COOKIE_MAX_AGE,
    path: '/',
  });
}

export function clearAuthToken(): void {
  cookies().delete(AUTH_COOKIE_NAME);
}

// 校验 token 有效性（调后端 /stats）
export async function verifyToken(token: string): Promise<boolean> {
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';
  try {
    const res = await fetch(`${backendUrl}/api/v1/admin/stats`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
    return res.ok;
  } catch {
    return false;
  }
}
```

- [ ] **Step 4: 创建 lib/api.ts**

```typescript
// src/lib/api.ts
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { AUTH_COOKIE_NAME } from './auth';
import type {
  StatsResponse,
  InviteListResponse,
  Batch,
  BatchDetail,
  CreateBatchResponse,
  CreateBatchInput,
  RewardListResponse,
} from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const token = cookies().get(AUTH_COOKIE_NAME)?.value;
  if (!token) {
    redirect('/login');
  }

  const res = await fetch(`${BACKEND_URL}/api/v1/admin${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...init?.headers,
    },
    cache: 'no-store',
  });

  if (res.status === 401) {
    redirect('/login');
  }
  if (!res.ok) {
    throw new Error(`API_ERROR: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  getStats: () => adminFetch<StatsResponse>('/stats'),

  getInvites: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<InviteListResponse>(`/invites${qs ? `?${qs}` : ''}`);
  },

  getBatches: () => adminFetch<Batch[]>('/redeem-batches'),

  createBatch: (data: CreateBatchInput) =>
    adminFetch<CreateBatchResponse>('/redeem-batches', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  getBatchDetail: (id: number) => adminFetch<BatchDetail>(`/redeem-batches/${id}`),

  toggleBatch: (id: number, isActive: boolean) =>
    adminFetch<{ success: boolean }>(`/redeem-batches/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive }),
    }),

  getRewards: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<RewardListResponse>(`/rewards${qs ? `?${qs}` : ''}`);
  },
};
```

- [ ] **Step 5: 创建 middleware.ts**

```typescript
// src/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('admin_token')?.value;
  const isLoginPage = request.nextUrl.pathname.startsWith('/login');
  const isRoot = request.nextUrl.pathname === '/';

  // 根路径让 layout 中的 redirect 处理
  if (isRoot) return NextResponse.next();

  if (!token && !isLoginPage) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('from', request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  if (token && isLoginPage) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.svg).*)'],
};
```

- [ ] **Step 6: 创建 login page**

```tsx
// src/app/(auth)/login/page.tsx
import { Suspense } from 'react';
import LoginForm from './login-form';
import { ChartLineUp } from '@phosphor-icons/react/dist/ssr';

export default async function LoginPage({
  searchParams,
}: {
  searchParams: { from?: string };
}) {
  return (
    <main className="min-h-screen flex items-center justify-center bg-gradient-to-br from-background to-secondary">
      <div className="w-full max-w-md mx-4">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 text-primary mb-4">
            <ChartLineUp size={28} weight="duotone" />
          </div>
          <h1 className="text-2xl font-semibold text-foreground text-left">Lumira 运营后台</h1>
          <p className="mt-2 text-sm text-muted-foreground text-left">请输入管理员 Token 登录</p>
        </div>
        <Suspense fallback={<div className="text-center text-muted-foreground">加载中…</div>}>
          <LoginForm redirectTo={searchParams.from} />
        </Suspense>
      </div>
    </main>
  );
}
```

- [ ] **Step 7: 创建 login-form.tsx（client component）**

```tsx
// src/app/(auth)/login/login-form.tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { loginAction } from '@/actions/login';

export default function LoginForm({ redirectTo }: { redirectTo?: string }) {
  const router = useRouter();
  const [token, setToken] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await loginAction(token, redirectTo);
      if (result?.error) {
        setError(result.error);
      }
    });
  }

  return (
    <form onSubmit={handleSubmit} className="bg-card p-6 rounded-xl shadow-sm border border-border space-y-4">
      <div className="space-y-2">
        <Label htmlFor="adminToken" className="text-left block">管理员 Token</Label>
        <Input
          id="adminToken"
          type="password"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="输入 ADMIN_TOKEN"
          autoComplete="current-password"
          required
          autoFocus
        />
      </div>
      {error && (
        <p className="text-sm text-destructive" role="alert">{error}</p>
      )}
      <Button type="submit" disabled={isPending || !token} className="w-full">
        {isPending ? '验证中…' : '登录'}
      </Button>
    </form>
  );
}
```

- [ ] **Step 8: 创建 actions/login.ts**

```typescript
// src/actions/login.ts
'use server';

import { redirect } from 'next/navigation';
import { setAuthToken, verifyToken } from '@/lib/auth';

export async function loginAction(token: string, redirectTo?: string) {
  if (!token || token.trim().length === 0) {
    return { error: '请输入 Token' };
  }

  const valid = await verifyToken(token);
  if (!valid) {
    return { error: 'Token 无效，请检查后重试' };
  }

  setAuthToken(token);
  redirect(redirectTo || '/dashboard');
}
```

- [ ] **Step 9: 创建 actions/logout.ts**

```typescript
// src/actions/logout.ts
'use server';

import { redirect } from 'next/navigation';
import { clearAuthToken } from '@/lib/auth';

export async function logoutAction() {
  clearAuthToken();
  redirect('/login');
}
```

- [ ] **Step 10: 创建 sidebar.tsx**

```tsx
// src/components/sidebar.tsx
import Link from 'next/link';
import { ChartLineUp, Users, Ticket, Gift } from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';

const navItems = [
  { href: '/dashboard', label: '概览', icon: ChartLineUp },
  { href: '/dashboard/invites', label: '邀请记录', icon: Users },
  { href: '/dashboard/redeem-batches', label: '兑换码', icon: Ticket },
  { href: '/dashboard/rewards', label: '奖励明细', icon: Gift },
];

export function Sidebar({ activePath }: { activePath: string }) {
  return (
    <aside className="hidden md:flex flex-col w-56 bg-card border-r border-border">
      <div className="p-6">
        <span className="text-lg font-semibold text-foreground">Lumira</span>
      </div>
      <nav className="flex-1 px-3 space-y-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = activePath === item.href || activePath.startsWith(item.href + '/');
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors',
                active
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:bg-accent/40 hover:text-foreground'
              )}
            >
              <Icon size={18} weight={active ? 'fill' : 'regular'} />
              <span className="text-left">{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 11: 创建 topbar.tsx**

```tsx
// src/components/topbar.tsx
import { SignOut } from '@phosphor-icons/react/dist/ssr';
import { Button } from '@/components/ui/button';
import { logoutAction } from '@/actions/logout';

export function Topbar({ title }: { title: string }) {
  return (
    <header className="h-16 flex items-center justify-between px-6 bg-card border-b border-border">
      <h1 className="text-lg font-medium text-foreground text-left">{title}</h1>
      <form action={logoutAction}>
        <Button variant="ghost" size="sm" type="submit">
          <SignOut size={16} className="mr-2" />
          退出登录
        </Button>
      </form>
    </header>
  );
}
```

- [ ] **Step 12: 创建 (dashboard)/layout.tsx**

```tsx
// src/app/(dashboard)/layout.tsx
import { Sidebar } from '@/components/sidebar';
import { Topbar } from '@/components/topbar';

const titleMap: Record<string, string> = {
  '/dashboard': '概览',
  '/dashboard/invites': '邀请记录',
  '/dashboard/redeem-batches': '兑换码批次',
  '/dashboard/rewards': '奖励明细',
};

function resolveTitle(pathname: string): string {
  if (titleMap[pathname]) return titleMap[pathname];
  if (pathname.startsWith('/dashboard/redeem-batches/new')) return '创建批次';
  if (pathname.match(/\/dashboard\/redeem-batches\/\d+/)) return '批次详情';
  return 'Lumira 运营后台';
}

export default async function DashboardLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { rest: string[] };
}) {
  const pathname = params.rest?.join('/') ? `/${params.rest.join('/')}` : '/dashboard';
  // 注意：App Router 的 layout 没有 pathname，下面用 children 中的客户端组件来传递。
  // 简化方案：使用 usePathname 在客户端组件中渲染。但 layout 是 Server Component。
  // 我们用一个客户端组件包裹器来获取 pathname 并传给 Sidebar/Topbar。

  return (
    <div className="flex h-screen">
      <DashboardShell>{children}</DashboardShell>
    </div>
  );
}

// 客户端包裹器：读取 pathname，决定 sidebar active state 和 topbar title
import DashboardShell from '@/components/dashboard-shell';
```

注：上面 layout.tsx 的实现可以简化。下面是更干净的版本（删除多余的 DashboardShell 引入注释，改为直接放客户端组件）：

实际上 layout 不接收 pathname。我们直接在 layout 里渲染一个客户端 `DashboardShell` 组件，由它内部用 `usePathname()` 读取路径并传给 `Sidebar` 和 `Topbar`。

- [ ] **Step 12b: 创建 dashboard-shell.tsx**

```tsx
// src/components/dashboard-shell.tsx
'use client';

import { usePathname } from 'next/navigation';
import { Sidebar } from '@/components/sidebar';
import { Topbar } from '@/components/topbar';

const titleMap: Record<string, string> = {
  '/dashboard': '概览',
  '/dashboard/invites': '邀请记录',
  '/dashboard/redeem-batches': '兑换码批次',
  '/dashboard/rewards': '奖励明细',
};

function resolveTitle(pathname: string): string {
  if (titleMap[pathname]) return titleMap[pathname];
  if (pathname === '/dashboard/redeem-batches/new') return '创建批次';
  if (pathname.match(/\/dashboard\/redeem-batches\/\d+/)) return '批次详情';
  return 'Lumira 运营后台';
}

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const title = resolveTitle(pathname);

  return (
    <>
      <Sidebar activePath={pathname} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Topbar title={title} />
        <main className="flex-1 overflow-y-auto bg-background p-6">
          {children}
        </main>
      </div>
    </>
  );
}
```

- [ ] **Step 12c: 简化 (dashboard)/layout.tsx**

```tsx
// src/app/(dashboard)/layout.tsx
import DashboardShell from '@/components/dashboard-shell';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <DashboardShell>{children}</DashboardShell>;
}
```

- [ ] **Step 13: 创建占位 dashboard page（确保路由可访问）**

```tsx
// src/app/(dashboard)/dashboard/page.tsx
export default function DashboardPage() {
  return (
    <div className="text-muted-foreground">
      Dashboard 待实现（Task 2.0）
    </div>
  );
}
```

- [ ] **Step 14: 创建占位 invites/redeem-batches/rewards pages**

```tsx
// src/app/(dashboard)/invites/page.tsx
export default function InvitesPage() {
  return <div className="text-muted-foreground">邀请记录待实现（Task 3.0）</div>;
}
```

```tsx
// src/app/(dashboard)/redeem-batches/page.tsx
export default function RedeemBatchesPage() {
  return <div className="text-muted-foreground">兑换码批次待实现（Task 4.0）</div>;
}
```

```tsx
// src/app/(dashboard)/rewards/page.tsx
export default function RewardsPage() {
  return <div className="text-muted-foreground">奖励明细待实现（Task 5.0）</div>;
}
```

- [ ] **Step 15: 创建 utils.test.ts**

```typescript
// src/lib/__tests__/utils.test.ts
import { describe, it, expect } from 'vitest';
import { truncateDeviceId, formatUnixTime, toUnixSeconds } from '../utils';

describe('truncateDeviceId', () => {
  it('truncates UUID to 8 chars + ellipsis', () => {
    expect(truncateDeviceId('66666666-6666-4666-8666-666666666666')).toBe('66666666…');
  });
  it('returns short id unchanged', () => {
    expect(truncateDeviceId('abc123')).toBe('abc123');
  });
});

describe('formatUnixTime', () => {
  it('formats known Unix timestamp', () => {
    // 2024-01-01 00:00:00 UTC = 1704067200
    const result = formatUnixTime(1704067200);
    // 时区相关，只验证格式
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/);
  });
});

describe('toUnixSeconds', () => {
  it('converts ISO datetime-local string', () => {
    const unix = toUnixSeconds('2024-01-01T00:00');
    expect(unix).toBeGreaterThan(1704067199);
    expect(unix).toBeLessThan(1704153601);
  });
});
```

- [ ] **Step 16: 创建 api.test.ts**

```typescript
// src/lib/__tests__/api.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock next/headers and next/navigation
vi.mock('next/headers', () => ({
  cookies: () => ({ get: () => ({ value: 'test-token' }) }),
}));
vi.mock('next/navigation', () => ({
  redirect: (path: string) => { throw new Error(`REDIRECT:${path}`); },
}));

// Mock global fetch
const fetchMock = vi.fn();
global.fetch = fetchMock as any;

describe('api client', () => {
  beforeEach(() => {
    fetchMock.mockReset();
  });

  it('getStats calls /stats with Authorization header', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ totalDevices: 1 }),
    });
    const { api } = await import('../api');
    const result = await api.getStats();
    expect(result).toEqual({ totalDevices: 1 });
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/stats'),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer test-token',
        }),
      }),
    );
  });

  it('throws on 404', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: false,
      status: 404,
      statusText: 'Not Found',
      json: async () => ({}),
    });
    const { api } = await import('../api');
    await expect(api.getBatchDetail(9999)).rejects.toThrow('API_ERROR: 404');
  });
});
```

- [ ] **Step 17: 安装并运行测试**

```bash
cd lumira-server/packages/admin
npm install
npx vitest run
```

Expected: 5/5 tests passing（3 utils + 2 api）。

- [ ] **Step 18: 运行 next build 验证**

```bash
npx next build --no-lint
```

Expected: build 成功，无 TypeScript 错误。

- [ ] **Step 19: 提交**

```bash
git add lumira-server/packages/admin/src/ lumira-server/packages/admin/package-lock.json
git commit -m "feat(admin): add auth, layout, sidebar, shadcn/ui components"
```

---

## Task 2.0: Dashboard 概览页

**Files:**
- Modify: `lumira-server/packages/admin/src/app/(dashboard)/dashboard/page.tsx`
- Create: `lumira-server/packages/admin/src/components/stats-card.tsx`
- Create: `lumira-server/packages/admin/src/components/trend-chart.tsx`
- Create: `lumira-server/packages/admin/src/components/chart-card.tsx`

**Interfaces:**
- Consumes: `api.getStats()` 返回 `StatsResponse`
- Produces: `StatsCard`、`TrendChart`、`ChartCard` 组件

- [ ] **Step 1: 创建 stats-card.tsx**

```tsx
// src/components/stats-card.tsx
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function StatsCard({
  label,
  value,
  icon: Icon,
  hint,
  className,
}: {
  label: string;
  value: number | string;
  icon?: React.ComponentType<{ size?: number; className?: string }>;
  hint?: string;
  className?: string;
}) {
  return (
    <Card className={cn('p-5', className)}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-muted-foreground text-left">{label}</p>
          <p className="mt-2 text-2xl font-semibold text-foreground text-left">{value}</p>
        </div>
        {Icon && (
          <div className="p-2 rounded-lg bg-primary/10 text-primary">
            <Icon size={20} />
          </div>
        )}
      </div>
      {hint && (
        <p className="mt-2 text-xs text-muted-foreground text-left">{hint}</p>
      )}
    </Card>
  );
}
```

- [ ] **Step 2: 创建 chart-card.tsx**

```tsx
// src/components/chart-card.tsx
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function ChartCard({
  title,
  description,
  children,
  className,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn('p-6', className)}>
      <div className="mb-4">
        <h3 className="text-base font-medium text-foreground text-left">{title}</h3>
        {description && (
          <p className="mt-1 text-sm text-muted-foreground text-left">{description}</p>
        )}
      </div>
      {children}
    </Card>
  );
}
```

- [ ] **Step 3: 创建 trend-chart.tsx（client component，用 recharts）**

```tsx
// src/components/trend-chart.tsx
'use client';

import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';

export interface TrendDataPoint {
  date: string;       // "MM-DD"
  devices: number;
  invites: number;
}

export function TrendChart({ data }: { data: TrendDataPoint[] }) {
  if (!data.length) {
    return (
      <div className="h-72 flex items-center justify-center text-sm text-muted-foreground">
        暂无趋势数据
      </div>
    );
  }
  return (
    <div className="h-72 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
          <XAxis dataKey="date" stroke="hsl(var(--muted-foreground))" fontSize={12} />
          <YAxis stroke="hsl(var(--muted-foreground))" fontSize={12} allowDecimals={false} />
          <Tooltip
            contentStyle={{
              backgroundColor: 'hsl(var(--card))',
              border: '1px solid hsl(var(--border))',
              borderRadius: '8px',
              color: 'hsl(var(--foreground))',
            }}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="devices"
            stroke="hsl(var(--chart-1))"
            name="设备注册"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
          <Line
            type="monotone"
            dataKey="invites"
            stroke="hsl(var(--chart-2))"
            name="邀请激活"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

- [ ] **Step 4: 创建 dashboard page.tsx**

```tsx
// src/app/(dashboard)/dashboard/page.tsx
import { api } from '@/lib/api';
import { StatsCard } from '@/components/stats-card';
import { ChartCard } from '@/components/chart-card';
import { TrendChart } from '@/components/trend-chart';
import {
  DeviceMobile, Users, ArrowUp, Ticket, Gift, Database,
} from '@phosphor-icons/react/dist/ssr';

export default async function DashboardPage() {
  let stats;
  try {
    stats = await api.getStats();
  } catch (e) {
    return (
      <div className="text-destructive">加载统计数据失败：{(e as Error).message}</div>
    );
  }

  // 注：后端目前无 /admin/stats/trend 端点，趋势图先用空数据占位
  // 待后端扩展后改为：const trend = await api.getStatsTrend();
  const trend: { date: string; devices: number; invites: number }[] = [];

  return (
    <div className="space-y-6">
      {/* 业务统计 - 2x2 grid */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatsCard
          label="累计设备"
          value={stats.totalDevices}
          icon={DeviceMobile}
          hint={`今日新增 ${stats.todayNewDevices}`}
        />
        <StatsCard
          label="累计邀请"
          value={stats.totalInvites}
          icon={Users}
          hint={`今日 ${stats.todayNewInvites}`}
        />
        <StatsCard
          label="累计兑换"
          value={stats.totalRedemptions}
          icon={ArrowUp}
          hint={`今日 ${stats.todayRedeemed}`}
        />
        <StatsCard
          label="奖励解锁"
          value={stats.totalRewardUnlocks}
          icon={Gift}
        />
      </section>

      {/* 兑换码统计 - 1x3 grid */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard label="已生成码数" value={stats.totalCodesGenerated} icon={Ticket} />
        <StatsCard label="已使用码数" value={stats.totalCodesUsed} icon={Database} />
        <StatsCard label="剩余可用" value={stats.totalCodesRemaining} icon={Ticket} />
      </section>

      {/* 7 日趋势图（占位） */}
      <ChartCard
        title="近 7 日趋势"
        description="设备注册与邀请激活走势（数据接口待后端扩展）"
      >
        <TrendChart data={trend} />
      </ChartCard>
    </div>
  );
}
```

- [ ] **Step 5: 安装依赖并构建**

```bash
cd lumira-server/packages/admin
npm install
npx next build --no-lint
```

Expected: build 成功。

- [ ] **Step 6: 提交**

```bash
git add lumira-server/packages/admin/src/
git commit -m "feat(admin): dashboard with stats cards and trend chart placeholder"
```

---

## Task 3.0: 邀请记录页

**Files:**
- Modify: `lumira-server/packages/admin/src/app/(dashboard)/invites/page.tsx`
- Create: `lumira-server/packages/admin/src/components/data-table.tsx`
- Create: `lumira-server/packages/admin/src/components/invites-table.tsx`
- Create: `lumira-server/packages/admin/src/components/pagination.tsx`

**Interfaces:**
- Consumes: `api.getInvites({ page, pageSize, deviceId })` 返回 `InviteListResponse`
- Produces: 通用 `DataTable`、`Pagination`、专用 `InvitesTable`

- [ ] **Step 1: 创建 pagination.tsx**

```tsx
// src/components/pagination.tsx
import { Button } from '@/components/ui/button';
import { CaretLeft, CaretRight } from '@phosphor-icons/react/dist/ssr';

export function Pagination({
  page,
  pageSize,
  total,
  basePath,
  searchParams,
}: {
  page: number;
  pageSize: number;
  total: number;
  basePath: string;
  searchParams: Record<string, string | undefined>;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const hasPrev = page > 1;
  const hasNext = page < totalPages;

  function buildUrl(pageNum: number): string {
    const params = new URLSearchParams();
    Object.entries(searchParams).forEach(([k, v]) => {
      if (v !== undefined && k !== 'page') params.set(k, v);
    });
    params.set('page', String(pageNum));
    params.set('pageSize', String(pageSize));
    return `${basePath}?${params.toString()}`;
  }

  return (
    <div className="flex items-center justify-between mt-4">
      <span className="text-sm text-muted-foreground">
        共 {total} 条 · 第 {page} / {totalPages} 页
      </span>
      <div className="flex gap-2">
        <Button asChild variant="outline" size="sm" disabled={!hasPrev}>
          <a href={buildUrl(page - 1)}>
            <CaretLeft size={14} className="mr-1" /> 上一页
          </a>
        </Button>
        <Button asChild variant="outline" size="sm" disabled={!hasNext}>
          <a href={buildUrl(page + 1)}>
            下一页 <CaretRight size={14} className="ml-1" />
          </a>
        </Button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 创建 invites-table.tsx**

```tsx
// src/components/invites-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { InviteListResponse } from '@/types/admin';

const channelLabels: Record<string, string> = {
  direct: '直接',
  share_card: '分享卡片',
  qrcode: '二维码',
};

export function InvitesTable({ data }: { data: InviteListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>邀请人</TableHead>
            <TableHead>被邀请人</TableHead>
            <TableHead className="font-mono">邀请码</TableHead>
            <TableHead>渠道</TableHead>
            <TableHead>激活时间</TableHead>
            <TableHead>邀请人 IP</TableHead>
            <TableHead>被邀请人 IP</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                无邀请记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => (
              <TableRow key={row.id}>
                <TableCell className="text-muted-foreground">{row.id}</TableCell>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.inviterDeviceId)}</TableCell>
                <TableCell className="font-mono text-xs">{truncateDeviceId(row.inviteeDeviceId)}</TableCell>
                <TableCell className="font-mono">{row.inviteCode}</TableCell>
                <TableCell>
                  <Badge variant="secondary">{channelLabels[row.channel] || row.channel}</Badge>
                </TableCell>
                <TableCell className="text-sm">{formatUnixTime(row.activatedAt)}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.inviterIp || '—'}</TableCell>
                <TableCell className="text-xs text-muted-foreground">{row.inviteeIp || '—'}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 3: 重写 invites/page.tsx**

```tsx
// src/app/(dashboard)/invites/page.tsx
import { api } from '@/lib/api';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { MagnifyingGlass } from '@phosphor-icons/react/dist/ssr';
import { InvitesTable } from '@/components/invites-table';
import { Pagination } from '@/components/pagination';

export default async function InvitesPage({
  searchParams,
}: {
  searchParams: { page?: string; pageSize?: string; deviceId?: string };
}) {
  const page = Number(searchParams.page) || 1;
  const pageSize = Number(searchParams.pageSize) || 20;
  const deviceId = searchParams.deviceId;

  let data;
  try {
    data = await api.getInvites({ page, pageSize, deviceId });
  } catch (e) {
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <form className="flex gap-2 items-end">
        <div className="flex-1 max-w-xs">
          <label className="text-sm text-muted-foreground mb-1 block">按设备 ID 筛选</label>
          <Input
            name="deviceId"
            defaultValue={deviceId}
            placeholder="输入完整或部分 device_id"
          />
        </div>
        <Button type="submit" size="sm">
          <MagnifyingGlass size={14} className="mr-1" /> 搜索
        </Button>
      </form>

      <InvitesTable data={data} />

      <Pagination
        page={page}
        pageSize={pageSize}
        total={data.total}
        basePath="/dashboard/invites"
        searchParams={searchParams}
      />
    </div>
  );
}
```

- [ ] **Step 4: 构建**

```bash
npx next build --no-lint
```

Expected: build 成功。

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/admin/src/
git commit -m "feat(admin): invites page with filterable table and pagination"
```

---

## Task 4.0: 兑换码批次管理

**Files:**
- Modify: `lumira-server/packages/admin/src/app/(dashboard)/redeem-batches/page.tsx`
- Create: `lumira-server/packages/admin/src/app/(dashboard)/redeem-batches/new/page.tsx`
- Create: `lumira-server/packages/admin/src/app/(dashboard)/redeem-batches/[id]/page.tsx`
- Create: `lumira-server/packages/admin/src/components/batch-form.tsx`
- Create: `lumira-server/packages/admin/src/components/batches-table.tsx`
- Create: `lumira-server/packages/admin/src/components/batch-codes-table.tsx`
- Create: `lumira-server/packages/admin/src/components/toggle-switch.tsx`
- Create: `lumira-server/packages/admin/src/actions/batch.ts`

**Interfaces:**
- Consumes: `api.getBatches()`, `api.createBatch()`, `api.getBatchDetail()`, `api.toggleBatch()`
- Produces: `createBatchAction`, `toggleBatchAction` Server Actions；批次列表/创建/详情 3 个页面

- [ ] **Step 1: 创建 actions/batch.ts**

```typescript
// src/actions/batch.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { toUnixSeconds } from '@/lib/utils';

export async function createBatchAction(formData: FormData) {
  const codesRaw = formData.get('codes') as string;
  const codes = codesRaw
    .split('\n')
    .map(c => c.trim())
    .filter(Boolean);

  if (codes.length === 0) {
    return { error: '请至少输入一个兑换码' };
  }

  try {
    const validFrom = formData.get('validFrom') as string | null;
    const validUntil = formData.get('validUntil') as string | null;

    const result = await api.createBatch({
      campaignName: formData.get('campaignName') as string,
      codes,
      rewardTier: Number(formData.get('rewardTier')),
      maxUsesPerCode: Number(formData.get('maxUsesPerCode')),
      validFrom: validFrom ? toUnixSeconds(validFrom) : undefined,
      validUntil: validUntil ? toUnixSeconds(validUntil) : undefined,
    });

    revalidatePath('/dashboard/redeem-batches');
    redirect(`/dashboard/redeem-batches/${result.batchId}`);
  } catch (e) {
    return { error: (e as Error).message };
  }
}

export async function toggleBatchAction(batchId: number, isActive: boolean) {
  try {
    await api.toggleBatch(batchId, isActive);
    revalidatePath('/dashboard/redeem-batches');
    revalidatePath(`/dashboard/redeem-batches/${batchId}`);
    return { success: true };
  } catch (e) {
    return { error: (e as Error).message };
  }
}
```

- [ ] **Step 2: 创建 toggle-switch.tsx（client component）**

```tsx
// src/components/toggle-switch.tsx
'use client';

import { useTransition } from 'react';
import { Switch } from '@/components/ui/switch';
import { toggleBatchAction } from '@/actions/batch';

export function ToggleSwitch({
  batchId,
  isActive,
}: {
  batchId: number;
  isActive: boolean;
}) {
  const [isPending, startTransition] = useTransition();

  return (
    <Switch
      checked={isActive}
      disabled={isPending}
      onCheckedChange={(checked) => {
        startTransition(async () => {
          await toggleBatchAction(batchId, checked);
        });
      }}
    />
  );
}
```

- [ ] **Step 3: 创建 batches-table.tsx**

```tsx
// src/components/batches-table.tsx
import Link from 'next/link';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ToggleSwitch } from '@/components/toggle-switch';
import { formatUnixTime } from '@/lib/utils';
import { Eye } from '@phosphor-icons/react/dist/ssr';
import type { Batch } from '@/types/admin';

export function BatchesTable({ batches }: { batches: Batch[] }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>Campaign</TableHead>
            <TableHead>阶梯</TableHead>
            <TableHead className="w-32">使用情况</TableHead>
            <TableHead>有效期</TableHead>
            <TableHead>状态</TableHead>
            <TableHead className="w-40">操作</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {batches.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                无批次
              </TableCell>
            </TableRow>
          ) : (
            batches.map((b) => {
              const active = b.isActive === 1;
              const usedPct = b.totalGenerated > 0
                ? Math.round((b.totalUsed / b.totalGenerated) * 100)
                : 0;
              return (
                <TableRow key={b.batchId}>
                  <TableCell className="text-muted-foreground">{b.batchId}</TableCell>
                  <TableCell className="font-medium">{b.campaignName}</TableCell>
                  <TableCell>
                    <Badge variant="outline">Tier {b.rewardTier}</Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <span className="text-sm">{b.totalUsed}/{b.totalGenerated}</span>
                      <div className="flex-1 max-w-20 h-1.5 bg-muted rounded-full overflow-hidden">
                        <div
                          className="h-full bg-primary rounded-full"
                          style={{ width: `${usedPct}%` }}
                        />
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">
                    {b.validFrom || b.validUntil
                      ? `${b.validFrom ? formatUnixTime(b.validFrom) : '?'} ~ ${b.validUntil ? formatUnixTime(b.validUntil) : '永久'}`
                      : '永久'}
                  </TableCell>
                  <TableCell>
                    <Badge variant={active ? 'default' : 'destructive'}>
                      {active ? '启用' : '已禁用'}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/dashboard/redeem-batches/${b.batchId}`}>
                          <Eye size={14} className="mr-1" /> 详情
                        </Link>
                      </Button>
                      <ToggleSwitch batchId={b.batchId} isActive={active} />
                    </div>
                  </TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 4: 创建 batch-form.tsx（client component，react-hook-form + zod）**

```tsx
// src/components/batch-form.tsx
'use client';

import { useState, useTransition } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { createBatchAction } from '@/actions/batch';

const schema = z.object({
  campaignName: z.string().min(1, '请输入 Campaign 名称').max(100),
  codes: z.string().refine(
    (v) => v.split('\n').map(s => s.trim()).filter(Boolean).length > 0,
    '请至少输入一个兑换码',
  ),
  rewardTier: z.coerce.number().int().min(1),
  maxUsesPerCode: z.coerce.number().int().min(1),
  validFrom: z.string().optional(),
  validUntil: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export default function BatchForm() {
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const { register, handleSubmit, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      campaignName: '',
      codes: '',
      rewardTier: 1,
      maxUsesPerCode: 1,
    },
  });

  const onSubmit = (data: FormValues) => {
    setError(null);
    const formData = new FormData();
    formData.set('campaignName', data.campaignName);
    formData.set('codes', data.codes);
    formData.set('rewardTier', String(data.rewardTier));
    formData.set('maxUsesPerCode', String(data.maxUsesPerCode));
    if (data.validFrom) formData.set('validFrom', data.validFrom);
    if (data.validUntil) formData.set('validUntil', data.validUntil);

    startTransition(async () => {
      const result = await createBatchAction(formData);
      if (result?.error) setError(result.error);
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5 max-w-2xl">
      <div className="space-y-2">
        <Label htmlFor="campaignName">Campaign 名称 *</Label>
        <Input id="campaignName" {...register('campaignName')} placeholder="如：双十一福利" />
        {errors.campaignName && <p className="text-sm text-destructive">{errors.campaignName.message}</p>}
      </div>

      <div className="space-y-2">
        <Label htmlFor="codes">兑换码列表（每行一个）*</Label>
        <Textarea
          id="codes"
          {...register('codes')}
          rows={8}
          placeholder={'CODE001\nCODE002\nCODE003'}
          className="font-mono text-sm"
        />
        {errors.codes && <p className="text-sm text-destructive">{errors.codes.message}</p>}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="rewardTier">关联奖励阶梯 *</Label>
          <Select defaultValue="1" {...register('rewardTier')}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="1">Tier 1（1 次邀请）</SelectItem>
              <SelectItem value="3">Tier 3（3 次邀请）</SelectItem>
              <SelectItem value="5">Tier 5（5 次邀请）</SelectItem>
              <SelectItem value="10">Tier 10（10 次邀请）</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="maxUsesPerCode">每码最大使用次数 *</Label>
          <Input id="maxUsesPerCode" type="number" min={1} {...register('maxUsesPerCode')} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="validFrom">有效期起（可选）</Label>
          <Input id="validFrom" type="datetime-local" {...register('validFrom')} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="validUntil">有效期止（可选）</Label>
          <Input id="validUntil" type="datetime-local" {...register('validUntil')} />
        </div>
      </div>

      {error && <p className="text-sm text-destructive" role="alert">{error}</p>}

      <Button type="submit" disabled={isPending}>
        {isPending ? '提交中…' : '创建批次'}
      </Button>
    </form>
  );
}
```

注：`Textarea` 是 shadcn/ui 组件，需要单独创建 `src/components/ui/textarea.tsx`：

```tsx
// src/components/ui/textarea.tsx
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface TextareaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {}

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, ...props }, ref) => {
    return (
      <textarea
        className={cn(
          'flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
          className,
        )}
        ref={ref}
        {...props}
      />
    );
  },
);
Textarea.displayName = 'Textarea';

export { Textarea };
```

- [ ] **Step 5: 创建 batch-codes-table.tsx**

```tsx
// src/components/batch-codes-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import type { BatchDetail } from '@/types/admin';

export function BatchCodesTable({ codes }: { codes: BatchDetail['codes'] }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="font-mono">兑换码</TableHead>
            <TableHead className="w-40">使用次数</TableHead>
            <TableHead className="w-32">使用率</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {codes.length === 0 ? (
            <TableRow>
              <TableCell colSpan={3} className="text-center text-muted-foreground py-8">无码</TableCell>
            </TableRow>
          ) : (
            codes.map((c) => {
              const pct = c.maxUses > 0 ? Math.round((c.usedCount / c.maxUses) * 100) : 0;
              const fullyUsed = c.usedCount >= c.maxUses;
              return (
                <TableRow key={c.code}>
                  <TableCell className="font-mono">{c.code}</TableCell>
                  <TableCell className="text-sm">
                    {c.usedCount} / {c.maxUses}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 max-w-20 h-1.5 bg-muted rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full ${fullyUsed ? 'bg-success' : 'bg-primary'}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                      <span className="text-xs text-muted-foreground w-10">{pct}%</span>
                    </div>
                  </TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 6: 重写 redeem-batches/page.tsx**

```tsx
// src/app/(dashboard)/redeem-batches/page.tsx
import Link from 'next/link';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Plus } from '@phosphor-icons/react/dist/ssr';
import { BatchesTable } from '@/components/batches-table';

export default async function RedeemBatchesPage() {
  let batches;
  try {
    batches = await api.getBatches();
  } catch (e) {
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button asChild>
          <Link href="/dashboard/redeem-batches/new">
            <Plus size={16} className="mr-1" /> 创建批次
          </Link>
        </Button>
      </div>
      <BatchesTable batches={batches} />
    </div>
  );
}
```

- [ ] **Step 7: 创建 new/page.tsx**

```tsx
// src/app/(dashboard)/redeem-batches/new/page.tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import BatchForm from '@/components/batch-form';

export default function NewBatchPage() {
  return (
    <Card className="max-w-3xl">
      <CardHeader>
        <CardTitle className="text-left">创建兑换码批次</CardTitle>
      </CardHeader>
      <CardContent>
        <BatchForm />
      </CardContent>
    </Card>
  );
}
```

注：需要 import 时使用 `Card`、`CardContent`、`CardHeader`、`CardTitle`——shadcn/ui Card 组件已有这些导出。

- [ ] **Step 8: 创建 [id]/page.tsx**

```tsx
// src/app/(dashboard)/redeem-batches/[id]/page.tsx
import { notFound } from 'next/navigation';
import { api } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ToggleSwitch } from '@/components/toggle-switch';
import { BatchCodesTable } from '@/components/batch-codes-table';
import { formatUnixTime } from '@/lib/utils';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';
import Link from 'next/link';

export default async function BatchDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const batchId = Number(params.id);
  if (Number.isNaN(batchId)) notFound();

  let detail;
  try {
    detail = await api.getBatchDetail(batchId);
  } catch (e) {
    if ((e as Error).message.includes('404')) notFound();
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  const active = detail.isActive === 1;

  return (
    <div className="space-y-4">
      <Button asChild variant="ghost" size="sm">
        <Link href="/dashboard/redeem-batches">
          <ArrowLeft size={14} className="mr-1" /> 返回列表
        </Link>
      </Button>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-left">{detail.campaignName}</CardTitle>
            <p className="text-sm text-muted-foreground mt-1 text-left">
              批次 #{detail.batchId} · 创建于 {formatUnixTime(detail.createdAt)}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <Badge variant={active ? 'default' : 'destructive'}>
              {active ? '启用' : '已禁用'}
            </Badge>
            <ToggleSwitch batchId={detail.batchId} isActive={active} />
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <p className="text-muted-foreground">奖励阶梯</p>
              <p className="mt-1"><Badge variant="outline">Tier {detail.rewardTier}</Badge></p>
            </div>
            <div>
              <p className="text-muted-foreground">每码上限</p>
              <p className="mt-1">{detail.maxUsesPerCode} 次</p>
            </div>
            <div>
              <p className="text-muted-foreground">有效期</p>
              <p className="mt-1 text-xs">
                {detail.validFrom || detail.validUntil
                  ? `${detail.validFrom ? formatUnixTime(detail.validFrom) : '?'} ~ ${detail.validUntil ? formatUnixTime(detail.validUntil) : '永久'}`
                  : '永久'}
              </p>
            </div>
            <div>
              <p className="text-muted-foreground">总量/已用</p>
              <p className="mt-1">{detail.totalUsed} / {detail.totalGenerated}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <div>
        <h3 className="text-base font-medium text-foreground mb-3 text-left">码列表</h3>
        <BatchCodesTable codes={detail.codes} />
      </div>
    </div>
  );
}
```

- [ ] **Step 9: 构建验证**

```bash
npx next build --no-lint
```

Expected: build 成功。

- [ ] **Step 10: 提交**

```bash
git add lumira-server/packages/admin/src/
git commit -m "feat(admin): redeem batches list, create form, detail page, toggle"
```

---

## Task 5.0: 奖励明细页

**Files:**
- Modify: `lumira-server/packages/admin/src/app/(dashboard)/rewards/page.tsx`
- Create: `lumira-server/packages/admin/src/components/rewards-table.tsx`

**Interfaces:**
- Consumes: `api.getRewards({ page, pageSize, deviceId })` 返回 `RewardListResponse`

- [ ] **Step 1: 创建 rewards-table.tsx**

```tsx
// src/components/rewards-table.tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { RewardListResponse } from '@/types/admin';

const sourceLabels: Record<string, { label: string; variant: 'default' | 'secondary' }> = {
  invite: { label: '邀请', variant: 'default' },
  redemption: { label: '兑换码', variant: 'secondary' },
};

export function RewardsTable({ data }: { data: RewardListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>设备 ID</TableHead>
            <TableHead>阶梯</TableHead>
            <TableHead>来源</TableHead>
            <TableHead>来源详情</TableHead>
            <TableHead>解锁时间</TableHead>
            <TableHead>状态</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                无奖励解锁记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((r) => {
              const src = sourceLabels[r.source] || { label: r.source, variant: 'secondary' as const };
              const claimed = r.status === 'claimed';
              return (
                <TableRow key={r.id}>
                  <TableCell className="text-muted-foreground">{r.id}</TableCell>
                  <TableCell className="font-mono text-xs">{truncateDeviceId(r.deviceId)}</TableCell>
                  <TableCell><Badge variant="outline">Tier {r.tier}</Badge></TableCell>
                  <TableCell>
                    <Badge variant={src.variant}>{src.label}</Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {r.sourceDetail || '—'}
                  </TableCell>
                  <TableCell className="text-sm">{formatUnixTime(r.unlockedAt)}</TableCell>
                  <TableCell>
                    <Badge variant={claimed ? 'default' : 'outline'}>
                      {claimed ? '已领取' : '已解锁'}
                    </Badge>
                  </TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 2: 重写 rewards/page.tsx**

```tsx
// src/app/(dashboard)/rewards/page.tsx
import { api } from '@/lib/api';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { MagnifyingGlass } from '@phosphor-icons/react/dist/ssr';
import { RewardsTable } from '@/components/rewards-table';
import { Pagination } from '@/components/pagination';

export default async function RewardsPage({
  searchParams,
}: {
  searchParams: { page?: string; pageSize?: string; deviceId?: string };
}) {
  const page = Number(searchParams.page) || 1;
  const pageSize = Number(searchParams.pageSize) || 20;
  const deviceId = searchParams.deviceId;

  let data;
  try {
    data = await api.getRewards({ page, pageSize, deviceId });
  } catch (e) {
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <form className="flex gap-2 items-end">
        <div className="flex-1 max-w-xs">
          <label className="text-sm text-muted-foreground mb-1 block">按设备 ID 筛选</label>
          <Input
            name="deviceId"
            defaultValue={deviceId}
            placeholder="输入完整或部分 device_id"
          />
        </div>
        <Button type="submit" size="sm">
          <MagnifyingGlass size={14} className="mr-1" /> 搜索
        </Button>
      </form>

      <RewardsTable data={data} />

      <Pagination
        page={page}
        pageSize={pageSize}
        total={data.total}
        basePath="/dashboard/rewards"
        searchParams={searchParams}
      />
    </div>
  );
}
```

- [ ] **Step 3: 构建验证**

```bash
npx next build --no-lint
```

Expected: build 成功。

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/admin/src/
git commit -m "feat(admin): rewards page with filterable table and pagination"
```

---

## 最终验证

- [ ] **全量构建**：`cd lumira-server/packages/admin && npx next build --no-lint`
- [ ] **单元测试**：`npx vitest run`
- [ ] **手测登录流程**：启动后端 (`cd packages/backend && npm run start:dev`) → 启动前端 (`cd packages/admin && npm run dev`) → 访问 http://localhost:3001 → 应跳转 /login → 输入 `dev-admin-token` → 应跳转 /dashboard → 看到 4 个占位链接 → 点击各链接可访问

## Self-Review

1. **Spec coverage**：4 个页面 + 认证 + 布局 → 全部覆盖。CSV 导出和 7 日趋势数据因后端缺口已在 spec §10 标注。
2. **Placeholder scan**：无 TBD/TODO，所有步骤含完整代码。
3. **Type consistency**：`api.ts` 的返回类型与 `types/admin.ts` 一致；`@lumira/shared` 类型在 admin 中复用。
4. **Known gaps**：
   - shadcn/ui 基础组件（Task 1.0 Step 1）需 implementer 从官方源码 verbatim 复制（subagent 可访问 ui.shadcn.com 文档页面获取）。如网络受限，可改用最小手写版本（只包含项目实际用到的 props/variants）。
   - `Textarea` 组件 shadcn/ui 官方有但需要单独 add，已在 Task 4.0 Step 4 提供 verbatim 源码。
   - Phosphor Icons 的 SSR 导入路径 `@phosphor-icons/react/dist/ssr` 适用于 Next.js Server Components。
