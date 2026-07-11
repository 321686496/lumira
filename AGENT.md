# AGENT.md — 摄影辅助应用项目

> 项目根目录智能体指令文件
> 开发范式：**Harness Engineering（马具工程）**
> 最后更新：2026-07-09（新增 uni-app 官方文档强制阅读章节）

---

## 一、项目概览

本项目包含 **两个独立的 uni-app 工程**，共享 `.pptpl` 模板格式，但产品边界与商业模式完全不同：

| 维度 | 如画 Lumira | 画集 Lumira Studio |
|---|---|---|
| 工程目录 | `lumira-app/` | `lumira-studio-app/` |
| 产品定位 | 单机离线拍摄辅助 | 联网模板社区平台 |
| 网络依赖 | 零网络权限 | 全功能在线 |
| AI 能力 | 纯算法（LUT/滤波/锐化） | 云端 AI（识别/评分/分割） |
| 模板来源 | 本地预置 + 文件导入 | 内置 + 市场下载 |
| 商业模式 | 预置付费模板 | 免费 + 模板抽成 + 广告 |
| 用户身份 | 无账号 | 普通用户 / 创作者 |
| 核心文档 | PRD + Brand + Frontend | PRD + Brand + Frontend |

> **关键约束**：两个工程独立开发、独立构建、独立发布。不允许在同一工程中通过条件编译混用。

### 1.1 ⚠️ 防混淆强制规则（MUST NOT VIOLATE）

两个AppName虽然共享 `.pptpl` 模板格式，但它们是**完全独立的产品**。AI Agent 在执行任何任务时，**必须严格区分**二者，绝不允许混淆：

| 隔离维度 | 如画 Lumira | 画集 Lumira Studio |
|---|---|---|
| 产品边界 | 单机离线拍摄辅助，无账号、无网络 | 联网模板社区平台，有用户体系、有网络 |
| 功能归属 | 预置模板 + 本地文件导入 + LUT 色彩滤镜 | 模板市场下载 / 上传 / 评分 / 创作者体系 |
| 文档路径 | `docs/superpowers/specs/2026-07-03-lumira-*.md` | `docs/superpowers/specs/2026-07-03-lumira-studio-*.md` |
| 设计令牌 | `$color-*` / 暗色系 / 个人沉浸感 | `$studio-*` / 亮色系 / 社区沉浸感 |
| 工程代码 | `lumira-app/` 目录下全部文件 | `lumira-studio-app/` 目录下全部文件 |

**禁止行为（任何一条都视为严重错误）：**

1. ❌ **禁止跨 App 引用文档**：修改如画代码时查阅画集 PRD/品牌/前端文档，反之亦然
2. ❌ **禁止跨 App 复制功能**：将画集的联网功能（如模板市场、用户评价）引入如画，或将在画的纯离线逻辑套用到画集
3. ❌ **禁止跨 App 复用设计令牌**：如画组件使用 `$studio-*` 变量，或画集组件使用 `$color-*` 变量
4. ❌ **禁止跨 App 修改目录**：在 `lumira-app/` 中创建属于画集的功能模块，反之亦然
5. ❌ **禁止在文档中混用产品名称**：如画文档中不出现"画集""Lumira Studio"，画集文档中不出现"如画""Lumira"（仅本对比表例外）
6. ❌ **禁止将共享类型当作功能互通借口**：`PhotoTemplate` 等共享 DTO 仅描述模板数据结构，不代表两 App 的业务逻辑可互通

**执行前自检**：每次任务启动时，先确认：
- 本次操作的目标 App 是哪一个？
- 查阅的文档路径是否属于该 App？
- 修改的代码文件是否在该 App 的工程目录下？
- 引入的功能是否属于该 App 的产品边界？

---

## 二、Harness Engineering 开发范式

### 2.1 范式定义

Harness Engineering（马具工程）借鉴马具制造中 **先搭骨架再填充** 的工艺思想，将前端开发拆解为三个严格递进的阶段：

