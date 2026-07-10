# 如画 Lumira 前端设计文档

> 文档版本：v1.0
> 创建日期：2026-07-03
> 文档类型：前端工程规格（Frontend Engineering Spec）
> 产品版本：如画 Lumira · 单机版
> 框架：uni-app (Vue3 + TypeScript)
> 设计范式：Harness Engineering（骨架优先，接口驱动，规格验证）

---

## 0. 文档说明

本文档定义「如画 Lumira」前端工程的完整设计。遵循 Harness Engineering 范式：
1. **骨架优先**：先定义组件树、路由、数据流等结构，再填充实现
2. **接口驱动**：组件/模块通过类型化的 Props/Events/Slots 通信
3. **规格验证**：每个页面有明确定义的 Spec 与验收标准

配套文档：
- PRD：`../superpowers/specs/2026-07-03-lumira-prd.md`
- 品牌设计：`../superpowers/specs/2026-07-03-lumira-brand.md`
- AGENT.md：`../../AGENT.md`

---

## 1. 技术选型

| 层 | 选择 | 理由 |
|---|---|---|
| 框架 | uni-app (Vue3.4 + Composition API) | 跨平台输出 iOS / Android |
| 语言 | TypeScript strict mode | 类型安全是 Harness 的基础 |
| 状态管理 | Pinia | 轻量、Vue3 原生、TS 友好 |
| 路由 | uni-app pages.json / uni-simple-router | 原生 Tab + 页面栈 |
| 样式方案 | CSS Variables（设计 Token）+ SCSS | 品牌色/间距/字体统一管理 |
| 图像处理 | 原生 C++ 插件（LUT/滤波/锐化） | 性能关键路径走原生 |
| 相机 | uni-app camera + nvue/原生插件 | 取景器叠图需高性能渲染 |
| 本地存储 | SQLite（@dcloudio/uni-sqlite） | 模板/照片索引持久化 |
| 代码规范 | ESLint + Prettier + Husky | 工程纪律 |

---

## 2. 工程目录结构

```
lumira/                        # 如画 单机版工程根目录
├── src/
│   ├── App.vue                # 应用根组件
│   ├── main.ts                # 入口文件
│   ├── manifest.json           # uni-app 配置（零网络权限）
│   ├── pages.json              # 页面路由配置
│   ├── uni.scss                # 全局 SCSS 变量
│   │
│   ├── pages/                  # 页面目录（按功能划分）
│   │   ├── home/                # 首页模块（Tab 1）
│   │   │   └── index.vue       #   首页（推荐/挑战/数据）
│   │   ├── templates/           # 模板模块（Tab 2）
│   │   │   ├── index.vue       #   模板库页
│   │   │   ├── detail.vue      #   模板详情页
│   │   │   ├── editor.vue      #   模板编辑器
│   │   │   ├── import.vue      #   模板导入页
│   │   │   └── unlock.vue      #   解锁面板（弹出式）
│   │   ├── capture/             # 拍摄模块（中心按钮跳转）
│   │   │   ├── index.vue       #   拍摄页（取景器 + 叠图）
│   │   │   ├── preview.vue     #   拍摄预览页
│   │   │   └── parameters.vue  #   参数面板（半屏弹窗）
│   │   ├── inspiration/         # 灵感模块（Tab 3）
│   │   │   └── index.vue       #   灵感页（穿搭/心情/探店/场景）
│   │   ├── gallery/             # 相册模块
│   │   │   ├── index.vue       #   相册页
│   │   │   ├── detail.vue      #   照片详情/后期编辑
│   │   │   └── diary.vue       #   拍摄日记/穿搭日记
│   │   └── profile/             # 个人/设置模块（Tab 4）
│   │       ├── index.vue       #   我的页
│   │       ├── growth.vue      #   成长中心
│   │       ├── invite.vue      #   邀请有礼
│   │       ├── academy.vue     #   摄影美学院
│   │       ├── academy-detail.vue # 教程详情
│   │       └── settings.vue    #   设置页
│   │
│   ├── components/             # 可复用组件
│   │   ├── camera/             #   相机相关
│   │   │   ├── CameraViewfinder.vue    # 取景器组件
│   │   │   ├── OverlayLayer.vue        # 叠图层（构图线+姿势）
│   │   │   ├── ShutterButton.vue       # 快门按钮
│   │   │   └── ParameterBar.vue        # 参数条
│   │   ├── image/              #   图像处理
│   │   │   ├── ImageEditor.vue         # 后期编辑器
│   │   │   ├── LutSelector.vue         # LUT 滤镜选择
│   │   │   └── CropFrame.vue           # 裁剪框
│   │   ├── template/           #   模板相关
│   │   │   ├── TemplateCard.vue        # 模板卡片
│   │   │   ├── TemplateTag.vue         # 模板标签
│   │   │   └── OverlayPreview.vue      # 叠图预览缩略
│   │   └── ui/                 #   通用 UI
│   │       ├── AppButton.vue           # 按钮
│   │       ├── AppHeader.vue           # 页面头部
│   │       ├── AppTabBar.vue           # 底部 Tab
│   │       ├── AppInput.vue            # 输入框
│   │       ├── AppAvatar.vue           # 头像
│   │       ├── AppBadge.vue            # 徽章
│   │       ├── AppSkeleton.vue         # 骨架屏
│   │       ├── AppEmpty.vue            # 空状态
│   │       └── AppToast.vue            # 轻提示
│   │
│   ├── composables/            # 可组合逻辑（Vue3 Composables）
│   │   ├── useCamera.ts        #   相机控制
│   │   ├── useOverlay.ts       #   叠图渲染
│   │   ├── useImageProcessing.ts # 图像处理
│   │   ├── useTemplateEngine.ts  # 模板引擎
│   │   ├── useTemplateParser.ts   # PPTPL 解析器
│   │   ├── useFileShare.ts    #   文件分享/导入
│   │   ├── useGallery.ts      #   相册管理
│   │   └── useDevice.ts       #   设备信息/传感器
│   │
│   ├── stores/                 # Pinia 状态仓库
│   │   ├── capture.ts          #   拍摄状态
│   │   ├── gallery.ts          #   相册状态
│   │   ├── templates.ts        #   模板库状态
│   │   ├── profile.ts          #   个人等级/经验/统计
│   │   ├── challenge.ts        #   每日挑战进度
│   │   ├── diary.ts            #   拍摄日记/穿搭日记
│   │   ├── achievement.ts      #   成就/勋章
│   │   ├── invitation.ts       #   邀请裂变计数
│   │   └── settings.ts         #   设置状态
│   │
│   ├── services/               # 服务层
│   │   ├── camera.ts          #   相机原生服务（依赖注入接口）
│   │   ├── imageProcessor.ts  #   图像处理引擎接口
│   │   ├── templateEngine.ts  #   模板引擎（解析/应用/序列化）
│   │   └── storage.ts         #   本地存储（SQLite + 文件系统）
│   │
│   ├── types/                  # TypeScript 类型定义
│   │   ├── template.ts        #   .pptpl 类型定义
│   │   ├── photo.ts           #   照片元数据类型
│   │   ├── camera.ts          #   相机参数类型
│   │   ├── overlay.ts         #   叠图层类型
│   │   └── native.ts          #   原生插件接口类型
│   │
│   ├── tokens/                 # 设计 Token（CSS Variables 源）
│   │   └── lumira-tokens.ts   #   色板/间距/字号 Token
│   │
│   ├── utils/                  # 工具函数
│   │   ├── exif.ts            #   EXIF 读写
│   │   ├── color.ts           #   色彩空间转换
│   │   └── math.ts            #   矩阵/几何计算
│   │
│   └── assets/                 # 静态资源
│       ├── images/            #   图片
│       ├── icons/             #   图标（Phosphor Bold）
│       └── luts/              #   LUT 文件（.cube）
│
├── native/                    # 原生插件源码
│   ├── ios/                   #   iOS 原生插件
│   └── android/               #   Android 原生插件
│
├── static/                    # 模板/启动图等
│   └── builtin-templates/     #   内置精选模板 (.pptpl)
│
├── package.json
├── tsconfig.json
├── vite.config.ts             # uni-app 基于 Vite
└── .eslintrc.cjs
```

