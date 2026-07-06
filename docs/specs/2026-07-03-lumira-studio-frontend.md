# 画集 Lumira Studio 前端设计文档

> 文档版本：v1.0
> 创建日期：2026-07-03
> 文档类型：前端工程规格（Frontend Engineering Spec）
> 产品版本：画集 Lumira Studio · 联网版
> 框架：uni-app (Vue3 + TypeScript)
> 设计范式：Harness Engineering（骨架优先，接口驱动，规格验证）

---

## 0. 文档说明

本文档定义「画集 Lumira Studio」前端工程的完整设计。遵循 Harness Engineering 范式：
1. **骨架优先**：先定义组件树、路由、数据流等结构，再填充实现
2. **接口驱动**：组件/模块通过类型化的 Props/Events/Slots 通信
3. **规格验证**：每个页面有明确定义的 Spec 与验收标准

配套文档：
- PRD：`../superpowers/specs/2026-07-03-lumira-studio-prd.md`
- 品牌设计：`../superpowers/specs/2026-07-03-lumira-studio-brand.md`
- AGENT.md：`../../AGENT.md`

---

## 1. 技术选型

| 层 | 选择 | 理由 |
|---|---|---|
| 框架 | uni-app (Vue3.4 + Composition API) | 跨平台输出 iOS / Android |
| 语言 | TypeScript strict mode | 类型安全是 Harness 的基础 |
| 状态管理 | Pinia | 轻量、Vue3 原生、TS 友好 |
| 路由 | uni-app pages.json + uni-simple-router | 原生 Tab + 页面栈 |
| 样式方案 | CSS Variables（设计 Token）+ SCSS | 品牌色/间距/字体统一管理 |
| HTTP 请求 | uni.request + Axios 封装 | 统一拦截/错误处理 |
| 图像处理 | 原生 C++ 插件（本地）+ 云端 API | 双端处理 |
| 相机 | uni-app camera + nvue/原生插件 | 取景器叠图需高性能渲染 |
| 本地存储 | SQLite（@dcloudio/uni-sqlite） | 模板/照片索引持久化 |
| H5 渲染 | 原生 Canvas + WebGL | LUT/滤镜 |
| 代码规范 | ESLint + Prettier + Husky | 工程纪律 |

### 1.1 推荐依赖

```json
{
  "dependencies": {
    "vue": "^3.4.0",
    "pinia": "^2.1.0",
    "uni-simple-router": "^3.0.0",
    "@dcloudio/uni-sqlite": "^1.0.0",
    "axios": "^1.6.0",
    "dayjs": "^1.11.0"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "sass": "^1.70.0",
    "@types/node": "^20.0.0",
    "eslint": "^8.56.0",
    "@typescript-eslint/parser": "^6.0.0",
    "prettier": "^3.2.0"
  }
}
```

---

## 2. 工程目录结构

