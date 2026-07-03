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
│   │   ├── capture/            # 拍摄模块
│   │   │   ├── index.vue       #   拍摄页（取景器 + 叠图）
│   │   │   ├── preview.vue     #   拍摄预览页
│   │   │   └── parameters.vue  #   参数面板（半屏弹窗）
│   │   ├── gallery/            # 相册模块
│   │   │   ├── index.vue       #   相册页
│   │   │   └── detail.vue      #   照片详情/后期编辑
│   │   ├── templates/          # 模板模块
│   │   │   ├── index.vue       #   模板库页
│   │   │   ├── detail.vue      #   模板详情页
│   │   │   ├── editor.vue      #   模板编辑器
│   │   │   └── import.vue      #   模板导入页
│   │   └── profile/            # 个人/设置模块
│   │       ├── index.vue       #   我的页
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
│   │   ├── capture.ts         #   拍摄状态
│   │   ├── gallery.ts         #   相册状态
│   │   ├── templates.ts       #   模板库状态
│   │   └── settings.ts        #   设置状态
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
| `/pages/capture/index` | 拍摄页 | 是 | 首页，取景器 + 快门 |
| `/pages/capture/preview` | 拍摄预览 | 否 | 拍摄后立即预览 |
| `/pages/capture/parameters` | 参数面板 | 否 | 半屏弹窗式 |
| `/pages/templates/index` | 模板库 | 是 | 所有可用模板 |
| `/pages/templates/detail` | 模板详情 | 否 | 单模板详解 |
| `/pages/templates/editor` | 模板编辑器 | 否 | 创建/编辑模板 |
| `/pages/templates/import` | 模板导入 | 否 | 从文件导入 |
| `/pages/gallery/index` | 相册 | 否 | 从拍摄页底部入口 |
| `/pages/gallery/detail` | 照片详情/后期 | 否 | 查看/编辑单张 |
| `/pages/profile/index` | 我的 | 是 | 个人/设置入口 |
| `/pages/profile/settings` | 设置 | 否 | 应用设置 |

### 3.2 导航图

```
[Tab 1: 拍摄] ──── (/pages/capture/index)
   ├── 拍摄预览 ──→ (/pages/capture/preview)
   │     └── 后期编辑 ──→ (/pages/gallery/detail)
   ├── 参数面板 ──→ (/pages/capture/parameters)
   └── 相册入口 ──→ (/pages/gallery/index)
                      └── 照片详情 ──→ (/pages/gallery/detail)

[Tab 2: 模板] ──── (/pages/templates/index)
   ├── 模板详情 ──→ (/pages/templates/detail)
   ├── 模板创建 ──→ (/pages/templates/editor)
   └── 模板导入 ──→ (/pages/templates/import)

[Tab 3: 我的] ──── (/pages/profile/index)
   └── 设置 ──→ (/pages/profile/settings)
```

### 3.3 TabBar 配置

```json
{
  "tabBar": {
    "color": "#9C9690",
    "selectedColor": "#C9A96E",
    "backgroundColor": "#FAF7F2",
    "borderStyle": "white",
    "list": [
      {
        "pagePath": "pages/capture/index",
        "iconPath": "assets/icons/tab-capture.svg",
        "selectedIconPath": "assets/icons/tab-capture-active.svg",
        "text": "拍摄"
      },
      {
        "pagePath": "pages/templates/index",
        "iconPath": "assets/icons/tab-templates.svg",
        "selectedIconPath": "assets/icons/tab-templates-active.svg",
        "text": "模板"
      },
      {
        "pagePath": "pages/profile/index",
        "iconPath": "assets/icons/tab-profile.svg",
        "selectedIconPath": "assets/icons/tab-profile-active.svg",
        "text": "我的"
      }
    ]
  }
}
```

---

## 4. 组件树（Harness 骨架）