---

## 3. 页面路由与导航

### 3.1 路由结构

| 路径 | 页面 | Tab | 说明 |
|---|---|---|---|
| `/pages/home/index` | 首页 | 是 | 留存枢纽：推荐/挑战/数据/限时免费 |
| `/pages/templates/index` | 模板库 | 是 | 模板浏览/解锁/兑换码 |
| `/pages/capture/index` | 拍摄页 | 否（中心按钮） | 取景器 + 快门，无 Tab 栏沉浸页 |
| `/pages/capture/preview` | 拍摄预览 | 否 | 拍摄后立即预览 |
| `/pages/capture/parameters` | 参数面板 | 否 | 半屏弹窗式 |
| `/pages/inspiration/index` | 灵感 | 是 | 女性向功能：穿搭/心情/探店/场景 |
| `/pages/profile/index` | 我的 | 是 | 个人/等级/成就/设置 |
| `/pages/templates/detail` | 模板详情 | 否 | 单模板详解 |
| `/pages/templates/editor` | 模板编辑器 | 否 | 创建/编辑模板 |
| `/pages/templates/import` | 模板导入 | 否 | 从文件导入 |
| `/pages/templates/unlock` | 模板解锁面板 | 否 | 弹出式多路径解锁 |
| `/pages/gallery/index` | 相册 | 否 | 从首页/拍摄页入口 |
| `/pages/gallery/detail` | 照片详情/后期 | 否 | 查看/编辑单张 |
| `/pages/gallery/diary` | 拍摄日记/穿搭日记 | 否 | 时间轴视图 |
| `/pages/profile/growth` | 成长中心 | 否 | 成就/等级/统计 |
| `/pages/profile/invite` | 邀请有礼 | 否 | 裂变分享入口 |
| `/pages/profile/academy` | 摄影美学院 | 否 | 教程列表 |
| `/pages/profile/academy-detail` | 教程详情 | 否 | 单篇教程阅读 |
| `/pages/profile/settings` | 设置 | 否 | 应用设置 |

### 3.2 导航图

```
[Tab 1: 首页] ──── (/pages/home/index)
   ├── 模板解锁面板 ──→ (/pages/templates/unlock)
   ├── 拍摄入口 ──→ (/pages/capture/index)
   ├── 每日挑战拍摄 ──→ (/pages/capture/index)
   ├── 合拍挑战 ──→ (/pages/capture/index)
   ├── 限时免费 ──→ (/pages/templates/unlock)
   ├── 相册 ──→ (/pages/gallery/index)
   └── 照片详情 ──→ (/pages/gallery/detail)

[Tab 2: 模板] ──── (/pages/templates/index)
   ├── 模板详情 ──→ (/pages/templates/detail)
   ├── 模板创建 ──→ (/pages/templates/editor)
   ├── 模板导入 ──→ (/pages/templates/import)
   └── 模板解锁 ──→ (/pages/templates/unlock)

[中心按钮: 拍摄] ──── (/pages/capture/index)
   ├── 拍摄预览 ──→ (/pages/capture/preview)
   │     └── 后期编辑 ──→ (/pages/gallery/detail)
   └── 参数面板 ──→ (/pages/capture/parameters)

[Tab 3: 灵感] ──── (/pages/inspiration/index)
   ├── 穿搭日记 ──→ (/pages/gallery/diary)
   ├── 心情标签筛选 ──→ (/pages/gallery/index?filter=mood)
   ├── 探店打卡 ──→ (/pages/capture/index?mode=checkin)
   ├── 合拍指南 ──→ (/pages/capture/index?mode=group)
   └── 场景向导 ──→ (/pages/capture/index?scene=xxx)

[Tab 4: 我的] ──── (/pages/profile/index)
   ├── 成长中心 ──→ (/pages/profile/growth)
   ├── 邀请有礼 ──→ (/pages/profile/invite)
   ├── 摄影美学院 ──→ (/pages/profile/academy)
   ├── 设置 ──→ (/pages/profile/settings)
   └── 穿搭日记 ──→ (/pages/gallery/diary)
```

### 3.3 TabBar 配置（4 Tab + 中心拍摄按钮）