```
lumira-studio/                 # 画集 联网版工程根目录
├── src/
│   ├── App.vue                # 应用根组件
│   ├── main.ts                # 入口文件
│   ├── manifest.json           # uni-app 配置
│   ├── pages.json              # 页面路由配置
│   ├── uni.scss                # 全局 SCSS 变量
│   │
│   ├── pages/                  # 页面目录
│   │   ├── home/               # 首页（推荐流）
│   │   │   ├── index.vue
│   │   │   └── search.vue      # 全局搜索
│   │   ├── marketplace/        # 模板市场
│   │   │   ├── index.vue       #   市场首页
│   │   │   ├── detail.vue      #   模板详情
│   │   │   ├── upload.vue      #   模板上传
│   │   │   └── my-purchases.vue # 我的购买
│   │   ├── capture/            # 拍摄模块
│   │   │   ├── index.vue       #   拍摄页
│   │   │   └── ai-assist.vue   #   AI 辅助拍摄页
│   │   ├── community/          # 社区模块
│   │   │   ├── index.vue       #   社区首页
│   │   │   ├── detail.vue      #   作品详情
│   │   │   ├── publish.vue     #   作品发布
│   │   │   ├── challenge.vue   #   挑战赛
│   │   │   └── challenge-submit.vue # 挑战赛提交
│   │   ├── creator/            # 创作者中心
│   │   │   ├── dashboard.vue   #   数据看板
│   │   │   ├── earnings.vue    #   收益管理
│   │   │   ├── fans.vue        #   粉丝管理
│   │   │   └── certification.vue # 创作者认证
│   │   ├── profile/            # 个人/账户
│   │   │   ├── index.vue       #   我的
│   │   │   ├── settings.vue    #   设置
│   │   │   ├── wallet.vue      #   钱包
│   │   │   ├── orders.vue      #   订单
│   │   │   └── membership.vue  #   会员中心
│   │   └── auth/               # 认证
│   │       ├── login.vue       #   登录
│   │       ├── register.vue    #   注册
│   │       └── forgot.vue      #   找回密码
│   │
│   ├── components/             # 可复用组件
│   │   ├── camera/             #   相机相关（复用了部分如画组件）
│   │   │   ├── CameraViewfinder.vue
│   │   │   ├── OverlayLayer.vue
│   │   │   ├── ShutterButton.vue
│   │   │   └── AiAssistBar.vue     # AI辅助指示条
│   │   ├── image/              #   图像处理
│   │   │   ├── ImageEditor.vue
│   │   │   ├── LutSelector.vue
│   │   │   └── AiEnhanceButton.vue # AI增强按钮
│   │   ├── template/           #   模板相关
│   │   │   ├── TemplateCard.vue        # 市场卡片
│   │   │   ├── TemplateTag.vue
│   │   │   ├── TemplateRating.vue      # 评分
│   │   │   ├── CreatorAvatar.vue       # 创作者头像
│   │   │   └── PriceTag.vue            # 价格标签
│   │   ├── community/          #   社区相关
│   │   │   ├── WorkCard.vue            # 作品卡片
│   │   │   ├── LikeButton.vue          # 点赞按钮（带动画）
│   │   │   ├── CommentList.vue         # 评论列表
│   │   │   ├── CommentInput.vue        # 评论输入
│   │   │   ├── FollowButton.vue        # 关注按钮
│   │   │   └── ReportButton.vue        # 举报
│   │   ├── challenge/          #   挑战赛相关
│   │   │   ├── ChallengeCard.vue
│   │   │   ├── ChallengeBanner.vue
│   │   │   ├── ChallengeRank.vue
│   │   │   └── VoteButton.vue
│   │   ├── payment/            #   支付相关
│   │   │   ├── PriceBadge.vue
│   │   │   ├── PayConfirm.vue
│   │   │   └── WalletBalance.vue
│   │   └── ui/                 #   通用 UI
│   │       ├── AppButton.vue
│   │       ├── AppHeader.vue
│   │       ├── AppTabBar.vue
│   │       ├── AppInput.vue
│   │       ├── AppAvatar.vue
│   │       ├── AppBadge.vue
│   │       ├── AppSkeleton.vue
│   │       ├── AppEmpty.vue
│   │       ├── AppToast.vue
│   │       ├── AppModal.vue
│   │       ├── AppSearchBar.vue        # 搜索条
│   │       ├── AppImageGrid.vue        # 图片网格
│   │       └── AppPullRefresh.vue      # 下拉刷新
│   │
│   ├── composables/            # 可组合逻辑
│   │   ├── useCamera.ts
│   │   ├── useOverlay.ts
│   │   ├── useImageProcessing.ts
│   │   ├── useTemplateEngine.ts
│   │   ├── useApi.ts              # API 请求封装
│   │   ├── useAuth.ts             # 认证状态
│   │   ├── usePayment.ts          # 支付流程
│   │   ├── useNotification.ts     # 消息通知
│   │   ├── useSearch.ts           # 搜索
│   │   ├── usePagination.ts       # 分页/无限滚动
│   │   └── useChallenge.ts        # 挑战赛
│   │
│   ├── stores/                 # Pinia 状态仓库
│   │   ├── auth.ts             #   认证/用户
│   │   ├── capture.ts          #   拍摄
│   │   ├── marketplace.ts      #   模板市场
│   │   ├── community.ts        #   社区
│   │   ├── creator.ts          #   创作者中心
│   │   ├── wallet.ts           #   钱包
│   │   └── notification.ts     #   通知
│   │
│   ├── services/               # 服务层
│   │   ├── api/                #   API 接口
│   │   │   ├── client.ts       #   HTTP 客户端（Axios 实例）
│   │   │   ├── auth.ts         #   认证 API
│   │   │   ├── templates.ts    #   模板 API
│   │   │   ├── community.ts    #   社区 API
│   │   │   ├── creator.ts      #   创作者 API
│   │   │   ├── payment.ts      #   支付 API
│   │   │   ├── ai.ts           #   AI 服务 API
│   │   │   └── challenge.ts    #   挑战赛 API
│   │   ├── camera.ts           #   相机原生服务
│   │   ├── imageProcessor.ts   #   图像处理引擎
│   │   ├── templateEngine.ts   #   模板引擎
│   │   └── storage.ts          #   本地存储
│   │
│   ├── types/                  # TypeScript 类型
│   │   ├── api.ts              #   API 响应类型
│   │   ├── model.ts            #   数据模型
│   │   ├── template.ts         #   .pptpl 类型
│   │   ├── auth.ts             #   认证类型
│   │   ├── payment.ts          #   支付类型
│   │   └── native.ts           #   原生插件接口类型
│   │
│   ├── tokens/                 # 设计 Token
│   │   └── studio-tokens.ts    #   画集 Token
│   │
│   ├── utils/                  # 工具函数
│   │   ├── format.ts           #   格式化（价格/时间/数字）
│   │   ├── validate.ts         #   表单校验
│   │   ├── debounce.ts         #   防抖/节流
│   │   └── storage.ts          #   localStorage 封装
│   │
│   └── assets/
│       ├── images/
│       └── icons/
│
├── native/                    # 原生插件
│   ├── ios/
│   └── android/
│
├── package.json
├── tsconfig.json
└── vite.config.ts
```

---

## 3. 页面路由与导航

### 3.1 完整页面清单（22 页）

| 路径 | 页面 | Tab | 说明 |
|---|---|---|---|
| `/pages/home/index` | 首页 | 是 | 推荐流 + Bento 网格 |
| `/pages/home/search` | 搜索 | 否 | 全局搜索 |
| `/pages/marketplace/index` | 模板市场 | 是 | 分类/榜单/搜索 |
| `/pages/marketplace/detail` | 模板详情 | 否 | 含评价/作者/拍同款 |
| `/pages/marketplace/upload` | 模板上传 | 否 | 创作者发布 |
| `/pages/marketplace/my-purchases` | 我的购买 | 否 | 已购模板 |
| `/pages/capture/index` | 拍摄 | 是 | 同单机版 + AI 入口 |
| `/pages/capture/ai-assist` | AI 辅助 | 否 | AI 场景/评分 |
| `/pages/community/index` | 社区 | 是 | 作品瀑布流 |
| `/pages/community/detail` | 作品详情 | 否 | 评论/点赞/拍同款 |
| `/pages/community/publish` | 发布作品 | 否 | 选择模板+图片 |
| `/pages/community/challenge` | 挑战赛 | 否 | 挑战详情/提交 |
| `/pages/community/challenge-submit` | 挑战提交 | 否 | 参赛提交 |
| `/pages/creator/dashboard` | 创作者看板 | 否 | 数据/收入/粉丝 |
| `/pages/creator/earnings` | 收益 | 否 | 提现/明细 |
| `/pages/creator/fans` | 粉丝 | 否 | 粉丝列表 |
| `/pages/creator/certification` | 认证 | 否 | 创作者认证 |
| `/pages/profile/index` | 我的 | 是 | 个人中心 |
| `/pages/profile/settings` | 设置 | 否 | 应用设置 |
| `/pages/profile/wallet` | 钱包 | 否 | 充值/余额 |
| `/pages/profile/orders` | 订单 | 否 | 模板购买记录 |
| `/pages/profile/membership` | 会员中心 | 否 | 会员订阅 |
| `/pages/auth/login` | 登录 | 否 | 手机/微信/Apple |
| `/pages/auth/register` | 注册 | 否 | 新用户注册 |
| `/pages/auth/forgot` | 找回密码 | 否 | 密码重置 |

### 3.2 导航图

