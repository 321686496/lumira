# 模板系统与拍照引导设计文档

**日期**: 2026-07-11
**状态**: 已通过设计评审，待编写实现计划
**关联文档**:
- PRD: `docs/superpowers/specs/2026-07-03-lumira-prd.md`（第三章 模板体系）
- AGENT.md: 第五章 模板 .pptpl 互操作规范
- 前端设计: `docs/specs/2026-07-03-lumira-frontend.md`
- 页面设计: `docs specs/2026-07-09-lumira-frontend-page-design.md`

---

## 一、背景与目标

### 1.1 背景

如画（Lumira）App 当前已有模板列表、模板详情、拍照页等页面骨架，但存在以下问题：

1. **模板数据缺失**：无集中的模板数据文件，各页面内联 mock 数据，字段不统一
2. **字段定义不一致**：PRD 的 `.pptpl` JSON 格式与 AGENT.md 的 `PhotoTemplate` TS 接口存在结构差异
3. **拍照页无模板引导**：拍照页仅有静态三分法网格与硬编码参数，未实现真正的模板套用
4. **模板传递断点**：模板详情页跳转拍照页时未传 `templateId`，拍照页不接收也不加载模板
5. **无自定义模板功能**：用户无法创建、编辑、导入、导出自定义模板

### 1.2 目标

1. 落地 12 个系统内置模板（8 免费 + 4 付费），含完整参数（构图/姿势/相机/场景/后期）
2. 统一 `PhotoTemplate` 接口，同步更新 PRD 与 AGENT.md 两份文档
3. 拍照页实现模板套用引导：接收 `templateId` → 加载模板 → 显示构图叠图 + 姿势剪影 + 参数引导 + 一键应用
4. 实现用户自定义模板：创建/编辑/删除/复制/导入/导出
5. 实现剪影绘制功能：内置 SVG 库 + 用户绘制 + 用户导入图片
6. 优化拍照相关页面标题栏设计感

### 1.3 范围边界

| 项 | 本次实现 | 后续任务 |
|---|---|---|
| 内置模板数量 | 12 个（8 免费 + 4 付费） | 扩充至 108 个 |
| 取景器 | 保留占位图 | 真实相机取景 |
| 对齐检测 | 仅参考叠图 | 主体框对齐检测 |
| 模板存储 | `uni.setStorageSync`（H5 用 localStorage） | SQLite 持久化 |
| 导入导出 | H5 端 File API | App 端原生存储适配 |
| 剪影绘制 | SVG 矢量绘制 | 笔刷压感、图层 |

---

## 二、整体架构

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│  页面层 (pages/)                                         │
│  capture/index  templates/detail  templates/editor      │
│  templates/index  profile/my-templates                  │
├─────────────────────────────────────────────────────────┤
│  组件层 (components/)                                    │
│  CompositionOverlay  PoseSilhouette  ParamPanel         │
│  SilhouetteEditor                                       │
├─────────────────────────────────────────────────────────┤
│  组合式函数层 (composables/)                             │
│  useTemplate       useTemplateIO                        │
├─────────────────────────────────────────────────────────┤
│  数据层 (data/)                                          │
│  templates/*.ts    silhouettes/index.ts                  │
├─────────────────────────────────────────────────────────┤
│  类型层 (types/)                                         │
│  template.ts                                            │
└─────────────────────────────────────────────────────────┘
```

### 2.2 文件清单

```
lumira-app/src/
├─ types/
│   └─ template.ts                    【新增】统一 PhotoTemplate 接口
├─ data/
│   ├─ templates/
│   │   ├─ index.ts                    【新增】模板注册表 + getTemplateById()
│   │   ├─ sunset-silhouette.ts        【新增】日落逆光剪影
│   │   ├─ cafe-portrait.ts            【新增】咖啡馆人像
│   │   ├─ street-bw.ts                【新增】黑白街拍
│   │   ├─ food-flat-lay.ts            【新增】美食俯拍
│   │   ├─ night-cityscape.ts          【新增】夜景城市
│   │   ├─ golden-landscape.ts         【新增】黄金时刻风光
│   │   ├─ indoor-still-life.ts        【新增】室内静物
│   │   ├─ soft-portrait.ts            【新增】柔光人像
│   │   ├─ neon-portrait.ts            【新增】霓虹人像（付费）
│   │   ├─ macro-flower.ts             【新增】微距花卉（付费）
│   │   ├─ film-vintage.ts             【新增】胶片复古人像（付费）
│   │   └─ urban-architecture.ts       【新增】城市建筑（付费）
│   └─ silhouettes/
│       └─ index.ts                    【新增】内置剪影 SVG 库
├─ composables/
│   ├─ useTemplate.ts                  【新增】模板加载/查询/自定义 CRUD
│   └─ useTemplateIO.ts                【新增】模板导入/导出
├─ components/
│   ├─ CompositionOverlay.vue          【新增】构图叠图
│   ├─ PoseSilhouette.vue              【新增】姿势剪影叠图
│   ├─ ParamPanel.vue                  【新增】底部半屏参数面板
│   └─ SilhouetteEditor.vue            【新增】剪影绘制画布
├─ pages/
│   ├─ capture/index.vue               【重构】拍照页
│   ├─ templates/detail.vue           【改造】读取模板数据 + 传 templateId
│   ├─ templates/index.vue             【改造】读取内置 + 自定义模板
│   ├─ templates/editor.vue            【重构】完整模板创建/编辑流程
│   └─ profile/
│       ├─ my-templates.vue            【新增】我的模板管理页
│       └─ index.vue                   【改造】添加我的模板入口
├─ pages.json                          【修改】注册 my-templates 路由
└─ App.vue                             【微调】标题栏深色适配
```

### 2.3 数据流

```
模板库 index.vue (列表)
  ├─ 点击内置模板 → detail.vue?templateId=xxx
  └─ 点击"我的"分类 → my-templates.vue

模板详情 detail.vue
  └─ "套用此模板拍摄" → capture/index.vue?templateId=xxx

我的模板 my-templates.vue
  ├─ 点击"新建" → editor.vue
  ├─ 点击模板 → editor.vue?templateId=xxx
  ├─ 点击"套用拍摄" → capture/index.vue?templateId=xxx
  ├─ 点击"导出" → useTemplateIO.exportTemplate()
  └─ 点击"导入" → useTemplateIO.importTemplate()

拍照页 capture/index.vue
  ├─ onLoad: useTemplate.loadTemplate(id)
  ├─ CompositionOverlay :template="current"
  ├─ PoseSilhouette :template="current"
  ├─ ParamPill (顶部) :template="current"
  └─ ParamPanel (底部半屏) :template="current"
```

---

## 三、统一 PhotoTemplate 接口

### 3.1 完整接口定义

```typescript
// types/template.ts

/** 模板目标主体类型 */
type Target = 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life'