首页采用 **4 Tab + 中心凸起拍摄按钮** 的悬浮胶囊导航：

```
        ╭─────────────────────────────────╮
        │   🏠      📚      📷      ✨      👤   │
        │  首页    模板    拍摄    灵感    我的  │
        │        (中心凸起按钮)             │
        ╰─────────────────────────────────╯
```

**pages.json 中启用自定义 Tab：**

```json
{
  "tabBar": {
    "custom": true,
    "list": [
      { "pagePath": "pages/home/index", "text": "首页" },
      { "pagePath": "pages/templates/index", "text": "模板" },
      { "pagePath": "pages/inspiration/index", "text": "灵感" },
      { "pagePath": "pages/profile/index", "text": "我的" }
    ]
  }
}
```

> `custom: true` 隐藏原生 Tab 栏，由全局组件 `FloatingTabBar.vue` 接管渲染。拍摄页不在 Tab 列表中，通过中心按钮跳转。

**悬浮 Tab 栏视觉规格**：

| 属性 | 规格 |
|---|---|
| 定位 | `position: fixed`，脱离底部边缘 |
| 底部距离 | `calc(env(safe-area-inset-bottom) + 16px)` |
| 水平内缩 | 左右各 `24px`（`--space-5`） |
| 容器形态 | 圆角胶囊，`border-radius: 9999px` |
| 高度 | `56px` |
| 背景 | `rgba(255,255,255,0.72)` + `backdrop-filter: blur(20px)` |
| 边框 | `1px solid var(--color-border)` |
| 阴影 | `0 4px 24px rgba(0,0,0,0.06)` |
| 图标尺寸 | `24px`，选中态品牌金 `--color-brand-primary` |
| 文字 | `--font-size-tag`（11px），选中态显示 |
| 层级 | `z-index: 900` |

**中心拍摄按钮规格**：

| 属性 | 规格 |
|---|---|
| 位置 | 悬浮胶囊中心，凸起高于 Tab 栏 `8px` |
| 尺寸 | `56px × 56px` 圆形 |
| 背景 | 品牌金 `--color-brand-primary`（`#C9A96E`） |
| 图标 | 相机图标，白色，`28px` |
| 阴影 | `0 4px 16px rgba(201,169,110,0.35)`（金色辉光） |
| 点击反馈 | `scale(0.92)` on `:active`，回弹 spring 动效 |
| 跳转到 | `/pages/capture/index`（无 Tab 栏沉浸页） |

**Tab 与按钮布局**：

```
┌──────────────────────────────────────────────┐
│                                              │
│   🏠      📚       📷       ✨      👤      │
│  首页    模板    (凸起)    灵感    我的     │
│                    相机                     │
│                                              │
└──────────────────────────────────────────────┘
         ↑         ↑         ↑        ↑
      常规Tab   常规Tab   中心凸起   常规Tab
                        (比其他Tab大1.5倍)
```

**首页 Tab 定位**：

| Tab | 定位 | 核心职责 | 日活驱动力 |
|---|---|---|---|
| 首页 | Tab 1 | 留存枢纽：推荐/挑战/数据/限时免费 | 挑战刷新、限时免费、连续打卡 |
| 模板 | Tab 2 | 内容消费：模板浏览/解锁/兑换码 | 每周限免、碎片收集 |
| 拍摄 | 中心按钮 | 核心动作：取景器+快门 | 唯一 CTA，无 Tab 沉浸 |
| 灵感 | Tab 3 | 女性向复合：穿搭/心情/探店/场景 | 穿搭连续打卡、场景收集 |
| 我的 | Tab 4 | 身份认同：等级/成就/邀请/设置 | 升级里程碑、成就解锁 |

---

## 4. 组件树（Harness 骨架）

```
App.vue
├── FloatingTabBar.vue              # 悬浮胶囊导航（4 Tab + 中心拍摄按钮，全局固定）
│
├── [Tab: 首页] HomeIndex.vue
│   ├── AppHeader                   # 日期 + 天气 + 通知入口
│   ├── RecommendSwiper             # 模板推荐横滑轮播（3-5张）
│   ├── TodayDataStrip              # 一行基础数据
│   ├── DailyChallengeCard          # 今日挑战卡片
│   ├── GroupChallengeCard          # 合拍挑战卡片
│   ├── LimitedFreeReminder         # 限时免费提醒
│   └── StreakReminder              # 连续打卡提醒
│
├── [Tab: 模板] TemplateIndex.vue
│   ├── AppHeader
│   ├── CategoryTabs                # 分类标签
│   └── TemplateCard[]              # 模板卡片列表
│
├── [拍摄页] CaptureIndex.vue       # 不在 Tab 中，通过中心按钮跳转
│   ├── CameraViewfinder.vue        # 取景器（全屏主体）
│   │   ├── OverlayLayer.vue        #   构图线叠图
│   │   │   ├── RuleOfThirdsGrid.vue
│   │   │   ├── GuideLines.vue
│   │   │   └── PoseOverlay.vue     #   姿势参考叠图
│   │   └── ParameterBar.vue        #   参数叠加指示
│   ├── TemplateTag.vue             # 当前模板名称
│   └── ShutterButton.vue           # 快门按钮
│
├── [Tab: 灵感] InspirationIndex.vue
│   ├── AppHeader
│   ├── DiaryEntryCard              # 穿搭日记入口（连续天数/最近记录）
│   ├── MoodTagCloud                # 心情标签云
│   ├── CheckinEntryCard            # 探店打卡入口
│   ├── GroupGuideEntryCard         # 合拍指南入口
│   └── SceneGuideGrid              # 场景向导网格
│
├── [Tab: 我的] ProfileIndex.vue
│   ├── AppHeader
│   ├── ProfileHeader               # 头像/昵称/等级/经验
│   ├── QuickActions                # 成长中心/成就/邀请 快捷入口
│   ├── FragmentProgress            # 碎片收集进度
│   └── MenuList                    # 摄影美学院/关于/设置
│
├── TemplateDetail.vue              # 非 Tab 页
│
├── TemplateUnlock.vue              # 弹出式多路径解锁面板
│
├── TemplateEditor.vue              # 非 Tab 页
│
├── ImageEditor.vue                 # 非 Tab 页（后期）
│
├── GalleryDiary.vue                # 拍摄日记/穿搭日记
│
├── GrowthCenter.vue                # 成长中心
│
├── InvitePage.vue                  # 邀请有礼
│
└── SettingsPage.vue                # 非 Tab 页
```