```
[Tab: 首页] ──→ /home/index
   ├── 搜索 ──→ /home/search
   └── 模板点击 ──→ /marketplace/detail

[Tab: 市场] ──→ /marketplace/index
   ├── 模板详情 ──→ /marketplace/detail
   │     └── 拍同款 ──→ /capture/index
   ├── 上传模板 ──→ /marketplace/upload
   └── 我的购买 ──→ /marketplace/my-purchases

[Tab: 拍摄] ──→ /capture/index
   └── AI 辅助 ──→ /capture/ai-assist

[Tab: 社区] ──→ /community/index
   ├── 作品详情 ──→ /community/detail
   │     ├── 拍同款 ──→ /marketplace/detail
   │     └── 评论/点赞
   ├── 发布作品 ──→ /community/publish
   └── 挑战赛 ──→ /community/challenge
         └── 参赛 ──→ /community/challenge-submit

[Tab: 我的] ──→ /profile/index
   ├── 设置 ──→ /profile/settings
   ├── 钱包 ──→ /profile/wallet
   ├── 订单 ──→ /profile/orders
   ├── 会员中心 ──→ /profile/membership
   └── 创作者中心 ──→ /creator/dashboard
         ├── 收益 ──→ /creator/earnings
         ├── 粉丝 ──→ /creator/fans
         └── 认证 ──→ /creator/certification

[全局] 未登录时跳转 → /auth/login
                     ├── 注册 → /auth/register
                     └── 找回密码 → /auth/forgot
```

### 3.3 TabBar 配置（悬浮式自定义 Tab 栏 + 中央拍摄凸起）

首页采用**悬浮 Tab 栏**（Floating Tab Bar）：5 Tab 中「拍摄」居中并以圆形凸起于胶囊之上，形成社区类应用的「中央行动按钮」范式。原生 `tabBar` 无法实现悬浮、圆角、凸起与毛玻璃，改用 uni-app **自定义 tabBar** 方案。

**pages.json 中启用自定义 Tab：**

```json
{
  "tabBar": {
    "custom": true,
    "list": [
      { "pagePath": "pages/home/index", "text": "首页" },
      { "pagePath": "pages/marketplace/index", "text": "市场" },
      { "pagePath": "pages/capture/index", "text": "拍摄" },
      { "pagePath": "pages/community/index", "text": "社区" },
      { "pagePath": "pages/profile/index", "text": "我的" }
    ]
  }
}
```

> `custom: true` 隐藏原生 Tab 栏，由全局组件 `FloatingTabBar.vue` 接管渲染。`list` 保留以维持路由约定与 App 端 Tab 页栈管理。

**悬浮 Tab 栏视觉规格**：