/** 构图叠图类型 */
type OverlayType = 'rule_of_thirds' | 'golden_ratio' | 'diagonal' | 'grid' | 'leading_lines' | 'center' | 'none'

/** 网格细分类型（当 overlayType 为 grid 时生效） */
type GridType = 'thirds' | 'quarters' | 'golden_spiral'

/** ISO 模式 */
type IsoMode = 'auto' | 'manual'

/** 白平衡预设 */
type WhiteBalance = 'daylight' | 'cloudy' | 'shade' | 'tungsten' | 'fluorescent' | 'custom'

/** 闪光模式 */
type FlashMode = 'off' | 'on' | 'auto' | 'torch'

/** 对焦模式 */
type FocusMode = 'auto' | 'manual' | 'continuous'

/** 镜头建议 */
type LensSuggestion = 'wide' | 'main' | 'telephoto' | 'ultra_wide'

/** 后期 LUT 预设 */
type LutPreset = 'none' | 'cinematic' | 'vintage' | 'bw' | 'warm_film' | 'cool_film' | 'pastel' | 'fuji'

/** 剪影资源类型 */
type SilhouetteType = 'builtin' | 'image' | 'svg'

/** 剪影资源（统一承载内置引用与自定义资源） */
interface SilhouetteResource {
  type: SilhouetteType
  /**
   * type=builtin 时：内置 SVG 库 key
   * type=image 时：base64 data URL
   * type=svg 时：内联 SVG 字符串
   */
  data: string
  filename?: string
  sizeKB?: number
}

interface TemplateMeta {
  id: string
  name: string
  author: string
  version: string
  category: Target
  tags: string[]
  price: number
  cover: string
  description: string
  referenceSource: string
}

interface Composition {
  overlayType: OverlayType
  gridType?: GridType
  subjectFrame: { x: number; y: number; w: number; h: number }
  opacity: number
  aspectRatio: string
  description: string
}

interface Pose {
  silhouette: SilhouetteResource
  position: { x: number; y: number }
  scale: number
  rotation: number
  description: string
}

interface CameraParams {
  exposureCompensation: number
  isoMode: IsoMode
  iso: number
  shutterSpeed: string
  whiteBalance: WhiteBalance
  whiteBalanceK: number
  flashMode: FlashMode
  focusMode: FocusMode
  filterPreset: string
  lensSuggestion: LensSuggestion
}

interface SceneGuide {
  lightDirection: string
  shootingDistance: string
  background: string
  props: string[]
  bestTime: string
  tips: string[]
}

interface PostProcess {
  cropRatio: string
  color: {
    brightness: number
    contrast: number
    saturation: number
    temperature: number
    tint: number
  }
  smoothStrength: number
  sharpen: number
  vignette: number
  grain: number
  lut: LutPreset
}