---

## 5. 数据流架构

### 5.1 整体数据流动

```
[用户操作] → [Vue 组件] → [Composable] → [Service] → [原生插件/存储]
                  ↑                           │
                  └───── Pinia Store ←────────┘
```

### 5.2 单向数据流规则

1. **组件不可直接调用 Service**：必须通过 Composable 或 Store 中转
2. **Store 不可直接操作原生插件**：必须通过 Service 层
3. **Service 返回 Promise**：所有原生调用异步化，Composable 处理加载/错误状态
4. **类型安全边界**：所有跨层数据传递使用 TypeScript 接口定义

### 5.3 核心数据流

**拍摄流程**：
```
ShutterButton.click
  → useCamera.capture(templateId?)
    → cameraService.capture()           // 原生调用
    → imageProcessor.applyPostProcess() // 应用模板后期
    → gallery.addPhoto()                // 存入相册
    → 返回 photoId
  → router.push('/preview', { photoId }) 
```

**模板应用流程**：
```
TemplateCard.select(templateId)
  → useTemplateEngine.load(templateId)
    → templateEngine.parse(pptplJson)   // 解析 .pptpl
    → camera.setOverlay(composition)    // 设置叠图
    → camera.setParameters(camera)      // 设置参数
    → parameterBar.show(sceneGuide)     // 显示指南
  → 状态更新至 capture store
```

**后期编辑流程**：
```
AdjustmentPanel.change(param, value)
  → useImageProcessing.adjust(param, value)
    → imageProcessor.adjust(param, value) // 原生处理
    → 返回处理后的临时图像
  → 预览更新（Canvas 实时渲染）
  → 用户确认 → gallery.updatePhoto()
```

### 5.4 状态仓库设计 (Pinia)

**capture store**：
```typescript
interface CaptureState {
  isActive: boolean              // 相机是否激活
  activeTemplateId: string | null
  overlaySettings: {             // 当前叠图设置
    showComposition: boolean
    showPose: boolean
    opacity: number
  }
  cameraParameters: CameraParams // 当前相机参数
  sceneGuide: SceneGuide | null  // 当前场景指南
  alignmentStatus: {             // 对齐检测结果
    isLevel: boolean
    subjectAligned: boolean
    message: string
  }
}
```

**gallery store**：
```typescript
interface GalleryState {
  photos: LocalPhoto[]
  currentPhotoId: string | null
  editingHistory: EditAction[]   // 编辑历史（支持撤销）
}
```

**templates store**：
```typescript
interface TemplatesState {
  builtinTemplates: LocalTemplate[]
  importedTemplates: LocalTemplate[]
  currentCategory: string
  searchQuery: string
}
```

---

## 6. 页面 Spec（规格定义）

### 6.1 首页（Home Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/home/index` |
| **Tab** | 是，首页 |
| **核心功能** | 留存枢纽：情绪入口 + 推荐 + 数据 + 限时免费 |
| **加载输入** | 每日挑战池（按日期哈希）、用户统计数据、限时免费配置 |
| **关键状态** | 今日挑战状态、限时免费倒计时、连续打卡天数 |
| **用户操作** | 预览推荐模板 → 套用一个；查看挑战可拍；点击进入模板库 |
| **反馈度量** | 首屏加载 < 800ms，Swiper 轮播顺滑 |
| **边界情况** | 无拍摄记录 → 展示系统引导照片；无网络 → 所有功能纯本地 |
| **数据依赖** | challenge store, template store, profile store |
| **验收标准** | 1. 日期 + 天气 + 每日一句正确显示 2. Swiper 模板推荐正常 3. 基础数据一行正确展示 4. 今日挑战状态正确 5. 合拍挑战入口可点 6. 限时免费倒计时刷新 7. 连续打卡进度刷新 |

**首页从上到下模块**：

```
┌─────────────────────────────────────────┐
│  1. 日期 + 天气 + 一句温柔               │  ← 情绪入口（无功能操作）
├─────────────────────────────────────────┤
│  2. Swiper 模板推荐（3-5 张卡横滑）       │  ← 种草推荐（第一视觉落点）
│     点击卡片 → 解锁面板 / 拍摄页         │
├─────────────────────────────────────────┤
│  3. 基础数据（一行）                      │  ← 本周：XX 张 · XX 个模板 · Lv.X
├─────────────────────────────────────────┤
│  4. 今日挑战                             │  ← 主挑战 + 支线 A/B
├─────────────────────────────────────────┤
│  5. 合拍挑战                             │  ← 双人/多人拍摄入口
├─────────────────────────────────────────┤
│  6. 限时免费提醒                         │  ← 一行，点击跳转解锁
├─────────────────────────────────────────┤
│  7. 连续打卡提醒                         │  ← 一行，点击跳转拍摄
└─────────────────────────────────────────┘
```

**首页 vs 灵感边界**：

| 维度 | 首页 | 灵感 |
|---|---|---|
| 情绪价值 | ✅ 日期+天气+每日一句 | ❌ 无 |
| 推荐 | ✅ Swiper 模板推荐 + 限时免费 | ❌ 无 |
| 数据 | ✅ 基础数据一行 | ❌ 无 |
| 挑战 | ✅ 每日挑战 + 合拍挑战 | ❌ 无 |
| 打卡 | ✅ 一行进度 | ❌ 无 |
| 穿搭日记 | ❌ | ✅ |
| 心情标签 | ❌ | ✅ |
| 探店打卡 | ❌ | ✅ |
| 场景向导 | ❌ | ✅ |

---