| 属性 | 规格 |
|---|---|
| 定位 | `position: fixed`，脱离底部边缘 |
| 底部距离 | `calc(env(safe-area-inset-bottom) + 12px)` |
| 水平内缩 | 左右各 `16px`（`--space-4`） |
| 容器形态 | 圆角胶囊，`border-radius: 9999px`，高 `60px` |
| 背景 | `rgba(255,255,255,0.82)` + `backdrop-filter: blur(20px)` |
| 边框 | `1px solid var(--color-border)` |
| 阴影 | `0 6px 28px rgba(200,101,53,0.10)`（暖橙调柔光） |
| 中央拍摄键 | 直径 `56px` 圆形，暖橙实底 `--color-brand-primary`，凸起于胶囊上方 `20px` |
| 图标（未选中） | `--color-text-tertiary`(#A89888)，22px |
| 图标（选中） | `--color-brand-primary`(#E8845C)，22px + 文字标签 |
| 层级 | `z-index: 900`（中央键 `z-index: 901`） |

---

## 4. 组件树（Harness 骨架）

```
App.vue
├── FloatingTabBar.vue                     # 悬浮胶囊导航（5 Tab，中央拍摄凸起）
│
├── [Tab: 首页] HomeIndex.vue
│   ├── AppHeader.vue                       # 标题栏 + 搜索/通知
│   ├── BentoGrid.vue                       # Bento 网格布局
│   │   ├── FeaturedCard.vue                #   本周精选（大卡片）
│   │   ├── ChallengeCard.vue               #   挑战赛（小卡片）
│   │   └── CreatorCard.vue[]               #   新晋创作者（横向滚动）
│   ├── SectionTitle.vue                    # 区块标题
│   └── AppImageGrid.vue                    # 热门作品瀑布流
│       └── WorkCard.vue[]
│           ├── LikeButton.vue
│           └── FollowButton.vue
│
├── [Tab: 市场] MarketplaceIndex.vue
│   ├── AppHeader.vue
│   ├── AppSearchBar.vue
│   ├── SortTabs.vue                        # 排序标签
│   ├── CategoryTabs.vue                    # 分类标签
│   └── TemplateCard.vue[]                  # 2 列网格
│       ├── PriceTag.vue
│       ├── CreatorAvatar.vue
│       └── TemplateRating.vue
│
├── [Tab: 拍摄] CaptureIndex.vue
│   ├── CameraViewfinder.vue                # 取景器
│   │   ├── OverlayLayer.vue
│   │   ├── ParameterBar.vue
│   │   └── AiAssistBar.vue                 # AI辅助提示
│   ├── ShutterButton.vue
│   └── TemplateTag.vue
│
├── [Tab: 社区] CommunityIndex.vue
│   ├── AppHeader.vue
│   ├── TopicTabs.vue                       # 话题标签
│   ├── ChallengeBanner.vue                 # 挑战赛 Banner
│   └── WorkCard.vue[]                      # 作品瀑布流
│       ├── LikeButton.vue
│       ├── CommentButton.vue
│       └── ShareButton.vue
│
├── [Tab: 我的] ProfileIndex.vue
│   ├── ProfileHeader.vue                   # 头像/昵称/统计
│   ├── ProfileMenu.vue                     # 功能菜单
│   │   ├── WalletEntry.vue
│   │   ├── OrderEntry.vue
│   │   ├── CreatorEntry.vue
│   │   └── SettingsEntry.vue
│   └── MyWorkGrid.vue                      # 我的作品缩略
│
├── TemplateDetail.vue
│   ├── TemplatePreview.vue                 # 模板预览/截图
│   ├── TemplateInfo.vue                    # 元信息/作者/评分
│   ├── CommentList.vue
│   └── ActionBar.vue                       # 购买/收藏/拍同款
│
├── WorkDetail.vue
│   ├── WorkImage.vue                       # 大图展示
│   ├── WorkInfo.vue                        # 模板来源/描述
│   ├── LikeButton.vue
│   └── CommentList.vue
│       └── CommentInput.vue
│
├── ChallengeDetail.vue
│   ├── ChallengeBanner.vue
│   ├── ChallengeRank.vue
│   └── WorkCard.vue[]
│
├── CreatorDashboard.vue
│   ├── StatsOverview.vue                   # 数据概览
│   ├── RevenueChart.vue                    # 收入图表
│   └── TemplateList.vue                    # 我的模板列表
│
└── LoginPage.vue
    ├── PhoneLogin.vue
    ├── SocialLogin.vue                     # 微信/Apple
    └── AgreementCheckbox.vue               # 协议确认
```

---

## 5. 数据流架构

### 5.1 整体数据流动

```
[用户操作] → [Vue 组件] → [Composable] → [Store (Pinia)]
                                             ├── [Service / API] → [后端]
                                             └── [Service / 原生] → [本地]
```

### 5.2 数据流向规则

1. **单向数据流**：组件 → Action → Store → Service/API
2. **请求状态管理**：每个 API 调用封装 `{ data, loading, error }` 三态
3. **乐观更新**：点赞/关注等社交操作先更新 UI 再确认服务端
4. **分页统一模式**：`usePagination` composable 统一管理加载更多
5. **认证态全局**：`auth` store 管理 token，API 拦截器自动注入

### 5.3 核心数据流

**模板购买流程**：
```
PriceTag / PayButton.click
  → usePayment.purchase(templateId)
    → auth.checkToken()
    → wallet.getBalance()
    → balance >= price ?
        YES → api.createOrder(templateId)
            → 微信/支付宝支付
            → api.confirmPayment(orderId)
            → marketplace.addToLibrary(templateId)
        NO  → toast("余额不足") → profile/wallet
    → marketplace store 更新（已购列表）
```

**作品发布流程**：
```
PublishButton.click
  → 选择模板（可选）
  → 选择照片
  → community store.setPublishing(true)
  → api.uploadWork(photo, templateId, description)
    → OSS 上传
    → 创建作品记录
  → community store.addWork(work)
  → router.push('/community/detail', { workId })
```

**AI 修图流程**：
```
AiEnhanceButton.click
  → useImageProcessing.aiEnhance(photoId)
    → api.aiEnhance(photoId)
    → 等待渲染（轮询/WS）
    → 下载处理结果
  → ImageEditor 显示结果
```

---

## 6. API 接口设计

### 6.1 HTTP 客户端配置

```typescript
// services/api/client.ts
const apiClient = axios.create({
  baseURL: 'https://api.lumira-studio.com/v1',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' }
})

// 请求拦截器：注入 Token
apiClient.interceptors.request.use(config => {
  const token = useAuthStore().token
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// 响应拦截器：统一错误处理
apiClient.interceptors.response.use(
  res => res.data,
  err => handleApiError(err)
)
```

### 6.2 核心 API 端点

```
# 认证
POST   /v1/auth/login                    # 登录
POST   /v1/auth/register                 # 注册
POST   /v1/auth/refresh                  # 刷新 Token
GET    /v1/auth/profile                  # 获取用户信息

# 模板
GET    /v1/templates                     # 模板列表（分页/筛选/排序）
GET    /v1/templates/:id                 # 模板详情
POST   /v1/templates                     # 上传模板
PUT    /v1/templates/:id                 # 更新模板
DELETE /v1/templates/:id                 # 下架模板
GET    /v1/templates/:id/versions        # 模板版本历史
POST   /v1/templates/:id/purchase        # 购买模板
GET    /v1/templates/my-purchases        # 我的已购

# 作品
GET    /v1/works                         # 作品列表（瀑布流）
GET    /v1/works/:id                     # 作品详情
POST   /v1/works                         # 发布作品
DELETE /v1/works/:id                     # 删除作品
POST   /v1/works/:id/like               # 点赞/取消
POST   /v1/works/:id/report             # 举报

# 评论
GET    /v1/works/:id/comments            # 评论列表
POST   /v1/works/:id/comments            # 发表评论
DELETE /v1/comments/:id                  # 删除评论

# 挑战赛
GET    /v1/challenges                    # 挑战赛列表
GET    /v1/challenges/:id                # 挑战赛详情
POST   /v1/challenges/:id/submit        # 提交参赛作品
GET    /v1/challenges/:id/rankings       # 排行榜
POST   /v1/challenges/:id/vote          # 投票

# 创作者
GET    /v1/creator/dashboard             # 创作者数据看板
GET    /v1/creator/earnings              # 收益明细
POST   /v1/creator/withdraw             # 提现
POST   /v1/creator/certify              # 提交认证
GET    /v1/creator/followers             # 粉丝列表

# 钱包/支付
GET    /v1/wallet                        # 钱包信息
POST   /v1/wallet/recharge              # 充值
GET    /v1/orders                        # 订单列表

# AI
POST   /v1/ai/scene-recognition         # 场景识别
POST   /v1/ai/composition-score         # 构图评分
POST   /v1/ai/enhance                   # 智能修图（异步）
POST   /v1/ai/portrait-segment          # 人像分割
POST   /v1/ai/pose-evaluate             # 姿态评估

# 通知
GET    /v1/notifications                 # 通知列表
PUT    /v1/notifications/:id/read       # 标记已读
```

### 6.3 API 响应标准

```typescript
// 成功
interface ApiSuccess<T> {
  code: 0
  data: T
  message: 'success'
}

// 失败
interface ApiError {
  code: number        // 错误码（非 0）
  message: string     // 错误信息
  details?: any       // 详细错误
}

// 分页
interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  pageSize: number
  hasMore: boolean
}
```

---

## 7. 状态仓库设计

### 7.1 auth store

```typescript
interface AuthState {
  user: User | null
  token: string | null
  isLoggedIn: boolean
  loginMethod: 'phone' | 'wechat' | 'apple' | null
}

interface AuthActions {
  login(credentials: LoginInput): Promise<void>
  logout(): void
  refreshToken(): Promise<void>
  updateProfile(profile: Partial<User>): Promise<void>
}
```

### 7.2 marketplace store

```typescript
interface MarketplaceState {
  templates: Template[]
  currentCategory: string
  currentSort: 'popular' | 'newest' | 'rating'
  searchQuery: string
  myPurchases: string[]     // 已购模板 ID 列表
  loading: boolean
  pagination: PaginationMeta
}

interface MarketplaceActions {
  fetchTemplates(params: FetchParams): Promise<void>
  loadMore(): Promise<void>
  purchaseTemplate(templateId: string): Promise<void>
  addToFavorites(templateId: string): void
  search(query: string): Promise<void>
}
```

### 7.3 community store

```typescript
interface CommunityState {
  works: Work[]
  currentTopic: string
  activeChallenge: Challenge | null
  challengeRankings: RankingEntry[]
  loading: boolean
}

interface CommunityActions {
  fetchWorks(params: FetchParams): Promise<void>
  publishWork(work: CreateWorkInput): Promise<void>
  likeWork(workId: string): Promise<void>
  commentOnWork(workId: string, content: string): Promise<void>
  fetchChallenge(id: string): Promise<void>
  submitChallenge(challengeId: string, workId: string): Promise<void>
}
```

---

## 8. 页面 Spec（规格定义 - 关键页面）

### 8.1 首页（Home Index）— Bento 推荐流

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/home/index` |
| **核心功能** | 个性化推荐 + Bento 网格 + 热门作品 |
| **加载输入** | 判断登录态 → 请求首页数据（精选/挑战/热门/创作者） |
| **数据依赖** | `templates()` `challenges()` `works()` 三个接口并行 |
| **骨架** | 暖橙色骨架屏，Bento 卡片形状 |
| **滚动** | 下拉刷新 + 无限滚动（作品流） |
| **验收标准** | 1. Bento 网格正确布局 2. 精选卡片可点击进入模板详情 3. 挑战赛卡片展示标题/时间/参与人数 4. 热门作品瀑布流加载正常 5. 下拉刷新 6. 搜索入口可跳转 |

### 8.2 模板详情（Template Detail）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/marketplace/detail` |
| **参数** | `templateId: string` |
| **核心功能** | 模板预览、购买、评价、拍同款 |
| **关键状态** | `isPurchased`, `isInCart`, `currentRating` |
| **操作** | 购买 → 支付 → 添加到库；收藏；评价；拍同款（跳转拍摄） |
| **验收标准** | 1. 模板截图/预览正常 2. 作者信息/评分/下载量展示 3. 价格展示 4. 已购显示"已购买" 5. 未购弹出支付 6. 评价列表 7. 拍同款跳转 |

### 8.3 创作看板（Creator Dashboard）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/creator/dashboard` |
| **权限** | 创作者角色 |
| **核心功能** | 下载量/收入/粉丝统计数据 + 模板列表 |
| **验收标准** | 1. 本月/累计收入 2. 模板下载排行 3. 粉丝增长趋势 4. 最近订单 5. 提现入口 |

---

## 9. 设计 Token 系统

对应品牌文档第 4 节配色和第 5 节字体：

```scss
// studio-tokens.scss — 画集 Lumira Studio 设计 Token

// === 配色系统 ===
--color-bg-canvas: #FBF8F3;
--color-bg-card: #FFFFFF;
--color-bg-surface: #F4EFE7;

--color-text-primary: #2B1F18;
--color-text-secondary: #6B5A4E;
--color-text-tertiary: #A89888;

--color-brand-primary: #E8845C;
--color-brand-secondary: #C56535;

--color-community: #C45050;
--color-creator-gold: #C9A96E;
--color-link: #3D6E8E;
--color-success: #7A8B5C;

--color-border: #EFE8DC;

// 社区分类色
--color-category-portrait-bg: #F5E3DC;
--color-category-portrait-text: #B86555;
--color-category-landscape-bg: #E8EADC;
--color-category-landscape-text: #6E7A4A;
--color-category-food-bg: #F5EBD8;
--color-category-food-text: #A8843C;
--color-category-night-bg: #E0DCE8;
--color-category-night-text: #5C5478;
--color-category-travel-bg: #DFEAE8;
--color-category-travel-text: #4A7A78;
--color-category-family-bg: #F3DEE0;
--color-category-family-text: #B05A6A;

// 深色模式
--color-bg-canvas-dark: #1F1A16;
--color-bg-card-dark: #2A2420;
--color-text-primary-dark: #F0EBE2;
--color-brand-dark: #EE9572;

// === 间距 ===
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 24px;
--space-6: 32px;
--space-7: 48px;
--space-8: 64px;

// === 字号 ===
--font-size-display: 32px;
--font-size-title: 22px;
--font-size-heading: 17px;
--font-size-body: 14px;
--font-size-caption: 12px;
--font-size-tag: 10px;
--font-size-mono: 16px;

// === 圆角 ===
--radius-button: 6px;
--radius-card: 8px;
--radius-pill: 9999px;
```

---

## 10. 性能目标

| 指标 | 目标 | 测量方式 |
|---|---|---|
| 首页首屏 | < 1.5s | 从点击 Tab 到首屏渲染完成 |
| 模板列表 | < 1.5s | 页面进入到列表渲染 |
| 模板下载 | < 3s | 点击下载到 .pptpl 解析完毕 |
| 搜索响应 | < 800ms | 输入完毕到结果展示 |
| AI 接口 P95 | < 3s | 请求发出到响应（同步） |
| 图片上传 | < 5s (10MB) | 选择到上传完成 |
| 无限滚动 | 无感知 | 滑到底部前完成预加载 |
| 安装包 | < 60MB | — |

---

## 11. 安全与合规

- JWT Token 存储于 keychain/keystore，不存 localStorage
- 支付签名在服务端完成，前端不透传密钥
- 所有 API 请求走 HTTPS，证书 pinning
- 图片上传前客户端压缩（减少 OSS 带宽和审核压力）
- 用户敏感信息（手机号等）脱敏显示
- 内容审核前置：上传时调用内容安全 API
- 隐私协议与用户协议在首次登录时展示确认

---

## 12. 原生插件接口

### CameraService（与如画共用接口）

```typescript
interface CameraService {
  initialize(config: CameraConfig): Promise<void>
  startPreview(viewContainer: HTMLElement): Promise<void>
  stopPreview(): Promise<void>
  setOverlay(layer: OverlayLayer): Promise<void>
  capture(): Promise<string>
  switchCamera(): Promise<void>
  release(): Promise<void>
}
```

### ImageProcessingService（本地 + 云端混合）

```typescript
interface ImageProcessingService {
  // 本地（同如画）
  load(path: string): Promise<ImageHandle>
  adjustColor(handle: ImageHandle, params: ColorParams): Promise<ImageHandle>
  applyLut(handle: ImageHandle, lutPath: string): Promise<ImageHandle>
  smooth(handle: ImageHandle, strength: number): Promise<ImageHandle>
  sharpen(handle: ImageHandle, strength: number): Promise<ImageHandle>
  crop(handle: ImageHandle, rect: CropRect): Promise<ImageHandle>
  export(handle: ImageHandle, options: ExportOptions): Promise<string>
  release(handle: ImageHandle): void

  // 云端 AI
  aiEnhance(photoPath: string): Promise<string>
  aiSegment(photoPath: string): Promise<string>
  aiBeautify(photoPath: string, level: BeautyLevel): Promise<string>
}
```

---

## 13. 构建与配置

### manifest.json 关键配置

```json
{
  "name": "画集",
  "appid": "__UNI__LUMIRA_STUDIO",
  "versionName": "1.0.0",
  "versionCode": "100",
  "networkTimeout": { "request": 15000 },
  "app-plus": {
    "distribute": {
      "android": {
        "permissions": [
          "android.permission.CAMERA",
          "android.permission.INTERNET",
          "android.permission.READ_EXTERNAL_STORAGE"
        ]
      },
      "ios": {
        "infoPlist": {
          "NSCameraUsageDescription": "画集需要使用相机拍摄照片",
          "NSPhotoLibraryAddUsageDescription": "画集需要保存照片到相册",
          "NSPhotoLibraryUsageDescription": "画集需要读取相册照片"
        }
      }
    },
    "nativePlugins": {
      "LumiraCamera": { "class": "LumiraCameraModule" },
      "LumiraImageProcessor": { "class": "LumiraImageProcessorModule" }
    }
  }
}
```

> **注意**：联网版需要 INTERNET 权限用于 API 通信与 CDN 资源加载。

### pages.json 配置

```json
{
  "pages": [
    { "path": "pages/home/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/home/search", "style": { "navigationBarTitleText": "搜索" } },
    { "path": "pages/marketplace/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/marketplace/detail", "style": { "navigationBarTitleText": "模板详情" } },
    { "path": "pages/marketplace/editor", "style": { "navigationBarTitleText": "模板编辑器" } },
    { "path": "pages/capture/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/preview", "style": { "navigationBarTitleText": "预览" } },
    { "path": "pages/capture/aienhance", "style": { "navigationBarTitleText": "AI 增强" } },
    { "path": "pages/community/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/community/detail", "style": { "navigationBarTitleText": "作品详情" } },
    { "path": "pages/community/challenge", "style": { "navigationBarTitleText": "挑战赛" } },
    { "path": "pages/community/challenge-submit", "style": { "navigationBarTitleText": "提交作品" } },
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/settings", "style": { "navigationBarTitleText": "设置" } },
    { "path": "pages/profile/works", "style": { "navigationBarTitleText": "我的作品" } },
    { "path": "pages/profile/library", "style": { "navigationBarTitleText": "我的模板库" } },
    { "path": "pages/profile/favorites", "style": { "navigationBarTitleText": "我的收藏" } },
    { "path": "pages/profile/wallet", "style": { "navigationBarTitleText": "我的钱包" } },
    { "path": "pages/creator/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/creator/analytics", "style": { "navigationBarTitleText": "数据看板" } },
    { "path": "pages/creator/works-manage", "style": { "navigationBarTitleText": "作品管理" } },
    { "path": "pages/creator/earnings", "style": { "navigationBarTitleText": "收益管理" } },
    { "path": "pages/auth/login", "style": { "navigationBarTitleText": "登录" } },
    { "path": "pages/auth/register", "style": { "navigationBarTitleText": "注册" } },
    { "path": "pages/webview/index", "style": { "navigationBarTitleText": "" } }
  ],
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "画集",
    "backgroundColor": "#FEF9F4"
  },
  "tabBar": {
    "color": "#B8A69A",
    "selectedColor": "#E87A4A",
    "backgroundColor": "#FEF9F4",
    "list": [
      { "pagePath": "pages/home/index", "text": "首页", "iconPath": "static/tab/home.png", "selectedIconPath": "static/tab/home-active.png" },
      { "pagePath": "pages/marketplace/index", "text": "市场", "iconPath": "static/tab/market.png", "selectedIconPath": "static/tab/market-active.png" },
      { "pagePath": "pages/capture/index", "text": "拍摄", "iconPath": "static/tab/capture.png", "selectedIconPath": "static/tab/capture-active.png" },
      { "pagePath": "pages/community/index", "text": "社区", "iconPath": "static/tab/community.png", "selectedIconPath": "static/tab/community-active.png" },
      { "pagePath": "pages/profile/index", "text": "我的", "iconPath": "static/tab/profile.png", "selectedIconPath": "static/tab/profile-active.png" }
    ]
  }
}
```

---

## 14. 组件通信约定

| 通信方式 | 用途 | 约束 |
|---|---|---|
| Props（父→子） | 配置传递、数据流入 | 必须 TS 接口，不可 mutate |
| Emits（子→父） | 事件上报 | 命名 `on-*` 驼峰，payload 有类型 |
| Slots | 布局扩展 | 具名 slot，提供 fallback |
| Provide/Inject | 深层依赖传递 | 仅在跨 3+ 层时使用 |
| Pinia | 全局/跨页面状态 | 不得在组件内直接修改（通过 Action） |
| Composable return values | 逻辑复用 | 返回 `{ ref, fn }` 模式 |

**禁止**：
- 组件间直接通过 ref 操作对方内部状态
- EventBus 全局事件（难以追踪）
- 在 Props 中传递响应式对象（除非只读）

---

## 15. 构建配置清单

| 配置项 | 值 | 说明 |
|---|---|---|
| 编译目标 | Vue3 + TypeScript | uni-app CLI 模式 |
| 包名 Android | com.lumirastudio.app | — |
| Bundle ID iOS | com.lumirastudio.app | — |
| 最低 SDK Android | API 26 (Android 8.0) | — |
| 最低 iOS 版本 | iOS 13.0 | 支持 SwiftUI 互操作 |
| 上传 CDN | ali-oss SDK | 作品照片存储 |
| 推送 | uni-push | 社区互动通知 |
| 统计分析 | uni-analytics | 埋点基础框架 |
| 热更新 | uni-upgrade-center | App 资源更新 |

> **注意**：以上 uni 插件需在 manifest.json 中额外配置，具体参数以插件文档为准。

---

## 16. 界面设计与布局

> 本章定义「画集 Lumira Studio」的视觉界面设计与页面布局。设计语言承接品牌文档「暖意 bento 社区」：暖橙赤茶米配色、无衬线亲和字体、bento 网格、明快活泼的社区氛围，同时保持克制的层次与轻盈的悬浮导航。

### 16.1 设计原则

| 原则 | 说明 |
|---|---|
| 暖意社区 | 暖橙主色营造亲和活力，卡片圆角更小(8px)显现代感 |
| Bento 组织 | 首页/看板用非对称 Bento 网格聚合多类内容 |
| 内容优先 | 作品图/模板图为主角，社区流以视觉瀑布呈现 |
| 悬浮中央键 | 拍摄置于 Tab 栏中央凸起，强化「随手创作」的核心行为 |
| 分类色语义 | 六大拍摄品类各有专属点缀色（人像/风光/美食/夜景/旅行/家庭） |

### 16.2 全局布局栅格

```
┌─────────────────────────────┐  ← 状态栏（沉浸式，safe-area-inset-top）
│  AppHeader  🔍 搜索      🔔   │  ← 标题 + 搜索框 + 通知铃铛
├─────────────────────────────┤
│                             │
│      内容主体区              │  ← 左右安全边距 --space-4 (16px)
│  （Bento / 瀑布流 / 列表）    │     卡片间距 --space-3 (12px)
│                             │
│                             │
│           ╭───╮             │  ← 中央拍摄键凸起
│      ╭────┤ ◉ ├────╮        │  ← 悬浮 Tab 栏（5 Tab）
│      │ ⌂  ▦   ♥  ○ │        │     底部 safe-area + 12px
│      ╰───────────────╯       │
└─────────────────────────────┘
```

- **内容安全边距**：左右各 `--space-4`(16px)
- **底部内容留白**：可滚动页面底部 padding 预留 `100px`，避让悬浮 Tab 与中央凸起键
- **卡片圆角**：`--radius-card`(8px)，边框 `1px solid var(--color-border)`

### 16.3 悬浮 Tab 栏详细设计（中央凸起）

```
                  ╭─────╮
                  │  ◉  │          ← 中央拍摄键（暖橙实底，凸起 20px）
        ╭─────────┴─────┴─────────╮
        │  ⌂      ▦          ♥   ○ │  ← 首页/市场 | (中央) | 社区/我的
        │  首页                     │  ← 选中态显文字
        ╰───────────────────────────╯
   ↑ safe-area + 12px          ↑ 左右内缩 16px
```

**结构与交互**：

| 元素 | 规格 |
|---|---|
| 容器 | 胶囊 `border-radius:9999px`，高 `60px`，白 82% 透明 + `blur(20px)` |
| 四侧图标 | 首页/市场/社区/我的，22px，未选 `#A89888`，选中 `#E8845C` + 文字 |
| 中央拍摄键 | 直径 `56px` 圆，暖橙实底 `#E8845C`，白色相机图标，凸起于胶囊上方 |
| 中央键阴影 | `0 4px 16px rgba(232,132,92,0.35)` |
| 中央键动效 | `:active scale(0.92)`，点击后轻微暖橙涟漪 |
| 选中动效 | 图标 `scale(1.08)` + 文字淡入，`200ms cubic-bezier(0.16,1,0.3,1)` |

**FloatingTabBar.vue 骨架**：

```vue
<script setup lang="ts">
interface FloatingTabBarProps {
  current: string          // 当前选中 tab key
}
const props = defineProps<FloatingTabBarProps>()
const emit = defineEmits<{
  (e: 'on-switch', key: string): void
  (e: 'on-capture'): void   // 中央拍摄键单独事件
}>()
</script>

<template>
  <view class="studio-tabbar">
    <!-- 左侧两个 tab -->
    <view
      v-for="tab in leftTabs"
      :key="tab.key"
      class="studio-tabbar__item"
      :class="{ 'is-active': tab.key === current }"
      @tap="emit('on-switch', tab.key)"
    >
      <image class="studio-tabbar__icon" :src="tab.key === current ? tab.iconActive : tab.icon" />
      <text v-if="tab.key === current" class="studio-tabbar__label">{{ tab.label }}</text>
    </view>

    <!-- 中央拍摄凸起键 -->
    <view class="studio-tabbar__capture" @tap="emit('on-capture')">
      <image class="studio-tabbar__capture-icon" src="/static/icons/capture-white.svg" />
    </view>

    <!-- 右侧两个 tab -->
    <view
      v-for="tab in rightTabs"
      :key="tab.key"
      class="studio-tabbar__item"
      :class="{ 'is-active': tab.key === current }"
      @tap="emit('on-switch', tab.key)"
    >
      <image class="studio-tabbar__icon" :src="tab.key === current ? tab.iconActive : tab.icon" />
      <text v-if="tab.key === current" class="studio-tabbar__label">{{ tab.label }}</text>
    </view>
  </view>
</template>
```

```scss
.studio-tabbar {
  position: fixed;
  left: var(--space-4);
  right: var(--space-4);
  bottom: calc(env(safe-area-inset-bottom) + 12px);
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: space-around;
  border-radius: 9999px;
  border: 1px solid var(--color-border);
  background: rgba(255, 255, 255, 0.82);
  backdrop-filter: blur(20px);
  box-shadow: 0 6px 28px rgba(200, 101, 53, 0.10);
  z-index: 900;

  &__item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    transition: transform 200ms cubic-bezier(0.16, 1, 0.3, 1);
    &.is-active { transform: scale(1.08); }
  }
  &__icon { width: 22px; height: 22px; }
  &__label { font-size: var(--font-size-tag); color: var(--color-brand-primary); }

  &__capture {
    position: relative;
    width: 56px;
    height: 56px;
    margin-top: -20px;               // 凸起
    border-radius: 9999px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-brand-primary);
    box-shadow: 0 4px 16px rgba(232, 132, 92, 0.35);
    z-index: 901;
    transition: transform 150ms ease;
    &:active { transform: scale(0.92); }
  }
  &__capture-icon { width: 26px; height: 26px; }
}
```

### 16.4 关键页面布局（线框图）

#### 首页（Home Index）— Bento 网格

```
┌─────────────────────────────┐
│ 画集         🔍 搜索灵感   🔔 │  ← 标题 + 搜索 + 通知
│                             │
│ ┌───────────────┬─────────┐ │
│ │               │ 本周挑战 │ │  ← Bento：大卡（本周精选）
│ │   本周精选     │  #城市光影│ │    + 挑战小卡
│ │   （大图）     ├─────────┤ │
│ │               │ 热门榜单 │ │
│ └───────────────┴─────────┘ │
│                             │
│  新晋创作者                  │
│  ○ ○ ○ ○ ○  →              │  ← 头像横滑
│                             │
│  为你推荐                    │
│ ┌─────────┐ ┌─────────┐     │  ← 推荐模板/作品双列
│ │  作品图  │ │  作品图  │     │
│ └─────────┘ └─────────┘     │
│           ╭───╮             │
│      ╭────┤ ◉ ├────╮        │  ← 悬浮 Tab（中央拍摄凸起）
│      │ ⌂  ▦   ♥  ○ │        │
│      ╰───────────────╯       │
└─────────────────────────────┘
```

- 顶部为非对称 Bento（1 大 + 2 小），圆角 8px
- 「新晋创作者」横向滚动头像列
- 「为你推荐」双列内容，无限下拉

#### 模板市场（Marketplace Index）

```
┌─────────────────────────────┐
│ 市场            🔍           │
│ ［推荐］热门 新品 免费 榜单    │  ← 排序/筛选横滑 tab
│                             │
│ 人像 风光 美食 夜景 旅行 家庭  │  ← 分类色标签（各专属点缀色）
│                             │
│ ┌───────────┐ ┌───────────┐ │
│ │   模板图   │ │   模板图   │ │  ← 双列模板卡片
│ │           │ │           │ │
│ │ 晨雾人像   │ │ 赛博夜景   │ │
│ │ ○作者 ¥6  │ │ ○作者 免费 │ │  ← 作者头像 + 价格
│ │ ♥1.2k ⭐4.8│ │ ♥890 ⭐4.6 │ │  ← 点赞 + 评分
│ └───────────┘ └───────────┘ │
│           ╭───╮             │
│      ╭────┤ ◉ ├────╮        │
│      ╰───────────────╯       │
└─────────────────────────────┘
```

- 分类标签使用六大品类专属色（对应 tokens 中 `--color-category-*`）
- 模板卡片含作者、价格、点赞、评分四要素

#### 作品社区（Community Index）— 瀑布流

```
┌─────────────────────────────┐
│ 社区            + 发布        │  ← 发布作品入口
│ ［关注］推荐 挑战赛 附近       │
│                             │
│ ┌──────────┐ ┌──────────┐   │  ← 双列瀑布流（不等高）
│ │          │ │          │   │
│ │  作品图   │ │  作品图   │   │
│ │          │ ├──────────┤   │
│ ├──────────┤ │ ○ 用户名  │   │
│ │ ○ 用户名  │ │ ♥328 💬45 │   │
│ │ 拍同款↗   │ │ 拍同款↗   │   │
│ └──────────┘ └──────────┘   │
│           ╭───╮             │
│      ╭────┤ ◉ ├────╮        │
│      ╰───────────────╯       │
└─────────────────────────────┘
```

- Masonry 瀑布流（不等高图片），间距 `--space-3`(12px)
- 每卡含作者、点赞、评论、「拍同款」快捷入口

#### 创作者看板（Creator Dashboard）— Bento 数据

```
┌─────────────────────────────┐
│ ← 创作者中心                  │
│                             │
│ ┌─────────┬─────────────┐   │
│ │ 本月收益 │  ¥ 2,480.50  │   │  ← Bento 数据卡
│ ├─────────┼──────┬──────┤   │
│ │ 粉丝     │ 模板 │ 销量  │   │
│ │ 3,204   │  18  │ 512  │   │
│ └─────────┴──────┴──────┘   │
│                             │
│  📈 近 30 天销量趋势          │  ← 折线图卡片
│  ▁▂▃▅▆▇▆▅▃▂                │
│                             │
│  我的模板              管理→  │
│  ▸ 晨雾人像   销量 128       │
│  ▸ 赛博夜景   销量 96        │
└─────────────────────────────┘
```

- 创作者看板为深度页面，**不显示悬浮 Tab 栏**
- 数据以 Bento 卡聚合：收益/粉丝/模板/销量

### 16.5 组件视觉规范速查

| 组件 | 关键样式 |
|---|---|
| 页面标题 | 无衬线粗体（如 HarmonyOS Sans / Source Han Sans），`--font-size-display`(32px) |
| 主 CTA 按钮 | 暖橙实底 `#E8845C` + 白字，`--radius-button`(6px)，`:active scale(0.98)` |
| 次级按钮 | 白底 + 1px 边框 + 暖橙字 |
| 卡片 | 白底、`1px solid var(--color-border)`、`--radius-card`(8px) |
| 分类标签 | pill，`--font-size-tag`(10px)，六大品类各用专属 `--color-category-*` |
| 社区互动 | 点赞♥ 选中态 `--color-community`(#C45050)，数值 caption |
| 价格标 | 免费=success 绿标；付费=暖橙数字 + ¥ mono |
| 头像 | 圆形，边框 `1px rgba(0,0,0,0.06)` |

### 16.6 动效规范

- **页面进入**：内容块 `translateY(12px) + opacity:0 → 1`，`600ms cubic-bezier(0.16,1,0.3,1)`
- **瀑布流交错**：卡片 `animation-delay: calc(var(--index) * 80ms)`
- **中央拍摄键**：常驻，点击 `scale(0.92)` + 暖橙涟漪
- **点赞动效**：♥ 图标 `scale(1→1.3→1)` 弹性回弹 + 变色
- **仅动画 `transform` 与 `opacity`**，不触发布局重排