interface PhotoTemplate {
  meta: TemplateMeta
  composition: Composition
  pose: Pose
  camera: CameraParams
  sceneGuide: SceneGuide
  postProcess: PostProcess
}
```

### 3.2 与 PRD / AGENT.md 对齐说明

| 字段 | PRD 来源 | AGENT.md 来源 | 统一后 |
|---|---|---|---|
| `composition.overlayType` | ✅ | ❌（用 `guideLines`） | 采用 PRD 枚举 + 扩展 |
| `composition.subjectFrame` | ✅ `{x,y,w,h}` | ❌ | 采用 PRD |
| `composition.opacity` | ✅ | ❌ | 采用 PRD |
| `composition.gridType` | ❌ | ✅ | 融合：`thirds\|quarters\|golden_spiral` |
| `composition.aspectRatio` | ❌ | ✅ `aspectRatios` | 采用 AGENT.md（改单数） |
| `pose.silhouette` | ❌ `silhouetteUrl` | ✅ | **重新设计**：`SilhouetteResource` 支持 builtin/image/svg |
| `pose.position/scale/rotation` | ✅ | ❌ | 采用 PRD |
| `camera.*` | ✅ 完整 | ✅ 部分 | 取并集 |
| `sceneGuide.*` | ✅ 完整 | ✅ 部分 | 取并集 |
| `postProcess.*` | ✅ 完整 | ✅ 部分 | 取并集 |
| `meta.referenceSource` | ❌ | ❌ | **新增**：记录参数参考来源 |

### 3.3 剪影资源类型处理策略

| 类型 | `data` 内容 | 渲染方式 | 模板体积 | 适用场景 |
|---|---|---|---|---|
| `builtin` | SVG 库 key | 从内置库查找并渲染 | 极小 | 系统内置 12 个模板 |
| `image` | base64 data URL | `<image>` 标签渲染 | 大（几十 KB） | 用户导入 PNG 剪影图 |
| `svg` | 内联 SVG 字符串 | `v-html` 渲染 | 小（几 KB） | 用户绘制后保存 |

### 3.4 模板导入导出的资源打包策略

导出的 `.pptpl` 文件是**完全自包含**的 JSON，不依赖外部资源文件：

- `builtin` 类型：`data` 仅含 key 字符串（依赖目标系统的内置 SVG 库）
- `image` 类型：`data` 含完整 base64，自包含
- `svg` 类型：`data` 含完整 SVG 字符串，自包含

导入时校验：
- `builtin` 类型：校验内置 SVG 库中是否存在该 key，找不到时降级为 `none`
- `image`/`svg` 类型：`data` 自包含，直接可用

---

## 四、12 个内置模板清单

### 4.1 模板清单总览

| # | ID | 名称 | 分类 | 价格 | 构图类型 | 剪影 ID | 参数参考来源 |
|---|---|---|---|---|---|---|---|
| 1 | sunset_silhouette | 日落逆光剪影 | portrait | 免费 | rule_of_thirds | standing-profile | Pexels #12345；Photzy 逆光人像指南 |
| 2 | cafe_portrait | 咖啡馆人像 | portrait | 免费 | center | sitting-cafe | Unsplash #67890 |
| 3 | street_bw | 黑白街拍 | street | 免费 | leading_lines | walking-street | Magnum 街拍作品 |
| 4 | food_flat_lay | 美食俯拍 | food | 免费 | grid | food-overhead | The Bite Shot 教程 |
| 5 | night_cityscape | 夜景城市 | night | 免费 | rule_of_thirds | none | 城市夜景摄影集 |
| 6 | golden_landscape | 黄金时刻风光 | landscape | 免费 | golden_ratio | none | 500px 风光精选 |
| 7 | indoor_still_life | 室内静物 | still-life | 免费 | grid | still-life-table | 静物摄影教程 |
| 8 | soft_portrait | 柔光人像 | portrait | 免费 | center | soft-portrait | 人像摄影工作室 |
| 9 | neon_portrait | 霓虹人像 | portrait | 付费 ¥3 | leading_lines | neon-pose | 500px Neon Portrait 专题 |
| 10 | macro_flower | 微距花卉 | macro | 付费 ¥3 | center | macro-flower | 微距摄影教程 |
| 11 | film_vintage | 胶片复古人像 | portrait | 付费 ¥3 | rule_of_thirds | vintage-portrait | 胶片摄影作品 |
| 12 | urban_architecture | 城市建筑 | landscape | 付费 ¥3 | diagonal | none | 建筑摄影作品集 |

### 4.2 内置剪影 SVG 库 key 预设

| silhouetteId | 描述 |
|---|---|
| `standing-profile` | 站立侧身 |
| `sitting-cafe` | 坐姿咖啡馆 |
| `walking-street` | 行走街拍 |
| `food-overhead` | 俯拍美食手势 |
| `cityscape-tripod` | 城市风光三脚架 |
| `landscape-wide` | 风光广角 |
| `still-life-table` | 静物台面 |
| `soft-portrait` | 柔光半身 |
| `neon-pose` | 霓虹姿势 |
| `macro-flower` | 微距手持 |
| `vintage-portrait` | 复古人像 |
| `none` | 无姿势（风光/夜景等） |

### 4.3 代表性模板完整参数示例

#### 模板 1：日落逆光剪影（sunset_silhouette）

```typescript
{
  meta: {
    id: 'sunset_silhouette',
    name: '日落逆光剪影',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    tags: ['逆光', '剪影', '黄昏', '人像'],
    price: 0,
    cover: 'https://picsum.photos/seed/sunset-silhouette/600/800',
    description: '日落时分逆光拍摄人像剪影，突出轮廓与氛围',
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.33, y: 0.4, w: 0.34, h: 0.5 },
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '人物置于左侧三分线交点，剪影轮廓清晰，上方留白展示天空'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'standing-profile' },
    position: { x: 0.35, y: 0.55 },
    scale: 1.0,
    rotation: 0,
    description: '模特侧身站立，背对镜头，面朝夕阳方向，手臂自然下垂'
  },
  camera: {
    exposureCompensation: -0.7,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    filterPreset: 'none',
    lensSuggestion: 'telephoto'
  },
  sceneGuide: {
    lightDirection: '逆光 180°（太阳位于模特正后方）',
    shootingDistance: '3-5m',
    background: '开阔天空，地平线低于模特头部',
    props: ['三脚架（可选）', '反光板（补面部光）'],
    bestTime: '日落前 30 分钟（黄金时刻末段）',
    tips: [
      '对焦点选天空中等亮度区域锁定曝光',
      '确保模特轮廓无重叠，头部与天空分离',
      '可降低 EV 制造更深剪影',
      '拍摄 RAW 便于后期恢复天空色彩'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: { brightness: -5, contrast: 25, saturation: -10, temperature: 15, tint: 5 },
    smoothStrength: 0,
    sharpen: 20,
    vignette: 30,
    grain: 10,
    lut: 'cinematic'
  }
}
```

#### 模板 4：美食俯拍（food_flat_lay）

```typescript
{
  meta: {
    id: 'food_flat_lay',
    name: '美食俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    tags: ['美食', '俯拍', 'flat-lay', '静物'],
    price: 0,
    cover: 'https://picsum.photos/seed/food-flat-lay/600/800',
    description: '90 度俯拍美食 flat-lay，突出摆盘与桌面构成',
    referenceSource: '样片 EXIF: 食物摄影教程；参数参考 YouTube 频道 The Bite Shot'
  },
  composition: {
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: { x: 0.25, y: 0.25, w: 0.5, h: 0.5 },
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '主菜置于画面中心或三分线交点，餐具沿对角线摆放'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'none' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，仅示意手部可辅助摆放餐具'
  },
  camera: {
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '侧光 45°（窗户自然光最佳）',
    shootingDistance: '0.5-1m（俯拍正上方）',
    background: '哑光桌面 / 木板 / 亚麻布',
    props: ['餐具', '餐巾', '新鲜食材', '小道具（花朵、杂志）'],
    bestTime: '白天（自然光充足的窗边）',
    tips: [
      '手机与桌面保持平行，避免透视畸变',
      '使用 2× 镜头减少广角变形',
      '主菜与配菜形成色彩对比',
      '留白区域放小道具增加层次'
    ]
  },
  postProcess: {
    cropRatio: '1:1',
    color: { brightness: 10, contrast: 15, saturation: 20, temperature: 10, tint: 0 },
    smoothStrength: 0,
    sharpen: 30,
    vignette: 0,
    grain: 0,
    lut: 'none'
  }
}
```

#### 模板 9：霓虹人像（neon_portrait，付费）

```typescript
{
  meta: {
    id: 'neon_portrait',
    name: '霓虹人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    tags: ['霓虹', '夜景人像', '赛博朋克', '城市'],
    price: 3,
    cover: 'https://picsum.photos/seed/neon-portrait/600/800',
    description: '利用城市霓虹灯光拍摄赛博朋克风格人像',
    referenceSource: '样片 EXIF: 赛博朋克人像作品集；参数参考 500px Neon Portrait 专题'
  },
  composition: {
    overlayType: 'leading_lines',
    subjectFrame: { x: 0.4, y: 0.3, w: 0.25, h: 0.6 },
    opacity: 0.45,
    aspectRatio: '9:16',
    description: '人物置于画面右侧，左侧霓虹招牌引导线指向人物'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'neon-pose' },
    position: { x: 0.6, y: 0.5 },
    scale: 0.9,
    rotation: -5,
    description: '模特微侧身，面部朝向霓虹光源，手部可触碰面部或举起'
  },
  camera: {
    exposureCompensation: -0.3,
    isoMode: 'manual',
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'tungsten',
    whiteBalanceK: 3200,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '侧光 90°（霓虹灯作为主光源）',
    shootingDistance: '1.5-2m',
    background: '霓虹招牌 / 广告灯箱 / 反光玻璃幕墙',
    props: ['霓虹灯环境', '湿润地面（雨后或洒水制造反射）'],
    bestTime: '夜晚 20:00-23:00（霓虹灯最亮时段）',
    tips: [
      '利用霓虹灯色彩渲染面部',
      '面部可部分入阴影营造神秘感',
      '寻找湿润地面制造倒影',
      '低角度仰拍增强人物气场'
    ]
  },
  postProcess: {
    cropRatio: '9:16',
    color: { brightness: -10, contrast: 30, saturation: 25, temperature: -15, tint: -10 },
    smoothStrength: 20,
    sharpen: 15,
    vignette: 25,
    grain: 15,
    lut: 'cool_film'
  }
}
```

> 其余 9 个模板（cafe_portrait、street_bw、night_cityscape、golden_landscape、indoor_still_life、soft_portrait、macro_flower、film_vintage、urban_architecture）按相同结构定义，参数参考真实样片 EXIF 与摄影常识生成。完整数据在实现阶段编写。

---

## 五、组件设计

### 5.1 CompositionOverlay.vue（构图叠图）

**职责**：根据 `Composition` 配置渲染构图叠图（三分法/黄金比例/对角线/网格/引导线/中心十字）+ 主体建议框。

**Props**：
- `composition: Composition` - 构图配置
- `overlayOpacityOverride?: number` - 外部覆盖透明度

**特点**：
- 纯 CSS 绘制，无图片资源依赖
- 支持 6 种构图类型动态切换
- 主体建议框用虚线表示，金色高亮
- 透明度可外部覆盖（如面板展开时降低）

**渲染逻辑**：
- `rule_of_thirds`: 2 条竖线 + 2 条横线，间距 33.33%
- `golden_ratio`: 2 条竖线 + 2 条横线，间距 38.2%/61.8%
- `diagonal`: 2 条对角线
- `grid`: 根据 `gridType` 渲染 thirds/quarters/golden_spiral
- `leading_lines`: 2 条引导线（从底部两角指向中心）
- `center`: 1 条竖线 + 1 条横线，居中

### 5.2 PoseSilhouette.vue（姿势剪影叠图）

**职责**：根据 `Pose` 配置渲染剪影叠图。

**Props**：
- `pose: Pose` - 姿势配置
- `containerSize: { w: number; h: number }` - 容器尺寸

**渲染逻辑**：
- `builtin` 类型：从 `BUILTIN_SILHOUETTES` 查找 SVG 字符串，`v-html` 渲染
- `image` 类型：`<image :src="silhouette.data">` 渲染 base64 图片
- `svg` 类型：`v-html` 渲染内联 SVG 字符串
- `none` 类型：不渲染任何内容

**样式**：
- 位置：`left/top` 归一化坐标转百分比
- 变换：`translate(-50%, -50%) scale(${scale}) rotate(${rotation})`
- 透明度：0.55（不遮挡取景器实际画面）

### 5.3 ParamPanel.vue（底部半屏参数面板）

**职责**：展示模板所有参数，支持一键应用与微调。

**Props**：
- `template: PhotoTemplate` - 完整模板对象
- `visible: boolean` - 是否展开
- `applied: boolean` - 是否已应用

**Emits**：
- `close` - 关闭面板
- `apply` - 一键应用模板参数
- `update:opacity` - 构图透明度变化

**结构**：
- 拖拽手柄（点击关闭）
- 模板概要（名称 + 简介）
- Tab 切换（5 个 Tab）：相机 / 构图 / 场景 / 姿势 / 后期
- 滚动内容区（每个 Tab 展示对应模块参数）
- 底部"一键应用模板参数"按钮

**Tab 内容**：
- **相机 Tab**：EV/ISO/快门/白平衡/闪光/对焦/镜头
- **构图 Tab**：构图类型/宽高比/叠图透明度滑块/构图说明
- **场景 Tab**：光线/距离/背景/最佳时间/道具标签/拍摄贴士
- **姿势 Tab**：剪影预览/描述/位置/缩放
- **后期 Tab**：裁剪比/LUT/调色五项滑块/磨皮/锐化/暗角/颗粒

### 5.4 SilhouetteEditor.vue（剪影绘制画布）

**职责**：提供 SVG 矢量绘制工具，用户可绘制人物轮廓剪影。

**Props**：
- `visible: boolean` - 是否显示

**Emits**：
- `close` - 关闭绘制器
- `complete` - 绘制完成，返回 SVG 字符串

**工具**：
- 画笔：黑色描边，可调粗细（2-30px）
- 橡皮：擦除路径
- 撤销/重做：维护路径栈
- 清空：清空所有路径

**辅助功能**：
- 人体比例参考线（头 12.5% / 腰 37.5% / 膝 62.5%）
- 可选参考图叠加（上传图片半透明显示，便于临摹）

**绘制原理**：
- 使用 SVG `<path>` 元素记录绘制路径
- `touchstart` 开始新路径 `M x y`
- `touchmove` 追加 `L x y` 到当前路径
- `touchend` 结束当前路径，推入路径栈
- 完成时合并所有路径为完整 SVG 字符串

**坐标系**：
- SVG viewBox: `0 0 300 480`（3:4.8 接近人像比例）
- 触摸坐标需转换为 viewBox 坐标

---

## 六、页面设计

### 6.1 拍照页（capture/index.vue 重构）

**职责**：接收 `templateId`，加载模板，渲染构图叠图 + 姿势剪影 + 参数引导 + 一键应用。

**URL 参数**：`?templateId=xxx`

**布局**：
1. **顶部沉浸式深色标题栏**：返回按钮 + 模板名称 + 场景指南入口 + 闪光灯切换
2. **取景器**（占位图）：背景图 + 半透明遮罩
3. **构图叠图**：`CompositionOverlay` 组件
4. **姿势剪影叠图**：`PoseSilhouette` 组件
5. **顶部参数 pill 栏**：EV pill + WB pill + 一键应用 pill
6. **底部控制区**：
   - 快门行：上次照片缩略图 + 快门按钮 + 翻转镜头按钮
   - 模板快速切换横滑：最近使用的模板缩略图
7. **半屏参数面板**：`ParamPanel` 组件（可展开/收起）

**标题栏设计**（沉浸式深色，不走通用 `lumira-nav`）：
- 完全透明背景
- 顶部渐变遮罩（`linear-gradient(rgba(0,0,0,0.4), transparent)`）保证图标可见性
- 返回按钮：64rpx 圆形，半透明黑色背景 + 毛玻璃模糊
- 标题：白色 32rpx，带 `text-shadow` 增强可读性
- 操作按钮：64rpx 圆形，与返回按钮统一样式

**交互流程**：
1. 进入页面：onLoad 接收 templateId → 加载模板 → 渲染叠图与剪影 → 参数 pill 显示建议值（未应用态）
2. 点击顶部"一键应用" pill：`applied = true`，pill 高亮变为"已应用"，`showToast` 反馈
3. 点击参数 pill（EV/WB）：展开半屏面板，定位到对应 Tab
4. 面板中调节滑块：构图透明度实时反馈到叠图，后期参数可微调
5. 切换底部模板横滑：加载新模板，`applied` 重置，叠图与参数更新
6. 点击快门：跳转 preview 页（保留当前模板信息）

### 6.2 模板详情页（templates/detail.vue 改造）

**改造点**：
- 从 URL query 读取 `templateId`
- 使用 `useTemplate.loadTemplate(id)` 加载模板数据
- 替换硬编码内容为模板数据驱动渲染
- "套用此模板拍摄"按钮跳转时传 `templateId`：`/pages/capture/index?templateId=${id}`

### 6.3 模板库列表页（templates/index.vue 改造）

**改造点**：
- 分类 pill 新增"我的"选项
- "我的"分类显示用户自定义模板列表
- 列表数据从 `useTemplate.getAllTemplates()` 读取（内置 + 自定义）
- 新增"导入模板"与"新建模板"操作入口

### 6.4 模板编辑器页（templates/editor.vue 重构）

**职责**：完整的模板创建/编辑流程。

**URL 参数**：`?templateId=xxx`（编辑模式，无参数为新建模式）

**步骤区**（6 个）：
1. **模板信息**：名称/分类/标签/简介
2. **构图叠图**：构图类型/宽高比/透明度/主体框坐标
3. **姿势剪影**：
   - 来源选择：内置库 / 导入图片 / 绘制剪影
   - 内置库：横向滚动的剪影缩略图选择
   - 导入图片：`uni.chooseImage` → 读取为 base64
   - 绘制剪影：打开 `SilhouetteEditor` 弹层
   - 位置/缩放/旋转滑块/描述
4. **相机参数**：EV/ISO/快门/白平衡/闪光/对焦/镜头
5. **场景指南**：光线/距离/背景/最佳时间/道具/贴士
6. **后期参数**：裁剪比/LUT/调色五项/磨皮/锐化/暗角/颗粒

**底部操作**：
- 预览效果（跳转 detail.vue 预览）
- 保存模板（`saveCustomTemplate`）
- 导出 .pptpl（编辑模式下，`exportTemplate`）

**剪影三种来源处理**：
- `builtin`：`silhouette = { type: 'builtin', data: key }`
- `image`：`uni.chooseImage` → `uni.getFileSystemManager().readFile` 读为 base64 → `silhouette = { type: 'image', data: base64URL, filename, sizeKB }`
- `svg`：打开 `SilhouetteEditor` → `@complete` 事件接收 SVG 字符串 → `silhouette = { type: 'svg', data: svgString }`

### 6.5 我的模板管理页（profile/my-templates.vue）

**职责**：管理用户自定义模板，支持创建/编辑/删除/复制/导入/导出/套用拍摄。

**布局**：
1. **标题栏**：通用 `lumira-nav`（透明+滚动毛玻璃）
2. **统计栏**：自定义模板数 / 已使用次数 / 收藏数
3. **操作栏**：导入模板 / 新建模板
4. **筛选栏**：全部 / 人像 / 风光 / 美食 / 其他
5. **列表**：卡片式列表（封面 + 名称 + 分类标签 + 标签 + 参数摘要 + 操作按钮）
6. **空状态**：引导创建第一个模板
7. **长按操作面板**：编辑 / 套用拍摄 / 复制 / 导出 .pptpl / 删除

**操作流程**：
- 点击"新建" → `editor.vue`
- 点击模板卡片 → `editor.vue?templateId=xxx`
- 点击"套用拍摄" → `capture/index.vue?templateId=xxx`
- 点击"导出" → `useTemplateIO.exportTemplate(tpl)` → 浏览器下载 .pptpl 文件
- 点击"导入" → `useTemplateIO.importTemplate()` → 选择文件 → 解析 → 保存
- 长按模板 → 显示操作面板
- 删除 → `showModal` 二次确认 → `deleteCustomTemplate(id)`

### 6.6 个人页改造（profile/index.vue）

在个人页菜单中添加"我的模板"入口：

```vue
<view class="menu-row" @click="goMyTemplates">
  <text class="ph ph-stack menu-icon"></text>
  <text class="menu-label">我的模板</text>
  <text class="menu-count">{{ customCount }}</text>
  <text class="ph ph-caret-right menu-arrow"></text>