```
┌─────────────────────────────────────────────────┐
│                 Harness Engineering               │
│                                                   │
│  骨架优先          接口驱动          规格验证       │
│  (Skeleton-First)  (Interface-Driven) (Spec-Verified)│
│                                                   │
│  1. 目录结构搭建     1. TS 接口定义    1. 对照文档验收   │
│  2. 组件树声明      2. Service 层契约  2. 类型安全审查   │
│  3. 路由骨架        3. Store 类型      3. 边界条件覆盖   │
│  4. 页面占位        4. Props/Emits 签名 4. 性能基线比对   │
│  5. 数据流拓扑      5. API 请求响应    5. 权限合规检查   │
└─────────────────────────────────────────────────┘
```

### 2.2 三阶段细则

#### 阶段一：骨架优先（Skeleton-First）

任何功能开发前，必须先搭建其结构骨架。骨架是**可类型检查但无视觉/业务逻辑**的空壳。

**具体规则：**

1. **目录骨架**：按 `pages/` → `components/` → `composables/` → `services/` → `stores/` 创建目录，确保路径约定一致
2. **组件树声明**：在文档中声明组件层级树（父→子→孙），每个组件标注其 Props/Emits 接口
3. **路由骨架**：提前注册所有页面路由（含 TabBar），页面组件导出空的 `<template>` 占位
4. **Store 骨架**：定义所有 Pinia Store 的名称与接口类型，getters/actions 仅声明签名不实现
5. **Service 接口**：Service 层仅导出 TypeScript `interface` 或 `type`，不导出任何实现

**示例：骨架阶段的一个页面组件**

```vue
<script setup lang="ts">
// 仅定义接口 + 骨架 Props，无逻辑
interface CapturePageProps {
  templateId?: string
}
const props = defineProps<CapturePageProps>()
const emit = defineEmits<{
  (e: 'on-capture', photo: string): void
}>()
</script>

<template>
  <view class="capture-page">
    <!-- 骨架阶段仅占位容器 -->
  </view>
</template>
```

#### 阶段二：接口驱动（Interface-Driven）

骨架搭建完成后，所有跨模块通信必须通过 **预先定义的接口契约** 进行。

**接口优先于实现** 原则：
- 先定义 Service Layer 的 `interface`，再实现具体类
- 先定义 Pinia Store 的 `type` 签名，再写 Action 逻辑
- 先定义组件 Props/Emits 的 TS 类型，再写模板
- 先定义 API 请求/响应的 DTO 类型，再对接后端

**接口定义规范：**

```typescript
// 1. Service 接口 — 必须导出 interface
export interface CameraService {
  initialize(config: CameraConfig): Promise<void>
  startPreview(view: CameraView): void
  capture(): Promise<PhotoResult>
  release(): void
}

// 2. Store 接口 — 使用 type 或 interface
interface CaptureState {
  isReady: boolean
  currentTemplate: Template | null
  previewFrame: string | null
}
interface CaptureActions {
  startSession(): Promise<void>
  applyTemplate(id: string): void
}

// 3. Props 接口 — 命名 [ComponentName]Props
interface CameraOverlayProps {
  template: Template
  opacity: number
  onReady?: () => void
}

// 4. API DTO — 请求/响应分离
interface TemplateListRequest {
  category?: string
  page: number
  pageSize: number
}
interface TemplateListResponse {
  items: TemplateSummary[]
  total: number
  hasMore: boolean
}
```

#### 阶段三：规格验证（Spec-Verified）

实现完成后，必须对照前端设计文档的 **规格表** 逐项验证：

**验证清单（每功能必检）：**
- [ ] 页面路由与文档中的路由表一致
- [ ] 组件 Props 签名与文档声明一致
- [ ] Store 状态/actions 与文档一致
- [ ] Service 方法签名与接口定义一致
- [ ] 设计 Token 使用与文档命名一致（无 hardcode 颜色/间距）
- [ ] 性能基线满足文档中的目标值
- [ ] 权限声明满足文档合规要求

---

## 三、项目目录结构约定

### 3.1 根级结构