### 6.2 拍摄页（Capture Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/capture/index` |
| **Tab** | 否（中心按钮跳转，无 Tab 栏沉浸页） |
| **核心功能** | 取景器 + 叠图 + 拍摄 |
| **加载输入** | 相机权限 → 激活相机 → 加载默认/上次模板 |
| **关键状态** | `capture.isActive`, `capture.activeTemplateId` |
| **用户操作** | 选模板 → 按快门 → 预览/重拍 |
| **反馈度量** | 相机启动 < 1s，叠图渲染 < 50ms/帧 |
| **边界情况** | 无相机权限 → 显示权限引导页；无默认模板 → 自由拍摄模式 |
| **数据依赖** | camera service, template store |
| **验收标准** | 1. 取景器实时显示画面 2. 叠图准确叠加 3. 快门响应 < 100ms 4. 参数面板可调 5. 无网络权限提示 |

---

### 6.3 模板库页（Template Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/templates/index` |
| **Tab** | 是 |
| **核心功能** | 浏览/搜索/分类模板，解锁面板入口 |
| **加载输入** | 读取 SQLite 中所有模板（内置+导入） |
| **关键状态** | `templates.*`, 解锁状态 |
| **用户操作** | 分类筛选 → 点击模板 → 进入详情/弹出解锁面板/直接套用 |
| **反馈度量** | 列表加载 < 500ms |
| **边界情况** | 无模板 → 展示空状态+引导创建/导入 |
| **数据依赖** | template store, storage service |
| **验收标准** | 1. 内置模板正确显示 2. 分类筛选正常 3. 模板卡片展示完整 4. 点击可套用 5. 解锁面板可触发 6. 兑换码入口可用 |

---

### 6.4 灵感页（Inspiration Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/inspiration/index` |
| **Tab** | 是，第三 Tab |
| **核心功能** | 纯女性向功能合集：穿搭日记 + 心情标签 + 探店打卡 + 场景向导 |
| **加载输入** | 用户穿搭记录、心情标签统计、探店地点统计 |
| **关键状态** | 穿搭连续天数、标签使用频率、已打卡地点数 |
| **用户操作** | 进入穿搭时间线 / 按心情筛选照片 / 打卡新地点 / 选择场景 |
| **反馈度量** | 首屏加载 < 800ms |
| **边界情况** | 无穿搭记录 → 展示穿搭灵感引导；无标签记录 → 引导首次标记 |
| **数据依赖** | gallery store, diary store, mood/place statistics |
| **验收标准** | 1. 穿搭日记入口展示连续天数 2. 心情标签云可点击筛选 3. 探店打卡入口展示已打卡数 4. 场景向导可点击进入拍摄 5. 无首页情绪装饰（纯功能导向） |

**灵感页从上到下模块**：

```
┌─────────────────────────────────────────┐
│  1. 穿搭日记卡片                         │  ← 连续天数 + 最近两条记录
│     点击 → 穿搭时间线                    │
├─────────────────────────────────────────┤
│  2. 心情标签云                           │  ← 7 种标签 + 各自标记次数
│     点击 → 按心情筛选照片                │
├─────────────────────────────────────────┤
│  3. 探店打卡卡片                         │  ← 已打卡总数 + 最近 3 个地点
│     点击 → 地点列表/地图                 │
├─────────────────────────────────────────┤
│  4. 场景向导网格                         │  ← 6-8 个预设场景
│     点击 → 对应场景模板推荐 + 拍摄       │
└─────────────────────────────────────────┘
```

---

### 6.5 我的页（Profile Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/profile/index` |
| **Tab** | 是 |
| **核心功能** | 个人身份 + 等级/成就/邀请/设置 |
| **加载输入** | 用户等级、经验值、成就列表、碎片统计 |
| **关键状态** | `profile.level`, `profile.xp`, `profile.unlocks` |
| **用户操作** | 查看成长中心 / 邀请好友 / 查看成就 / 进入设置 |
| **反馈度量** | 首屏加载 < 800ms |
| **边界情况** | 无网络 → 所有数据纯本地 |
| **数据依赖** | profile store, achievement store |
| **验收标准** | 1. 头像/昵称/等级正确展示 2. 经验进度条动画正确 3. 成就列表可滚动 4. 邀请入口可用 5. 设置入口可用 6. 碎片收集进度展示 |

---

### 6.6 后期编辑页（Gallery Detail）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/gallery/detail` |
| **核心功能** | 查看/编辑/导出照片 |
| **加载输入** | photoId → 加载原图 + EXIF |
| **关键状态** | `gallery.currentPhotoId` |
| **用户操作** | 调节参数 → 实时预览 → 保存/导出 |
| **反馈度量** | 参数调整响应 < 50ms，导出 < 2s (1080P) |
| **边界情况** | 照片被删除 / 不支持的格式 |
| **验收标准** | 1. 亮度/对比度/饱和度/色温可调 2. LUT 滤镜生效 3. 磨皮锐化可用 4. 裁剪旋转可用 5. 前后对比 6. 导出到相册 |

### 6.7 模板编辑器页（Template Editor）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/templates/editor` |
| **核心功能** | 创建/编辑拍摄模板 |
| **加载输入** | templateId（编辑已有）或空（新建） |
| **关键状态** | 编辑器内部状态 |
| **用户操作** | 上传姿势图 → 绘制构图线 → 设置参数 → 预览 → 保存 |
| **边界情况** | 无图片选择权限 → 引导开启；参数超出范围 → 自动限幅 |
| **验收标准** | 1. 可上传姿势参考图 2. 可绘制构图叠图 3. 相机参数可设 4. 后期参数可调 5. 保存为 .pptpl 6. 导出分享 |

---

## 7. 服务层接口定义

### 7.1 CameraService（原生插件接口）

```typescript
interface CameraService {
  /** 初始化相机 */
  initialize(config: CameraConfig): Promise<void>
  /** 开始预览（取景器） */
  startPreview(viewContainer: HTMLElement): Promise<void>
  /** 停止预览 */
  stopPreview(): Promise<void>
  /** 设置叠图层 */
  setOverlay(layer: OverlayLayer): Promise<void>
  /** 更新叠图透明度 */
  setOverlayOpacity(opacity: number): Promise<void>
  /** 设置相机参数 */
  setParameters(params: CameraParams): Promise<void>
  /** 获取当前相机参数 */
  getParameters(): Promise<CameraParams>
  /** 拍摄 */
  capture(): Promise<string>           // 返回照片文件路径
  /** 切换摄像头 */
  switchCamera(): Promise<void>
  /** 检测水平 */
  detectLevel(): Promise<{ isLevel: boolean; angle: number }>
  /** 释放相机 */
  release(): Promise<void>
}
```