</view>
```

### 6.7 路由注册

```json
// pages.json 新增
{
  "path": "pages/profile/my-templates",
  "style": {
    "navigationBarTitleText": "我的模板",
    "navigationStyle": "custom",
    "backgroundColor": "#FAF7F2"
  }
}
```

---

## 七、组合式函数

### 7.1 useTemplate.ts

```typescript
// composables/useTemplate.ts

import { ref } from 'vue'
import { BUILTIN_TEMPLATES, getTemplateById as getBuiltinById } from '@/data/templates'
import type { PhotoTemplate } from '@/types/template'

const CUSTOM_TEMPLATES_KEY = 'lumira_custom_templates'
const RECENT_TEMPLATES_KEY = 'lumira_recent_templates'
const MAX_RECENT = 6

const recentTemplates = ref<PhotoTemplate[]>([])

export function useTemplate() {
  /** 加载模板（内置 + 自定义） */
  function loadTemplate(id: string): PhotoTemplate | null {
    const builtin = getBuiltinById(id)
    if (builtin) return builtin
    const custom = getCustomTemplates().find(t => t.meta.id === id)
    return custom || null
  }

  /** 获取所有模板（内置 + 自定义） */
  function getAllTemplates(): PhotoTemplate[] {
    return [...BUILTIN_TEMPLATES, ...getCustomTemplates()]
  }

  /** 获取免费模板 */
  function getFreeTemplates(): PhotoTemplate[] {
    return BUILTIN_TEMPLATES.filter(t => t.meta.price === 0)
  }

  /** 获取付费模板 */
  function getPaidTemplates(): PhotoTemplate[] {
    return BUILTIN_TEMPLATES.filter(t => t.meta.price > 0)
  }

  /** 获取自定义模板 */
  function getCustomTemplates(): PhotoTemplate[] {
    const raw = uni.getStorageSync(CUSTOM_TEMPLATES_KEY)
    if (!raw) return []
    try {
      return JSON.parse(raw) as PhotoTemplate[]
    } catch {
      return []
    }
  }

  /** 保存自定义模板（新建或更新） */
  function saveCustomTemplate(tpl: PhotoTemplate): void {
    const list = getCustomTemplates()
    const idx = list.findIndex(t => t.meta.id === tpl.meta.id)
    if (idx >= 0) {
      list[idx] = tpl
    } else {
      list.push(tpl)
    }
    uni.setStorageSync(CUSTOM_TEMPLATES_KEY, JSON.stringify(list))
  }

  /** 删除自定义模板 */
  function deleteCustomTemplate(id: string): void {
    const list = getCustomTemplates().filter(t => t.meta.id !== id)
    uni.setStorageSync(CUSTOM_TEMPLATES_KEY, JSON.stringify(list))
  }

  /** 复制自定义模板 */
  function duplicateTemplate(id: string): PhotoTemplate | null {
    const tpl = getCustomTemplates().find(t => t.meta.id === id)
    if (!tpl) return null
    const copy: PhotoTemplate = {
      ...tpl,
      meta: {
        ...tpl.meta,
        id: `${tpl.meta.id}_copy_${Date.now()}`,
        name: `${tpl.meta.name}（副本）`
      }
    }
    saveCustomTemplate(copy)
    return copy
  }

  /** 添加到最近使用 */
  function pushRecent(id: string): void {
    const tpl = loadTemplate(id)
    if (!tpl) return
    const filtered = recentTemplates.value.filter(t => t.meta.id !== id)
    recentTemplates.value = [tpl, ...filtered].slice(0, MAX_RECENT)
    uni.setStorageSync(RECENT_TEMPLATES_KEY, JSON.stringify(
      recentTemplates.value.map(t => t.meta.id)
    ))
  }

  /** 加载最近使用模板 */
  function loadRecent(): void {
    const ids = uni.getStorageSync(RECENT_TEMPLATES_KEY) as string[]
    if (!ids || !Array.isArray(ids)) return
    recentTemplates.value = ids
      .map(id => loadTemplate(id))
      .filter((t): t is PhotoTemplate => t !== null)
      .slice(0, MAX_RECENT)
  }

  return {
    recentTemplates,
    loadTemplate,
    getAllTemplates,
    getFreeTemplates,
    getPaidTemplates,
    getCustomTemplates,
    saveCustomTemplate,
    deleteCustomTemplate,
    duplicateTemplate,
    pushRecent,
    loadRecent
  }
}
```

### 7.2 useTemplateIO.ts

```typescript
// composables/useTemplateIO.ts