```
App.vue
├── AppTabBar.vue                   # 底部导航（3 Tab）
│
├── [Tab: 拍摄] CaptureIndex.vue
│   ├── AppHeader.vue               # 标题栏 + 设置入口
│   ├── CameraViewfinder.vue        # 取景器（全屏主体）
│   │   ├── OverlayLayer.vue        #   构图线叠图
│   │   │   ├── RuleOfThirdsGrid.vue
│   │   │   ├── GuideLines.vue
│   │   │   └── PoseOverlay.vue     #   姿势参考叠图
│   │   └── ParameterBar.vue        #   参数叠加指示
│   ├── TemplateTag.vue             # 当前模板名称
│   └── ShutterButton.vue           # 快门按钮
│
├── [Tab: 模板] TemplateIndex.vue
│   ├── AppHeader.vue
│   ├── CategoryTabs.vue            # 分类标签
│   └── TemplateCard.vue[]          # 模板卡片列表
│
├── [Tab: 我的] ProfileIndex.vue
│   ├── AppHeader.vue
│   ├── ProfileStats.vue            # 拍摄统计
│   └── SettingsEntry.vue           # 设置入口
│
├── TemplateDetail.vue              # 非 Tab 页
│   ├── OverlayPreview.vue
│   └── TemplateInfo.vue
│
├── TemplateEditor.vue              # 非 Tab 页
│   ├── EditorCanvas.vue            # 编辑画布
│   ├── ControlPanel.vue            # 参数控制面板
│   └── PreviewToggle.vue           # 预览切换
│
├── ImageEditor.vue                 # 非 Tab 页（后期）
│   ├── ImageCanvas.vue             # 图像显示画布
│   ├── AdjustmentPanel.vue         # 参数调节面板
│   │   ├── ColorSliders.vue        #   调色滑块
│   │   ├── LutSelector.vue         #   LUT 滤镜选择
│   │   ├── CropFrame.vue           #   裁剪框
│   │   ├── SmoothSlider.vue        #   磨皮强度
│   │   └── SharpenSlider.vue       #   锐化强度
│   └── CompareToggle.vue           # 前后对比
│
└── SettingsPage.vue                 # 非 Tab 页
    └── SettingItem.vue[]
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

### 6.1 拍摄页（Capture Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/capture/index` |
| **Tab** | 是，首页 |
| **核心功能** | 取景器 + 叠图 + 拍摄 |
| **加载输入** | 相机权限 → 激活相机 → 加载默认/上次模板 |
| **关键状态** | `capture.isActive`, `capture.activeTemplateId` |
| **用户操作** | 选模板 → 按快门 → 预览/重拍 |
| **反馈度量** | 相机启动 < 1s，叠图渲染 < 50ms/帧 |
| **边界情况** | 无相机权限 → 显示权限引导页；无默认模板 → 自由拍摄模式 |
| **数据依赖** | camera service, template store |
| **验收标准** | 1. 取景器实时显示画面 2. 叠图准确叠加 3. 快门响应 < 100ms 4. 参数面板可调 5. 无网络权限提示 |

### 6.2 模板库页（Template Index）

| 属性 | 规格 |
|---|---|
| **路径** | `/pages/templates/index` |
| **Tab** | 是 |
| **核心功能** | 浏览/搜索/分类模板 |
| **加载输入** | 读取 SQLite 中所有模板（内置+导入） |
| **关键状态** | `templates.*` |
| **用户操作** | 分类筛选 → 点击模板 → 进入详情/直接套用 |
| **反馈度量** | 列表加载 < 500ms |
| **边界情况** | 无模板 → 展示空状态+引导创建/导入 |
| **数据依赖** | template store, storage service |
| **验收标准** | 1. 内置模板正确显示 2. 分类筛选正常 3. 模板卡片展示完整 4. 点击可套用 |

### 6.3 后期编辑页（Gallery Detail）

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

### 6.4 模板编辑器页（Template Editor）

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
    { "path": "pages/capture/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/preview", "style": { "navigationBarTitleText": "预览" } },
    { "path": "pages/templates/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/detail", "style": { "navigationBarTitleText": "模板详情" } },
    { "path": "pages/templates/editor", "style": { "navigationBarTitleText": "模板编辑器" } },
    { "path": "pages/templates/import", "style": { "navigationBarTitleText": "导入模板" } },
    { "path": "pages/gallery/index", "style": { "navigationBarTitleText": "相册" } },
    { "path": "pages/gallery/detail", "style": { "navigationBarTitleText": "编辑" } },
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
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