### 7.2 ImageProcessingService

```typescript
interface ImageProcessingService {
  /** 加载图像 */
  load(path: string): Promise<ImageHandle>
  /** 调整亮度/对比度/饱和度/色温/色调 */
  adjustColor(handle: ImageHandle, params: ColorParams): Promise<ImageHandle>
  /** 应用 LUT */
  applyLut(handle: ImageHandle, lutPath: string): Promise<ImageHandle>
  /** 磨皮 */
  smooth(handle: ImageHandle, strength: number): Promise<ImageHandle>
  /** 锐化 */
  sharpen(handle: ImageHandle, strength: number): Promise<ImageHandle>
  /** 裁剪 */
  crop(handle: ImageHandle, rect: CropRect): Promise<ImageHandle>
  /** 旋转 */
  rotate(handle: ImageHandle, angle: number): Promise<ImageHandle>
  /** 暗角 */
  vignette(handle: ImageHandle, strength: number): Promise<ImageHandle>
  /** 颗粒 */
  grain(handle: ImageHandle, strength: number): Promise<ImageHandle>
  /** 应用完整后期参数包 */
  applyPostProcess(handle: ImageHandle, params: PostProcessParams): Promise<ImageHandle>
  /** 导出 */
  export(handle: ImageHandle, options: ExportOptions): Promise<string>
  /** 释放句柄 */
  release(handle: ImageHandle): void
}
```

### 7.3 TemplateEngine

```typescript
interface TemplateEngine {
  /** 解析 .pptpl JSON */
  parse(json: string): Promise<ResolvedTemplate>
  /** 序列化为 .pptpl JSON */
  serialize(template: LocalTemplate): Promise<string>
  /** 验证模板完整性 */
  validate(template: RawTemplate): ValidationResult
  /** 兼容性检查 */
  checkCompatibility(version: string): CompatibilityResult
  /** 升级旧版本模板 */
  migrate(template: RawTemplate): Promise<ResolvedTemplate>
}
```

---

## 8. 设计 Token 系统（CSS Variables）

对应品牌文档第 4 节配色和第 5 节字体：

```scss
// lumira-tokens.scss — 如画 Lumira 设计 Token

// === 配色系统 ===
// 背景
--color-bg-canvas: #FAF7F2;
--color-bg-card: #FFFFFF;
--color-bg-surface: #F2EEE6;

// 文字
--color-text-primary: #1A1A1A;
--color-text-secondary: #5C5852;
--color-text-tertiary: #9C9690;

// 品牌
--color-brand-primary: #C9A96E;
--color-brand-secondary: #A88550;

// 语义
--color-danger: #B85450;
--color-success: #7A8B5C;

// 分隔
--color-border: #EAE5DC;

// 点缀
--color-tag-gold-bg: #F5EDDB;
--color-tag-gold-text: #8C7340;
--color-tag-red-bg: #F5E3E0;
--color-tag-red-text: #9F3F3A;
--color-tag-green-bg: #EBEEE2;
--color-tag-green-text: #566340;

// 深色模式
--color-bg-canvas-dark: #1C1A17;
--color-bg-card-dark: #262320;
--color-text-primary-dark: #F2EEE6;
--color-brand-dark: #D4B57A;

// === 间距系统（8px 栅格） ===
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 24px;
--space-6: 32px;
--space-7: 48px;
--space-8: 64px;
--space-9: 96px;

// === 字号系统 ===
--font-size-display: 36px;
--font-size-title: 24px;
--font-size-heading: 18px;
--font-size-body: 15px;
--font-size-caption: 13px;
--font-size-tag: 11px;
--font-size-mono: 13px;

// === 圆角 ===
--radius-button: 6px;
--radius-card: 12px;
--radius-pill: 9999px;

// === 阴影 ===
--shadow-none: none;
--shadow-card: 0 1px 3px rgba(0,0,0,0.04);
```

---

## 9. 构建与配置

### 9.1 manifest.json 关键配置

```json
{
  "name": "如画",
  "appid": "__UNI__LUMIRA",
  "versionName": "1.0.0",
  "versionCode": "100",
  "networkTimeout": { "request": 0 },
  "debug": false,
  "uni-app": {
    "usingComponents": true,
    "nvue": { "flex-direction": "column" }
  },
  "app-plus": {
    "distribute": {
      "android": { "permissions": ["android.permission.CAMERA"] },
      "ios": { "infoPlist": { "NSCameraUsageDescription": "使用相机拍摄照片" } }
    },
    "nativePlugins": {
      "LumiraCamera": { "class": "LumiraCameraModule" },
      "LumiraImageProcessor": { "class": "LumiraImageProcessorModule" }
    }
  }
}
```

> **注意**：manifest 中不含任何网络权限。Android 需明确声明不请求 INTERNET 权限。

### 9.2 pages.json 配置

```json
{
  "pages": [
    { "path": "pages/home/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/detail", "style": { "navigationBarTitleText": "模板详情" } },
    { "path": "pages/templates/editor", "style": { "navigationBarTitleText": "模板编辑器" } },
    { "path": "pages/templates/import", "style": { "navigationBarTitleText": "导入模板" } },
    { "path": "pages/templates/unlock", "style": { "navigationBarTitleText": "解锁模板" } },
    { "path": "pages/capture/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/preview", "style": { "navigationBarTitleText": "预览" } },
    { "path": "pages/capture/parameters", "style": { "navigationBarTitleText": "参数" } },
    { "path": "pages/inspiration/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/gallery/index", "style": { "navigationBarTitleText": "相册" } },
    { "path": "pages/gallery/detail", "style": { "navigationBarTitleText": "编辑" } },
    { "path": "pages/gallery/diary", "style": { "navigationBarTitleText": "穿搭日记" } },
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/growth", "style": { "navigationBarTitleText": "成长中心" } },
    { "path": "pages/profile/invite", "style": { "navigationBarTitleText": "邀请有礼" } },
    { "path": "pages/profile/academy", "style": { "navigationBarTitleText": "摄影美学院" } },
    { "path": "pages/profile/academy-detail", "style": { "navigationBarTitleText": "教程详情" } },
    { "path": "pages/profile/settings", "style": { "navigationBarTitleText": "设置" } }
  ],
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "如画",
    "backgroundColor": "#FAF7F2"
  }
}
```