import { useTemplate } from './useTemplate'
import { BUILTIN_SILHOUETTES } from '@/data/silhouettes'
import type { PhotoTemplate } from '@/types/template'

export function useTemplateIO() {
  const { saveCustomTemplate, getCustomTemplates } = useTemplate()

  /** 导出模板为 .pptpl JSON 文件 */
  async function exportTemplate(tpl: PhotoTemplate): Promise<void> {
    const json = JSON.stringify(tpl, null, 2)
    // #ifdef H5
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${tpl.meta.id}.pptpl`
    a.click()
    URL.revokeObjectURL(url)
    uni.showToast({ title: '已导出 .pptpl 文件', icon: 'none' })
    // #endif
    // #ifndef H5
    uni.showToast({ title: '当前环境暂不支持导出', icon: 'none' })
    // #endif
  }

  /** 导入 .pptpl 文件并解析 */
  async function importTemplate(): Promise<PhotoTemplate | null> {
    return new Promise((resolve) => {
      // #ifdef H5
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = '.pptpl,.json'
      input.onchange = async (e: any) => {
        const file = e.target.files[0]
        if (!file) return resolve(null)
        const text = await file.text()
        try {
          const tpl = parseTemplate(text)
          // 若 ID 与已有模板冲突，自动追加后缀
          const existing = [...getCustomTemplates()]
          if (existing.some(t => t.meta.id === tpl.meta.id)) {
            tpl.meta.id = `${tpl.meta.id}_imported_${Date.now()}`
            tpl.meta.name = `${tpl.meta.name}（导入）`
          }
          saveCustomTemplate(tpl)
          uni.showToast({ title: '模板导入成功', icon: 'success' })
          resolve(tpl)
        } catch (err) {
          uni.showToast({ title: '模板文件格式错误', icon: 'none' })
          resolve(null)
        }
      }
      input.click()
      // #endif
      // #ifndef H5
      uni.showToast({ title: '当前环境暂不支持导入', icon: 'none' })
      resolve(null)
      // #endif
    })
  }

  /** 解析模板 JSON（含校验与降级） */
  function parseTemplate(json: string): PhotoTemplate {
    const tpl = JSON.parse(json) as PhotoTemplate
    // 校验必要字段
    if (!tpl.meta?.id || !tpl.meta?.name) {
      throw new Error('模板缺少必要字段（meta.id 或 meta.name）')
    }
    if (!tpl.composition || !tpl.camera || !tpl.postProcess) {
      throw new Error('模板缺少核心模块（composition/camera/postProcess）')
    }
    // 校验内置剪影是否存在
    if (tpl.pose?.silhouette?.type === 'builtin') {
      if (!BUILTIN_SILHOUETTES[tpl.pose.silhouette.data]) {
        tpl.pose.silhouette.data = 'none'
      }
    }
    return tpl
  }

  return {
    exportTemplate,
    importTemplate,
    parseTemplate
  }
}
```

---

## 八、标题栏优化（拍照相关页面）

### 8.1 通用 `.lumira-nav`（已在上一阶段完成）

- 默认透明背景
- 滚动超过阈值后添加 `.scrolled` 类，触发毛玻璃模糊
- 标题字号 38rpx，字间距 0.04em
- 返回按钮 64rpx 圆形新拟态凸起设计
- 过渡动画 cubic-bezier(0.16,1,0.3,1)

### 8.2 拍照页深色沉浸式标题栏

拍照页背景为深色，不走通用 `lumira-nav`，采用自定义实现：

- 完全透明背景
- 顶部渐变遮罩（`linear-gradient(rgba(0,0,0,0.4), transparent)`）保证图标可见性
- 返回按钮：64rpx 圆形，半透明黑色背景 + 毛玻璃模糊
- 标题：白色 32rpx，带 `text-shadow` 增强可读性
- 副标题：模板分类 + 宽高比，22rpx 半透明白色
- 操作按钮：64rpx 圆形，与返回按钮统一样式

### 8.3 各页面标题栏差异

| 页面 | 标题栏样式 | 设计要点 |
|---|---|---|
| 模板库 index.vue | 通用 lumira-nav | 保持现状 |
| 模板详情 detail.vue | 通用 lumira-nav | 滚动时增加微投影 |
| 模板编辑器 editor.vue | 通用 lumira-nav | 滚动时增强模糊 |
| 模板解锁 unlock.vue | 通用 lumira-nav | 保持现状 |
| 我的模板 my-templates.vue | 通用 lumira-nav | 左右留白略增 |
| 拍照页 capture/index.vue | 自定义深色沉浸式 | 顶部渐变遮罩+圆形按钮 |
| 拍照预览 preview.vue | 自定义深色沉浸式 | 沉浸式展示照片 |

---

## 九、文档同步更新

### 9.1 PRD 更新

更新 `docs/superpowers/specs/2026-07-03-lumira-prd.md` 第三章：
- 将 `.pptpl` JSON 格式更新为统一后的 `PhotoTemplate` 接口
- `pose.silhouetteUrl` 改为 `pose.silhouette: SilhouetteResource`
- 新增 `meta.referenceSource` 字段
- 补充 `composition.gridType` 字段

### 9.2 AGENT.md 更新

更新 `AGENT.md` 第五章：
- 将 `PhotoTemplate` TS 接口更新为统一后的版本
- `pose.silhouetteUrl` 改为 `pose.silhouette: SilhouetteResource`
- `composition.guideLines`/`ruleOfThirds` 合并为 `overlayType` + `gridType`
- 新增 `meta.referenceSource` 字段
- 同步 `SilhouetteResource` 类型定义

---

## 十、验收标准

### 10.1 模板系统

- [ ] 12 个内置模板数据完整（含所有字段）
- [ ] 模板详情页从模板数据对象读取内容渲染
- [ ] 模板列表页显示内置模板（8 免费 + 4 付费标记）
- [ ] `types/template.ts` 接口与 PRD、AGENT.md 一致

### 10.2 拍照引导

- [ ] 拍照页接收 URL query 的 `templateId`
- [ ] 加载模板后渲染对应的构图叠图
- [ ] 加载模板后渲染对应的姿势剪影（builtin 类型）
- [ ] 顶部参数 pill 显示模板建议参数
- [ ] 点击"一键应用" pill 后状态变化（已应用高亮）
- [ ] 点击参数 pill 展开半屏面板，显示对应 Tab
- [ ] 底部模板横滑切换时叠图与参数更新
- [ ] 构图透明度滑块实时反馈到叠图

### 10.3 自定义模板

- [ ] 模板编辑器支持完整 6 步骤流程
- [ ] 剪影三来源（内置库/导入图片/绘制）均可工作
- [ ] 保存的自定义模板出现在"我的模板"列表
- [ ] 编辑模式可加载已有模板数据
- [ ] 删除模板有二次确认
- [ ] 复制模板生成副本

### 10.4 剪影绘制

- [ ] 画笔工具可绘制路径
- [ ] 橡皮工具可擦除
- [ ] 撤销/重做功能正常
- [ ] 清空功能正常
- [ ] 人体比例参考线显示
- [ ] 完成后导出为 SVG 字符串

### 10.5 导入导出

- [ ] 导出生成 `.pptpl` 文件（JSON 格式）
- [ ] 导出的文件自包含（image/svg 类型含完整资源）
- [ ] 导入 `.pptpl` 文件后模板出现在列表
- [ ] 导入时内置剪影 key 校验与降级正常
- [ ] ID 冲突时自动追加后缀

### 10.6 标题栏

- [ ] 拍照页标题栏深色沉浸式，不遮挡取景器
- [ ] 拍照页标题栏图标在深色背景上清晰可见
- [ ] 其他页面标题栏保持通用 lumira-nav 样式
- [ ] 滚动感知毛玻璃效果正常

---

## 十一、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| SVG 剪影绘制在移动端触摸精度不足 | 用户绘制困难 | 提供人体比例参考线辅助；支持参考图临摹 |
| base64 图片导致模板体积过大 | 存储与导出文件膨胀 | 提示用户剪影图建议 < 100KB；导出时压缩 |
| H5 File API 在非 H5 端不可用 | App 端无法导入导出 | 条件编译，非 H5 端提示"暂不支持" |
| `uni.setStorageSync` 存储限制 | 自定义模板过多时溢出 | 单个模板 > 500KB 时警告；后续迁移 SQLite |
| 模板字段在后续迭代中变更 | 导入旧模板兼容性 | `meta.version` 字段记录版本，导入时校验 |

---

## 十二、后续任务（不在本次范围）

1. 真实相机取景器（替换占位图）
2. 主体框对齐检测
3. 扩充内置模板至 108 个
4. SQLite 持久化存储
5. App 端原生文件导入导出
6. 剪影绘制笔刷压感、图层
7. 模板分享社区
8. 模板评分与评论