```
photo_post/
├── AGENT.md                        # 本文件
├── .trae/                          # TRAE IDE 配置与技能
│   ├── rules/project_rules.md
│   └── skills/
├── assets/
│   └── logos/                      # SVG 品牌资产
│       ├── lumira/
│       └── lumira-studio/
├── docs/
│   ├── specs/                      # 前端工程文档
│   │   ├── 2026-07-03-lumira-frontend.md
│   │   └── 2026-07-03-lumira-studio-frontend.md
│   └── superpowers/specs/          # PRD / 品牌文档
│       ├── 2026-07-03-lumira-prd.md
│       ├── 2026-07-03-lumira-brand.md
│       ├── 2026-07-03-lumira-studio-prd.md
│       └── 2026-07-03-lumira-studio-brand.md
├── lumira-app/                     # 如画 Lumira 工程（待创建）
└── lumira-studio-app/              # 画集 Lumira Studio 工程（待创建）
```

### 3.2 各 uni-app 内部结构

```
lumira-app / lumira-studio-app/
├── manifest.json                   # uni-app 配置
├── pages.json                      # 路由配置
├── tsconfig.json
├── vite.config.ts
├── src/
│   ├── main.ts                     # 入口
│   ├── App.vue                     # 根组件
│   ├── pages/                      # 页面（按 Tab/功能分组）
│   ├── components/                 # 公共组件
│   │   ├── common/                 #  通用组件（Button, Icon, Loading...）
│   │   ├── capture/                #  拍摄相关组件
│   │   ├── template/               #  模板组件
│   │   └── layout/                 #  布局组件
│   ├── composables/                # 组合式逻辑
│   │   ├── useCamera.ts
│   │   ├── useTemplate.ts
│   │   └── ...
│   ├── services/                   # 服务层（接口+实现）
│   │   ├── camera.service.ts
│   │   ├── image-processor.service.ts
│   │   ├── template-engine.service.ts
│   │   └── ...
│   ├── stores/                     # Pinia 状态仓库
│   │   ├── capture.store.ts
│   │   ├── gallery.store.ts
│   │   └── ...
│   ├── types/                      # 全局类型定义
│   │   ├── template.ts             #  .pptpl 类型
│   │   ├── photo.ts
│   │   └── ...
│   ├── theme/                      # 设计令牌
│   │   ├── colors.ts
│   │   ├── spacing.ts
│   │   └── index.ts
│   └── utils/                      # 小工具函数
│       └── ...
└── static/                         # 静态资源
```

> **命名约定**：
> - 页面目录名 = 路由 segement（英文复数/名词）
> - 组件名：`PascalCase.vue`
> - Composable 名：`useCamelCase.ts`
> - Service 名：`kebab-case.service.ts`
> - Store 名：`kebab-case.store.ts`

---

## 四、编码约定

### 4.1 通用规则

- **语言**：TypeScript 强制，禁用 `any`，禁用 `@ts-ignore`
- **风格**：Vue3 Composition API + `<script setup lang="ts">`
- **CSS**：SCSS + 设计 Token 变量，禁止内联 style
- **注释**：不写冗余注释（能通过代码自表达的不要注释），仅在有隐含逻辑时添加
- **命名**：
  - 组件 Props → `camelCase` 命名（Vue 模板自动转 kebab-case）
  - Emit 事件 → `on-action-name` 格式
  - Pinia Action → 动词开头：`fetchTemplates`, `applyTemplate`
  - 常量 → `UPPER_SNAKE_CASE`

### 4.2 组件 Props 风格

```typescript
// ✅ 正确：严格类型 + 默认值
interface PhotoCardProps {
  src: string
  title?: string        // 可选
  width?: number        // 可选，默认 200
  showBadge?: boolean   // 可选，默认 false
}
const props = withDefaults(defineProps<PhotoCardProps>(), {
  title: '',
  width: 200,
  showBadge: false,
})
```

```typescript
// ❌ 禁止：无类型的 props
defineProps(['src', 'title'])
```

### 4.3 Service 层约定

- 每个 Service 对应一个独立的 `.ts` 文件
- 导出 **interface**（契约）与 **实现类**（Impl）分离
- 实现类名以 `Impl` 后缀