---

## 10. 组件通信约定

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

## 11. 性能目标

| 指标 | 目标 | 测量方式 |
|---|---|---|
| 相机启动 | < 1s | 从点击 Tab 到取景器画面 |
| 叠图渲染 | < 50ms/帧 | 帧率监测 |
| 快门响应 | < 100ms | 按下到捕捉完成 |
| 后期处理 (1080P) | < 2s | 单参数调整到预览 |
| 后期导出 (1080P) | < 3s | 从确认到写入文件 |
| 模板列表加载 | < 500ms | 页面进入到渲染完成 |
| 应用冷启动 | < 3s | 从图标点击到主页 |
| 安装包体积 | < 40MB | — |

---

## 12. 安全与合规

- manifest 零网络权限（不声明 INTERNET 权限）
- 无用户数据收集
- 无第三方 SDK（纯本地工具）
- 相机权限按需请求、动态授权
- 本地 SQLite 数据不加密（设备级存储无敏感数据）
- 导出文件无跟踪标识

---

## 13. 界面设计与布局

> 本章定义「如画 Lumira」的视觉界面设计与页面布局。设计语言承接品牌文档「东方编辑式留白」：大面积留白、serif 编辑式标题、米白暖金墨配色、克制的点缀色，无渐变、无重投影。

### 13.1 设计原则

| 原则 | 说明 |
|---|---|
| 编辑式留白 | 内容区大量宏观留白（页头 `--space-7` 起），呼吸感优先 |
| 内容即界面 | 照片/取景器为主角，UI 控件退让至边缘或悬浮层 |
| 字体对比 | Serif 标题（Noto Serif SC）+ Sans 正文，强对比建立层级 |
| 悬浮层级 | Tab 栏、快门、参数条以悬浮形式浮于内容之上，不占据版式流 |
| 单点缀色 | 品牌金仅用于选中态、关键 CTA、当前模板标记 |

### 13.2 全局布局栅格

```
┌─────────────────────────────┐  ← 状态栏（沉浸式，safe-area-inset-top）
│  AppHeader（可选，透明/留白）  │  ← 高度 88rpx，serif 标题左对齐
├─────────────────────────────┤
│                             │
│                             │
│        内容主体区            │  ← 左右安全边距 --space-5 (24px)
│      （列表/网格/画布）       │     内容最大宽度撑满，卡片间距 --space-4
│                             │
│                             │
│                             │
│      ╭───────────────╮      │  ← 悬浮 Tab 栏（fixed，不占版式流）
│      │ ◐  ▦  ○        │      │     底部 safe-area + 16px
│      ╰───────────────╯      │
└─────────────────────────────┘
```

- **内容安全边距**：左右各 `--space-5`(24px)，顶部页头 `--space-6`(32px)
- **底部内容留白**：所有可滚动页面底部 padding 预留 `96px`（`--space-9`），避免被悬浮 Tab 栏遮挡
- **卡片圆角**：`--radius-card`(12px)，边框统一 `1px solid var(--color-border)`

### 13.3 悬浮 Tab 栏详细设计

悬浮 Tab 栏是本产品导航的核心视觉符号，采用「胶囊悬浮 + 毛玻璃」形态：

```
        ╭───────────────────────────╮
        │   ◐        ▦        ○      │   ← 3 图标等分，选中态描金 + 显文字
        │  拍摄                       │
        ╰───────────────────────────╯
   ↑ 底部 safe-area-inset-bottom + 16px    ↑ 左右内缩 24px
```

**结构与交互**：

