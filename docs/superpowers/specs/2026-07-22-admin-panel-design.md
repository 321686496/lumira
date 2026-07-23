# 后台管理面板设计

> **关联设计**：[2026-07-22-lightweight-server-design.md](./2026-07-22-lightweight-server-design.md) §6 运营后台功能规格
> **后端依赖**：lumira-server `ae8a4758`（Admin API 已全部就绪，7 个端点）

## 1. 目标

为运营人员提供 Web 后台，管理邀请记录、兑换码批次、奖励解锁记录，并查看业务概览统计。面板只调用已存在的 `/api/v1/admin/*` 端点，不修改后端。

## 2. 技术栈

| 类别 | 选型 | 理由 |
|---|---|---|
| 框架 | Next.js 14 (App Router) + React 18 | spec §4 指定；Vercel 原生部署 |
| UI 组件 | shadcn/ui (Radix UI + Tailwind) | 源码复制式组件，完全可定制；与 Morandi 色系兼容 |
| 图标 | `@phosphor-icons/react` | 与用户既有偏好一致 |
| 样式 | Tailwind CSS 3 | 用户既有偏好；shadcn/ui 依赖 |
| 表单 | `react-hook-form` + `zod` + shadcn/ui Form | 类型安全 + 受控校验 |
| 图表 | shadcn/ui Charts (基于 recharts) | 与设计系统一致；使用 CSS 变量主题色 |
| 数据获取 | Server Components + fetch | RSC 模式，最少客户端 JS |
| Mutations | React Server Actions | 表单提交直接走 Server Action，无 API 路由 |
| 认证 | httpOnly Cookie + Next.js middleware | 简单、安全、Vercel 友好 |
| 测试 | Vitest + React Testing Library | 单元测试；E2E 留待 Phase 3 |
| 部署 | Vercel | spec §5 指定 |

## 3. 架构概览

```
lumira-server/packages/admin/         # Next.js 应用
├── src/
│   ├── app/
│   │   ├── layout.tsx                 # 根布局（字体、ThemeProvider）
│   │   ├── globals.css                # Tailwind + Morandi CSS 变量
│   │   ├── middleware.ts              # 路由守卫：未登录 → /login
│   │   ├── (auth)/
│   │   │   └── login/page.tsx         # 登录页（输入 ADMIN_TOKEN）
│   │   └── (dashboard)/
│   │       ├── layout.tsx             # 已认证布局（Sidebar + Topbar）
│   │       ├── dashboard/page.tsx     # 概览统计 + 7 日趋势图
│   │       ├── invites/page.tsx       # 邀请记录表格（分页+筛选）
│   │       ├── redeem-batches/
│   │       │   ├── page.tsx           # 批次列表
│   │       │   ├── new/page.tsx       # 创建新批次（表单）
│   │       │   └── [id]/page.tsx      # 批次详情（码列表+使用情况）
│   │       └── rewards/page.tsx       # 奖励解锁记录表格
│   ├── components/
│   │   ├── ui/                        # shadcn/ui 生成的基础组件
│   │   ├── sidebar.tsx                # 左侧导航
│   │   ├── stats-card.tsx             # Dashboard 统计卡片
│   │   ├── data-table.tsx             # 通用表格（基于 @tanstack/react-table）
│   │   ├── chart-card.tsx             # 图表容器
│   │   ├── batch-form.tsx             # 创建批次表单
│   │   ├── toggle-switch.tsx          # 批次启用/禁用开关
│   │   └── auth-provider.tsx          # 客户端 token context（仅 /login 用）
│   ├── lib/
│   │   ├── api.ts                     # 后端 API 客户端（Server 端 fetch 封装）
│   │   ├── auth.ts                    # cookie 读写 + 校验逻辑
│   │   └── utils.ts                   # cn() 等工具
│   ├── actions/
│   │   ├── login.ts                   # 登录 Server Action
│   │   ├── logout.ts                  # 登出 Server Action
│   │   └── batch.ts                   # 批次创建/切换 Server Actions
│   └── types/
│       └── admin.ts                   # 后台专属类型（stats/批量详情扩展）
├── package.json                       # name: @lumira/admin
├── next.config.js
├── tailwind.config.ts
├── tsconfig.json
└── components.json                    # shadcn/ui 配置
```

## 4. 认证设计

### 4.1 流程