```typescript
// camera.service.ts
export interface CameraService {
  initialize(config: CameraConfig): Promise<void>
  capture(): Promise<PhotoResult>
  release(): void
}

// camera.service.impl.ts
export class CameraServiceImpl implements CameraService {
  async initialize(config: CameraConfig): Promise<void> { /* ... */ }
  async capture(): Promise<PhotoResult> { /* ... */ }
  release(): void { /* ... */ }
}
```

### 4.4 Store 约定

- 使用 `defineStore` + Setup 语法
- 所有异步操作返回 `Promise`，错误在 Action 内部 try/catch
- 禁止 Store-to-Store 直接引用，通过 Action 参数传入

```typescript
export const useCaptureStore = defineStore('capture', () => {
  const isReady = ref(false)
  const currentTemplate = ref<Template | null>(null)

  async function startSession(): Promise<void> {
    try {
      await cameraService.initialize(config)
      isReady.value = true
    } catch (e) {
      isReady.value = false
      throw e
    }
  }

  return { isReady, currentTemplate, startSession }
})
```

---

## 五、模板 `.pptpl` 互操作规范

两个 APP 共享 `.pptpl` 模板格式。`.pptpl` 为完全自包含的 JSON 文件，不依赖任何外部资源文件。Agent 必须确保模板处理的代码遵循以下统一接口结构（实现位于各 APP 的 `types/template.ts`）：

```typescript
// types/template.ts

/** 剪影资源类型 */
type SilhouetteType = 'builtin' | 'image' | 'svg'

/**
 * 剪影资源（统一承载内置引用与自定义资源）
 * - builtin: data 为内置 SVG 库 key（如 'standing-profile'）
 * - image:   data 为 base64 data URL（用户导入 PNG/JPG）
 * - svg:     data 为内联 SVG 字符串（用户绘制）
 */
interface SilhouetteResource {
  type: SilhouetteType
  data: string
  filename?: string
  sizeKB?: number
}

interface PhotoTemplate {
  meta: {
    id: string
    name: string
    author: string
    version: string
    category: 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life'
    tags: string[]
    price: number
    cover: string
    description: string
    referenceSource: string  // 参数参考来源（如「样片 EXIF: Pexels #12345」）
  }
  composition: {
    overlayType: 'rule_of_thirds' | 'golden_ratio' | 'diagonal' | 'grid' | 'leading_lines' | 'center' | 'none'
    gridType?: 'thirds' | 'quarters' | 'golden_spiral'
    subjectFrame: { x: number; y: number; w: number; h: number }
    opacity: number
    aspectRatio: string
    description: string
  }
  pose: {
    silhouette: SilhouetteResource
    position: { x: number; y: number }
    scale: number
    rotation: number
    description: string
  }
  camera: {
    exposureCompensation: number
    isoMode: 'auto' | 'manual'
    iso: number
    shutterSpeed: string
    whiteBalance: 'daylight' | 'cloudy' | 'shade' | 'tungsten' | 'fluorescent' | 'custom'
    whiteBalanceK: number
    flashMode: 'off' | 'on' | 'auto' | 'torch'
    focusMode: 'auto' | 'manual' | 'continuous'
    filterPreset: string
    lensSuggestion: 'wide' | 'main' | 'telephoto' | 'ultra_wide'
  }
  sceneGuide: {
    lightDirection: string
    shootingDistance: string
    background: string
    props: string[]
    bestTime: string
    tips: string[]
  }
  postProcess: {
    cropRatio: string
    color: { brightness: number; contrast: number; saturation: number; temperature: number; tint: number }
    smoothStrength: number
    sharpen: number
    vignette: number
    grain: number
    lut: 'none' | 'cinematic' | 'vintage' | 'bw' | 'warm_film' | 'cool_film' | 'pastel' | 'fuji'
  }
}
```

**剪影资源自包含策略**：
- 导出时：`builtin` 仅存 key 字符串；`image` 存完整 base64 data URL；`svg` 存完整 SVG 字符串
- 导入时：校验 `builtin` 的 key 是否存在于内置 SVG 库，不存在则降级为 `none`
- ID 冲突时：自动追加 `_imported_${Date.now()}` 后缀避免覆盖