| 元素 | 规格 |
|---|---|
| 容器 | 胶囊 `border-radius:9999px`，高 `56px`，白色 72% 透明 + `blur(20px)` |
| 图标（未选中） | 线性图标，`--color-text-tertiary`(#9C9690)，24px |
| 图标（选中） | 填充图标，`--color-brand-primary`(#C9A96E)，24px + 下方显示文字标签 |
| 选中动效 | 图标 `scale(1.0→1.08)` + 文字淡入，`200ms cubic-bezier(0.16,1,0.3,1)` |
| 点击反馈 | `scale(0.94)` on `:active` |
| 拍摄页深色态 | 容器切换 `rgba(28,26,23,0.6)`，未选中图标转 `rgba(255,255,255,0.6)` |

**FloatingTabBar.vue 骨架**：

```vue
<script setup lang="ts">
interface TabItem {
  key: string
  pagePath: string
  label: string
  icon: string
  iconActive: string
}
interface FloatingTabBarProps {
  current: string          // 当前选中 tab key
  theme?: 'light' | 'dark' // 拍摄页传 dark
}
const props = withDefaults(defineProps<FloatingTabBarProps>(), {
  theme: 'light',
})
const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()
</script>

<template>
  <view class="floating-tabbar" :class="`floating-tabbar--${theme}`">
    <view
      v-for="tab in tabs"
      :key="tab.key"
      class="floating-tabbar__item"
      :class="{ 'is-active': tab.key === current }"
      @tap="emit('on-switch', tab.key)"
    >
      <image class="floating-tabbar__icon" :src="tab.key === current ? tab.iconActive : tab.icon" />
      <text v-if="tab.key === current" class="floating-tabbar__label">{{ tab.label }}</text>
    </view>
  </view>
</template>
```

```scss
.floating-tabbar {
  position: fixed;
  left: var(--space-5);
  right: var(--space-5);
  bottom: calc(env(safe-area-inset-bottom) + 16px);
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-around;
  border-radius: 9999px;
  border: 1px solid var(--color-border);
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(20px);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
  z-index: 900;

  &--dark {
    background: rgba(28, 26, 23, 0.6);
    border-color: rgba(255, 255, 255, 0.12);
  }
  &__item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    transition: transform 200ms cubic-bezier(0.16, 1, 0.3, 1);
    &:active { transform: scale(0.94); }
    &.is-active { transform: scale(1.08); }
  }
  &__icon { width: 24px; height: 24px; }
  &__label {
    font-size: var(--font-size-tag);
    color: var(--color-brand-primary);
  }
}
```

### 13.4 关键页面布局（线框图）

#### 拍摄页（Capture Index）— 沉浸式深色

```
┌─────────────────────────────┐
│ ☰ 如画            ⚙          │  ← 顶部透明栏：模板名 + 设置（半透明）
│                             │
│                             │
│      ┌ ─ ─ ┬ ─ ─ ┬ ─ ─ ┐    │
│      │     │     │     │    │  ← 取景器全屏 + 三分构图叠图
│      ├ ─ ─ ┼ ─ ─ ┼ ─ ─ ┤    │     （品牌金半透明网格线）
│      │     │  ◇  │     │    │  ← 姿势剪影叠图（可选）
│      ├ ─ ─ ┼ ─ ─ ┼ ─ ─ ┤    │
│      │     │     │     │    │
│      └ ─ ─ ┴ ─ ─ ┴ ─ ─ ┘    │
│                             │
│  ⊹ 水平  EV+0.3  WB 5200K   │  ← 参数指示条（底部悬浮 pill）
│           （ ◉ ）            │  ← 快门按钮（悬浮，56px 圆）
│      ╭───────────────╮      │
│      │  ◐   ▦   ○     │      │  ← 悬浮 Tab（深色玻璃态）
│      ╰───────────────╯      │
└─────────────────────────────┘
```

- 取景器占满全屏（无边距），叠图层 `z-index:100`
- 快门按钮悬浮于 Tab 栏上方 `--space-6`(32px)，直径 `72px`，外描金环
- 参数指示条为深色玻璃胶囊，仅显示当前生效参数

#### 模板库页（Template Index）— 明亮编辑式

```
┌─────────────────────────────┐
│  模板                        │  ← Serif 大标题（--font-size-display）
│  108 个内置模板               │  ← 副标题 caption 灰
│                             │
│ ［全部］人像  风光  美食  夜景 │  ← 分类横滑标签（pill）
│                             │
│ ┌───────────┐ ┌───────────┐ │
│ │           │ │           │ │  ← 双列瀑布流卡片
│ │   缩略图   │ │   缩略图   │ │     图 + serif 名 + 金标签
│ │           │ │           │ │
│ │ 晨光人像   │ │ 城市街拍   │ │
│ │ ◆ 构图·参数 │ │ ◆ 构图     │ │
│ └───────────┘ └───────────┘ │
│ ┌───────────┐ ┌───────────┐ │
│ │  ...      │ │  ...      │ │
│      ╭───────────────╮      │
│      │  ◐   ▦   ○     │      │  ← 悬浮 Tab（明亮态）
│      ╰───────────────╯      │
└─────────────────────────────┘
```

- 双列瀑布流，卡片间距 `--space-4`(16px)
- 卡片：白底、1px 边框、12px 圆角，图片顶部圆角裁切
- 模板能力用小金标签标注（构图/姿势/参数/后期）

#### 我的页（Profile Index）

```
┌─────────────────────────────┐
│                             │
│         我的                 │  ← Serif 标题
│                             │
│ ┌─────────────────────────┐ │
│ │  128        36      12   │ │  ← 统计 Bento：拍摄/模板/收藏
│ │  拍摄张数   使用模板  收藏  │ │
│ └─────────────────────────┘ │
│                             │
│  ▸ 我的相册                  │  ← 列表项，右箭头
│  ▸ 导入模板                  │
│  ▸ 我的模板                  │
│  ─────────────────────────  │  ← 1px 分隔线
│  ▸ 设置                      │
│  ▸ 关于如画                  │
│      ╭───────────────╮      │
│      │  ◐   ▦   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

- 统计区为单张 Bento 卡片，三栏等分数字（serif 大字）+ caption 标签
- 功能入口为无框列表，仅 `border-bottom` 分隔

#### 后期编辑页（Gallery Detail）

```
┌─────────────────────────────┐
│ ✕                    对比 ⇄   │  ← 顶栏：关闭 + 前后对比
│ ┌─────────────────────────┐ │
│ │                         │ │
│ │        图像画布          │ │  ← 主画布区（居中，深色背景衬托）
│ │                         │ │
│ └─────────────────────────┘ │
│                             │
│ 调色  LUT  裁剪  磨皮  锐化   │  ← 工具横滑标签
│ ─────────────────────────── │
│  亮度   ●───────────  +12   │  ← 参数滑块区
│  对比   ────●────────   -4   │
│  饱和   ──────●──────    0   │
│                             │
│      ［ 重置 ］  ［ 导出 ］    │  ← 底部操作按钮（导出为墨黑 CTA）
└─────────────────────────────┘
```

- 后期编辑为全屏工作台，**不显示悬浮 Tab 栏**（沉浸编辑）
- 导出按钮为墨黑实底 CTA（`--color-text-primary` 底 + 白字，6px 圆角）

### 13.5 组件视觉规范速查

| 组件 | 关键样式 |
|---|---|
| 页面标题 | Noto Serif SC，`--font-size-display`(36px)，`letter-spacing:-0.02em` |
| 主 CTA 按钮 | 墨黑底 `#1A1A1A` + 白字，`--radius-button`(6px)，无投影，`:active scale(0.98)` |
| 次级按钮 | 白底 + 1px 边框 + 墨黑字 |
| 卡片 | 白底、`1px solid var(--color-border)`、`--radius-card`(12px)、`--shadow-card` |
| 标签/Badge | pill，`--font-size-tag`(11px)，点缀色底 + 对应文字色，大字距 |
| 分隔线 | `1px solid var(--color-border)`，无阴影 |
| 滑块 | 轨道 `--color-border`，滑块头品牌金，数值 mono 字体 |

### 13.6 动效规范

- **页面进入**：内容块 `translateY(12px) + opacity:0 → 1`，`600ms cubic-bezier(0.16,1,0.3,1)`
- **列表交错**：卡片 `animation-delay: calc(var(--index) * 80ms)`
- **Tab 切换**：仅图标 scale + 文字淡入，禁止整栏位移
- **仅动画 `transform` 与 `opacity`**，不触发布局重排

---