1. 用户访问任意 `(dashboard)/*` 路径
2. `middleware.ts` 检查 `admin_token` cookie 是否存在
3. 不存在或无效 → 重定向到 `/login?from=原路径`
4. `/login` 页面：输入 token → 提交触发 `loginAction`
5. `loginAction` 调用后端 `GET /api/v1/admin/stats` 测试 token 有效性
6. 有效 → 写入 `admin_token` httpOnly cookie（30 天过期）→ 重定向 `from` 或 `/dashboard`
7. 无效 → 返回错误信息显示在登录页

### 4.2 安全措施

- Cookie 属性：`httpOnly` + `secure`（生产）+ `sameSite: 'lax'` + `maxAge: 30d`
- 登录尝试不限速（后端已通过简单字符串比较，无时序敏感操作）
- 登出清除 cookie 并重定向 `/login`
- `BACKEND_URL` 通过环境变量注入，不硬编码

### 4.3 Middleware 实现

```typescript
// src/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('admin_token')?.value;
  const isLoginPage = request.nextUrl.pathname.startsWith('/login');

  if (!token && !isLoginPage) {
    return NextResponse.redirect(new URL('/login', request.url));
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

## 5. 页面规格

### 5.1 Dashboard (`/dashboard`)

**数据源**：`GET /api/v1/admin/stats`

**布局**：
```
┌────────────────────────────────────────────────────┐
│  [4 个统计卡片 - 2x2 grid]                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │累计设备    │ │今日新增   │ │累计邀请   │ │今日邀请 │ │
│  │ 1,234     │ │   12     │ │   567    │ │   3   │ │
│  └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│                                                      │
│  [3 个兑换码卡片 - 1x3 grid]                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │已生成      │ │已使用     │ │剩余可用    │             │
│  │  120      │ │  35      │ │  85      │             │
│  └──────────┘ └──────────┘ └──────────┘             │
│                                                      │
│  [7 日趋势图]                                         │
│  ┌────────────────────────────────────────┐         │
│  │ 设备注册 + 邀请激活 双折线               │         │
│  └────────────────────────────────────────┘         │
└────────────────────────────────────────────────────┘
```

**实现**：
- Server Component 直接 fetch `/admin/stats`
- 趋势图用 shadcn/ui Charts（LineChart）渲染 7 天数据
- 注：后端 `getStats()` 目前只返回累计/今日数据，7 日趋势数据需要后续后端扩展（见 §10 已知限制）

### 5.2 邀请记录 (`/dashboard/invites`)

**数据源**：`GET /api/v1/admin/invites?page=1&pageSize=20&deviceId=xxx`

**表格列**：

| 列 | 字段 | 格式化 |
|---|---|---|
| ID | `id` | 数字 |
| 邀请人 | `inviterDeviceId` | 截断显示前 8 位 + `…` |
| 被邀请人 | `inviteeDeviceId` | 同上 |
| 邀请码 | `inviteCode` | 6 位等宽字体 |
| 渠道 | `channel` | 标签（badge） |
| 激活时间 | `activatedAt` | `YYYY-MM-DD HH:mm` |
| 邀请人 IP | `inviterIp` | — |
| 被邀请人 IP | `inviteeIp` | — |

**筛选**：
- `deviceId` 搜索框（搜索按钮触发刷新）
- 分页：上一页/下一页 + 页码跳转

### 5.3 兑换码批次 (`/dashboard/redeem-batches`)

**列表数据源**：`GET /api/v1/admin/redeem-batches`

**表格列**：

| 列 | 格式化 |
|---|---|
| 批次 ID | 数字 |
| Campaign 名称 | 文本 |
| 奖励阶梯 | `Tier N` badge |
| 总量 / 已用 / 剩余 | `35/120` 进度条 |
| 有效期 | `2024-01-01 ~ 2024-12-31` 或 `永久` |
| 状态 | 绿色"启用" / 红色"已禁用" |
| 操作 | 详情 / 启用切换 |

**创建批次页 (`/new`)**：
- 表单字段：
  - Campaign 名称（text，必填，max 100）
  - 兑换码列表（textarea，每行一个码，必填，≥1 行）
  - 关联奖励阶梯（select，1/3/5/10）
  - 每码最大使用次数（number，默认 1，min 1）
  - 有效期起（datetime-local，可选）
  - 有效期止（datetime-local，可选）
- 提交 → Server Action `createBatchAction` → 调后端 `POST /admin/redeem-batches`
- 成功 → 重定向到批次详情页
- 失败 → 表单上方显示错误

**批次详情页 (`/[id]`)**：
- 批次元信息卡片（名称、阶梯、有效期、状态）
- 码列表表格（code、已用次数 / 上限、进度条）
- 启用/禁用切换按钮

### 5.4 奖励明细 (`/dashboard/rewards`)

**数据源**：`GET /api/v1/admin/rewards?page=1&pageSize=20&deviceId=xxx`

**表格列**：

| 列 | 格式化 |
|---|---|
| ID | 数字 |
| 设备 ID | 截断前 8 位 |
| 阶梯 | `Tier N` badge |
| 来源 | `邀请` / `兑换码` badge（不同色） |
| 来源详情 | 邀请码或兑换码（等宽字体） |
| 解锁时间 | `YYYY-MM-DD HH:mm` |
| 领取状态 | `已解锁` / `已领取` badge |

**筛选**：deviceId 搜索 + 来源下拉 + 状态下拉

## 6. 主题设计（Morandi 色系）

### 6.1 CSS 变量（`globals.css`）

```css
:root {
  /* 背景 */
  --background: 30 20% 96%;          /* #F5F3F0 暖白 */
  --foreground: 0 0% 24%;             /* #3D3D3D 深灰 */

  /* 卡片 */
  --card: 0 0% 100%;                  /* 纯白 */
  --card-foreground: 0 0% 24%;

  /* 主色 - 莫兰迪灰蓝 */
  --primary: 210 14% 54%;             /* #7C8B9A */
  --primary-foreground: 30 20% 98%;

  /* 强调色 - 莫兰迪粉 */
  --accent: 20 22% 70%;               /* #C4A49A */
  --accent-foreground: 0 0% 24%;

  /* 边框/分隔 */
  --border: 30 10% 88%;               /* #E4DFD8 */
  --input: 30 10% 88%;
  --ring: 210 14% 54%;

  /* 状态色（莫兰迪化） */
  --success: 130 15% 60%;             /* 莫兰迪绿 */
  --warning: 35 25% 65%;              /* 莫兰迪橙 */
  --destructive: 0 15% 60%;           /* 莫兰迪红 */

  /* 图表色板 */
  --chart-1: 210 14% 54%;             /* 灰蓝（设备线） */
  --chart-2: 20 22% 70%;              /* 粉（邀请线） */
  --chart-3: 130 15% 60%;             /* 绿 */
  --chart-4: 35 25% 65%;              /* 橙 */
}
```

### 6.2 视觉风格

- 标题栏左对齐（用户偏好）
- 卡片圆角 12px，阴影 `0 1px 3px rgba(0,0,0,0.04)`
- 按钮 padding 紧凑（`px-4 py-2 text-sm`）
- 表格行高 48px，斑马纹（偶数行 `bg-muted/30`）

## 7. 后端 API 客户端

### 7.1 `lib/api.ts`

```typescript
// Server-side only — reads token from cookies()
import { cookies } from 'next/headers';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const token = cookies().get('admin_token')?.value;
  if (!token) throw new Error('UNAUTHENTICATED');

  const res = await fetch(`${BACKEND_URL}/api/v1/admin${path}`, {
    ...init,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...init?.headers,
    },
    cache: 'no-store',
  });

  if (res.status === 401) throw new Error('UNAUTHENTICATED');
  if (res.status === 404) throw new Error('NOT_FOUND');
  if (!res.ok) throw new Error(`API_ERROR: ${res.status}`);

  return res.json();
}