- 离线版导入时做版本兼容性检查
- 联网版上传/下载时按 `meta.category` 等元数据过滤

---

## 六、设计令牌使用

所有颜色、间距、圆角必须通过 SCSS 变量引用，禁止硬编码。

**如画 Lumira 令牌引用：**
```scss
@import '@/theme/index.scss';
// .my-class { color: $color-primary; padding: $spacing-md; }
```

**画集 Lumira Studio 令牌引用：**
```scss
@import '@/theme/index.scss';
// .my-class { color: $studio-primary; padding: $spacing-md; }
```

完整令牌定义参见各 APP 的前端设计文档 ["设计 Token 系统"](#)。

---

## 七、开发工作流

### 7.1 新建功能流程

```
┌──────────────────┐
│ 1. 查阅前端设计文档  │ ← 确认页面 Spec 与接口定义
├──────────────────┤
│ 2. 搭建骨架        │ ← 创建目录、组件占位、路由注册
├──────────────────┤
│ 3. 定义接口        │ ← Service/Store/Props 类型声明
├──────────────────┤
│ 4. 实现逻辑        │ ← 填充骨架，实现 Service & Store
├──────────────────┤
│ 5. 规格验证        │ ← 对照文档逐项检查
└──────────────────┘
```

### 7.2 模板开发流程

1. 在 `types/template.ts` 中定义模板 DTO
2. 在 `services/template-engine.service.ts` 中定义 parse/validate/serialize 接口
3. 实现模板引擎（JSON 解析 + 版本迁移）
4. 在组件层消费模板数据（取景器覆盖、参数应用）

### 7.3 AI Agent 操作准则

- **App 隔离（最高优先级）**：每次任务必须先确认目标 App，只查阅该 App 的文档、只在该 App 工程目录下编码。严格遵守第一章第 1.1 节的「防混淆强制规则」
- **文件操作**：编辑前先读取目标文件完整上下文，理解已有风格后再修改
- **规格先行**：任何新功能实现前，先查阅**对应 APP** 的 PRD 与前端设计文档（禁止跨 App 查阅）
- **骨架第一**：不要一次性实现完整功能，先骨架后填充
- **类型安全**：所有新代码必须有完整 TypeScript 类型，不允许 `any`
- **Doc-As-Code**：文档与代码同等重要，更新代码即更新对应文档
- **变更即同步**：任何工程或文档变更后，立即按第九章「文档同步规则」回写 AGENT.md 与相关文档
- **跨 App 自检**：修改完成后再次确认未引入另一 App 的功能、令牌、命名或文档引用

---

## 八、关键文档索引

| 文档 | 路径 | 用途 |
|---|---|---|
| 如画 PRD | `docs/superpowers/specs/2026-07-03-lumira-prd.md` | 产品需求规格 |
| 如画 品牌 | `docs/superpowers/specs/2026-07-03-lumira-brand.md` | 品牌设计体系 |
| 如画 前端 | `docs/specs/2026-07-03-lumira-frontend.md` | 前端工程规格（含界面设计与布局） |
| 如画 测试 | `docs/specs/2026-07-03-lumira-test.md` | 前端测试用例（跳转/交互/本地服务数据） |
| 如画 v2.0 扩展 | `docs/superpowers/specs/2026-07-06-lumira-v2-features-design.md` | 游戏化·内容·裂变·商业化设计 |
| 画集 PRD | `docs/superpowers/specs/2026-07-03-lumira-studio-prd.md` | 产品需求规格 |
| 画集 品牌 | `docs/superpowers/specs/2026-07-03-lumira-studio-brand.md` | 品牌设计体系 |
| 画集 前端 | `docs/specs/2026-07-03-lumira-studio-frontend.md` | 前端工程规格（含界面设计与布局） |
| 画集 测试 | `docs/specs/2026-07-03-lumira-studio-test.md` | 前端测试用例（跳转/交互/API 接口数据） |
| 项目规则 | `.trae/rules/project_rules.md` | TRAE IDE 行为规则 |

> **维护要求**：本索引表必须与实际文件保持同步。新增/重命名/删除任何文档时，同步更新此表（详见第九章）。

---

## 九、文档同步规则（强制）

> **核心原则**：文档是项目的单一事实来源（Single Source of Truth）。**任何工程代码或文档的变更，都必须同步回 AGENT.md 及相关文档**，确保地图与实际状态永远一致。

### 9.1 触发同步的变更类型

以下任一变更发生时，**必须在同一次提交/任务内**同步更新对应文档：

| 变更类型 | 需同步的目标 |
|---|---|
| 新增/删除/重命名文档 | 更新第八章「关键文档索引」表 |
| 新增/删除/调整页面路由 | 更新对应 APP 前端文档「页面路由」+ 测试文档用例 |
| 新增/修改组件树结构 | 更新前端文档「组件树」章节 |
| 新增/修改 Service / Store / API 接口 | 更新前端文档接口定义 + 测试文档 DATA 用例 |
| 修改设计 Token / 品牌视觉 | 更新品牌文档 + 前端文档「设计 Token」 |
| 修改目录结构约定 | 更新本文件第三章 |
| 新增/修改编码约定或工作流 | 更新本文件第四、七章 |
| 新增功能特性 | 更新对应 PRD + 前端文档 + 测试文档 |
| 修改产品边界 / 商业模式 | 更新第一章「项目概览」对比表 |

### 9.2 同步操作准则

1. **原子性**：代码变更与文档同步在同一任务内完成，不允许「先改代码，文档后补」
2. **双向核对**：修改文档后，反向核对第八章索引与本章规则是否需要更新
3. **更新时间戳**：任何对 AGENT.md 的修改，同步更新文件头部「最后更新」日期
4. **测试文档跟随**：路由/交互/接口变更时，测试文档（`*-test.md`）的对应用例必须同步增删
5. **一致性优先**：若发现文档与代码不一致，以「先对齐文档」为准，再据文档修正代码（Spec-Verified）

### 9.3 AI Agent 强制检查

Agent 在完成任何工程或文档变更后，**必须自问并确认**：

- [ ] 本次变更是否属于 9.1 表中的触发类型？
- [ ] 对应的目标文档是否已同步更新？
- [ ] 第八章文档索引是否需要增删条目？
- [ ] AGENT.md 头部「最后更新」日期是否已刷新？
- [ ] 测试文档用例是否已跟随路由/交互/接口变更？

> 未完成上述同步的变更视为**未完成的任务**。

---

## 十、Harness Engineering 检查清单

开发过程中，Agent 应在每个功能完成后自行检查以下项目：

### 骨架完整性
- [ ] 所有页面路由已在 `pages.json` 注册
- [ ] 页面组件均已创建，至少包含空 `<template>`
- [ ] 组件树层级与文档一致

### 接口完整性
- [ ] 所有跨组件通信有 Props/Emits 类型签名
- [ ] Service 接口独立声明，未与实现混合
- [ ] Store Action 返回类型已定义

### 规格一致性
- [ ] 使用设计 Token 而非硬编码值
- [ ] 权限声明符合 APP 类型（离线 vs 联网）
- [ ] 无 `any` 类型、无 `@ts-ignore`
- [ ] 性能基线未降低

---

## 十一、uni-app 官方文档（强制阅读）

每次开发 uni-app 项目时，**必须**阅读以下官方文档，确保代码符合 uni-app 的最佳实践和规范：

| 文档 | 链接 | 用途 |
|---|---|---|
| 快速入门 | https://uniapp.dcloud.net.cn/quickstart.html | uni-app 项目创建、目录结构、生命周期、编译流程 |
| 组件 | https://uniapp.dcloud.net.cn/component/ | uni-app 内置组件 API 参考（view、scroll-view、swiper 等） |

> **执行要求**：
> - 开发前：阅读「快速入门」了解项目结构与生命周期
> - 开发中：查阅「组件」文档确认组件属性、事件、插槽的正确用法
> - 遇到平台差异时：参考官方文档中的「平台差异说明」

---

> **本文件是项目的开发宪法，Agent 在每次会话中须优先加载并遵循。**