export const api = {
  getStats: () => adminFetch<StatsResponse>('/stats'),
  getInvites: (params) => adminFetch<InvitesResponse>(`/invites?${new URLSearchParams(params)}`),
  getBatches: () => adminFetch<Batch[]>('/redeem-batches'),
  createBatch: (data) => adminFetch('/redeem-batches', { method: 'POST', body: JSON.stringify(data) }),
  getBatchDetail: (id) => adminFetch<BatchDetail>(`/redeem-batches/${id}`),
  toggleBatch: (id, isActive) => adminFetch(`/redeem-batches/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ isActive }),
  }),
  getRewards: (params) => adminFetch<RewardsResponse>(`/rewards?${new URLSearchParams(params)}`),
};
```

### 7.2 错误处理

- `UNAUTHENTICATED` → Server Component 抛出 → 触发 `redirect('/login')`
- `NOT_FOUND` → 渲染 404 页面
- `API_ERROR` → 渲染错误卡片 + 重试按钮

## 8. Server Actions

### 8.1 登录

```typescript
// src/actions/login.ts
'use server';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export async function loginAction(formData: FormData) {
  const token = formData.get('adminToken') as string;
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';

  // 验证 token 有效性
  const res = await fetch(`${backendUrl}/api/v1/admin/stats`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });

  if (!res.ok) {
    return { error: 'Token 无效，请检查后重试' };
  }

  cookies().set('admin_token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 30,  // 30 天
    path: '/',
  });

  redirect('/dashboard');
}
```

### 8.2 创建批次

```typescript
// src/actions/batch.ts
'use server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';

export async function createBatchAction(formData: FormData) {
  const codes = (formData.get('codes') as string)
    .split('\n')
    .map(c => c.trim())
    .filter(Boolean);

  try {
    const result = await api.createBatch({
      campaignName: formData.get('campaignName') as string,
      codes,
      rewardTier: Number(formData.get('rewardTier')),
      maxUsesPerCode: Number(formData.get('maxUsesPerCode')),
      validFrom: formData.get('validFrom') ? toUnix(formData.get('validFrom') as string) : undefined,
      validUntil: formData.get('validUntil') ? toUnix(formData.get('validUntil') as string) : undefined,
    });
    revalidatePath('/dashboard/redeem-batches');
    redirect(`/dashboard/redeem-batches/${result.batchId}`);
  } catch (e) {
    return { error: (e as Error).message };
  }
}

export async function toggleBatchAction(batchId: number, isActive: boolean) {
  await api.toggleBatch(batchId, isActive);
  revalidatePath('/dashboard/redeem-batches');
  revalidatePath(`/dashboard/redeem-batches/${batchId}`);
}
```

## 9. 部署架构

```
GitHub push → GitHub Actions (deploy-admin.yml)
              → npm ci
              → npm run build (Next.js)
              → Vercel deploy --prod

Vercel 环境:
  - BACKEND_URL=https://api.lumira.app
  - NEXT_PUBLIC_APP_NAME=Lumira Admin
```

Vercel 项目根目录设为 `packages/admin/`，monorepo 检测会自动识别 `@lumira/shared` 依赖。

## 10. 已知限制

1. **7 日趋势图数据缺失**：后端 `getStats()` 当前只返回累计/今日数据，无 7 日时序。Dashboard 趋势图先用占位骨架，待后端扩展 `/admin/stats/trend` 端点（已记入后续 backlog）。
2. **CSV 导出未实现**：spec §6.2/6.4 提到 CSV 导出，但后端目前无 `/admin/invites/export` 端点。本期前端先不实现导出按钮，待后端补充。
3. **无 E2E 测试**：MVP 仅做单元测试 + 手动验证。Playwright E2E 留待 Phase 3。
4. **单管理员**：无多用户/RBAC，全量后台权限。spec §11 Phase 3 再加。

## 11. 任务分解（为后续 writing-plans 提供输入）

| Task | 范围 | 依赖 |
|---|---|---|
| 0.1 | 脚手架：Next.js + Tailwind + shadcn/ui 初始化，基础配置，依赖安装 | 后端已完成 |
| 1.0 | 认证 + 布局：middleware、login 页、`(dashboard)` layout、Sidebar、api 客户端 | Task 0.1 |
| 2.0 | Dashboard 页：stats 卡片 + 占位趋势图 | Task 1.0 |
| 3.0 | 邀请记录页：DataTable + 筛选 + 分页 | Task 1.0 |
| 4.0 | 兑换码批次管理：列表 + 创建表单 + 详情页 + 切换 | Task 1.0 |
| 5.0 | 奖励明细页：DataTable + 筛选 + 分页 | Task 1.0 |

## 12. 验收标准

- [ ] `/login` 能正确校验 ADMIN_TOKEN 并写入 cookie
- [ ] 未登录访问 `/dashboard/*` 自动重定向 `/login`
- [ ] Dashboard 显示 7 个统计卡片 + 趋势图占位
- [ ] 邀请记录页能分页、按 deviceId 筛选
- [ ] 创建批次表单能提交并跳转到详情页
- [ ] 批次详情页显示码列表和使用进度
- [ ] 批次启用/禁用切换即时生效
- [ ] 奖励明细页能分页、按 deviceId/来源/状态筛选
- [ ] 所有页面采用 Morandi 色系
- [ ] `npm run build` 成功（无 TypeScript 错误）
- [ ] `npm run lint` 通过
