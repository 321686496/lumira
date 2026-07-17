# 如画 V2 综合增强设计

- 日期：2026-07-17
- 范围：如画 App（uni-app Vue 3）
- 状态：已批准，待实施

## 1. 背景

用户反馈 11 项问题，覆盖核心 bug、跨平台对等、场景/模板/拍摄页/照片墙模块增强。

### 1.1 强约束

**所有在 H5 生效的功能必须同步生效到 Android 与 iOS。** App-Plus 平台不得降级为"仅元数据"或"仅 UI 提示"。

### 1.2 需求清单

| # | 需求 | 优先级 |
|---|------|--------|
| 1 | Android APK 顶部/底部/左右边界拖动弹动效果 → 移除 | 高 |
| 2 | 首页场景推荐卡片简化：去掉氛围内容，仅展示描述 | 中 |
| 3 | 场景详情"加入组合"按钮改为跳转组合编辑器；"使用此场景拍摄"必须自动套用滤镜；场景引用的滤镜必须是系统中存在的 | 高 |
| 4 | 场景模块独立"场景库"页面 | 中 |
| 5 | 场景详情与模板详情页支持添加/显示标签 | 中 |
| 6 | 模板 tab 仅展示推荐模板，"查看更多"承载完整列表 | 中 |
| 7 | 今日拍摄小贴士基于用户近期拍照方式/风格生成 | 中 |
| 8 | 拍摄页：全屏/非全屏切换；底部操作栏可折叠+模板/场景横滑；顶部参数 pill 椭圆问题修复；小数参数保留 2 位 | 高 |
| 9 | ISO 参数必须有效果 | 高 |
| 10 | 后期参数调整必须真实生效（跨平台对等） | 高 |
| 11 | 拍照后照片进入照片墙；按场景分类；无场景时归"未分类"；后期可在照片墙为照片归类 | 高 |

## 2. 核心架构决策

### 2.1 跨平台滤镜烘焙统一化

**根因**：`useCamera.ts` 的 `captureAppPlus()` 直接返回 `takePhoto` 的临时路径，未调用 `bakePhoto()`，导致 App-Plus 拍照无任何后期效果。

**方案**：

1. `captureAppPlus(camera, post)` 改造为完整烘焙流程：
   - `takePhoto` 取临时路径
   - `uni.getImageInfo` 获取宽高
   - `uni.createOffscreenCanvas({ type: '2d', width, height })` 创建离屏画布
   - `canvas.createImage()` + `img.src = tempPath` 加载图片
   - 改造 `bakePhoto` 为 `bakePhotoForCanvas(canvas, ctx, img, w, h, camera, post)` 公共核心函数
   - H5 与 App-Plus 共用同一烘焙逻辑
2. `ctx.filter` 在 App-Plus WebView 可能不支持 → 备用：所有 CSS filter 效果增加像素级实现 `applyFilterFromPost(ctx, w, h, camera, post)`，当 `ctx.filter` 设置失败时降级
3. `<camera>` 原生预览无法应用 CSS filter → 在取景器上叠加 `<view class="filter-overlay">`，使用 `backdrop-filter: var(--current-filter)` 模拟实时效果
4. 拍照烘焙仍走完整像素级处理，确保最终照片含所有效果

### 2.2 ISO 跨平台对等

- **H5**：`MediaTrackConstraints.advanced: [{ iso: Number(value) }]` 应用到 video track（不支持时静默忽略）
- **App-Plus**：ISO 通过"实时 CSS filter 近似"实现
  - ISO > 基线 200 时：
    - `brightness += (iso - 200) / 6400 * 0.3`（最高 +0.3）
    - `grainStrength += (iso - 200) / 6400 * 0.4`（最高 +0.4）
  - `buildCssFilter` / `buildCanvasFilter` 同步纳入 ISO 公式
- ISO 值同时写入 `LocalPhoto.metadata.iso`，供 EXIF 卡片展示

### 2.3 滤镜合法性校验

`SYSTEM_FILTERS` 为常量 Record，不允许动态扩展。改造：

```typescript
// utils/filterRecipe.ts
const customFilters: Record<string, string> = {}

export function registerCustomFilter(name: string, filterStr: string): void
export function getFilterString(name: SystemFilter | string): string
export function isFilterRegistered(name: string): boolean
```

**简化方案**：scene-manage 自定义场景的 systemFilter 选择改为从 `getSystemFilterOptions()` 下拉选，**不允许创建新名称**。`scene-detail` 渲染前调用 `isFilterRegistered` 校验，未注册则降级为 `'none'` 并提示。

## 3. 详细设计

### 3.1 模块 D：核心 bug 修复（最高优先级）

#### 3.1.1 useCamera.ts 改造

```typescript
async function captureAppPlus(camera, post): Promise<BakeResult> {
  // 1. takePhoto
  const tempPath = await takePhotoAsync()
  // 2. getImageInfo
  const info = await getImageInfoAsync(tempPath)
  // 3. createOffscreenCanvas
  const canvas = uni.createOffscreenCanvas({ type: '2d', width: info.width, height: info.height })
  const ctx = canvas.getContext('2d')
  // 4. loadImage
  const img = canvas.createImage()
  await loadImageAsync(img, tempPath)
  // 5. bake
  const dataUrl = bakePhotoForCanvas(canvas, ctx, img, info.width, info.height, camera, post)
  // 6. return
  return { dataUrl, width: info.width, height: info.height, size: estimateSize(dataUrl) }
}
```

#### 3.1.2 captureBake.ts 重构

抽取公共函数 `bakePhotoForCanvas(canvas, ctx, img, w, h, camera, post)`：

```typescript
export function bakePhotoForCanvas(
  canvas: any, ctx: any, img: any,
  w: number, h: number,
  camera: Partial<CameraParams>, post: Partial<PostProcess>,
  quality = 0.92
): string {
  // 1. CSS filter（含 ISO 修正）
  const filterStr = buildCanvasFilter(camera, post)
  try { ctx.filter = filterStr } catch { /* 不支持则降级像素级 */ }
  
  // 2. drawImage
  ctx.drawImage(img, 0, 0, w, h)
  ctx.filter = 'none'
  
  // 3. 像素级处理（vignette/grain/sharpen/smooth + ISO 修正）
  applyPostProcess(ctx, w, h, camera, post)
  
  // 4. toDataURL
  return canvas.toDataURL('image/jpeg', quality)
}
```

H5 的 `bakePhoto()` 改为调用 `bakePhotoForCanvas` 的封装。

#### 3.1.3 filterRecipe.ts 改造

`buildCssFilter(camera, post)` 增加 ISO 公式：

```typescript
export function buildCssFilter(camera, post): string {
  const parts: string[] = []
  // ...现有 EV/WB/color/systemFilter/lut 逻辑
  
  // ISO 近似效果（H5 + App-Plus 统一）
  const iso = camera.iso
  if (iso && iso > 200) {
    const brightnessBoost = (iso - 200) / 6400 * 0.3
    if (brightnessBoost > 0) parts.push(`brightness(${1 + brightnessBoost})`)
  }
  
  return parts.length ? parts.join(' ') : 'none'
}

export function getGrainStrength(post: Partial<PostProcess>, iso?: number): number {
  let strength = /* 现有逻辑 */
  if (iso && iso > 200) {
    strength += (iso - 200) / 6400 * 0.4
  }
  return Math.min(1, strength)
}
```

### 3.2 模块 A：平台与体验层

#### 3.2.1 页面 bounce 移除（需求 1）

**App.vue onLaunch**：

```typescript
// #ifdef APP-PLUS
const currentWebview = plus.webview.currentWebview()
if (currentWebview) {
  currentWebview.setBounce('none')
  currentWebview.setStyle({ bounce: 'none' })
}
// #endif
```

**pages.json 全局**：

```json
{
  "globalStyle": {
    "bounce": "none"
  }
}
```

**App.vue 全局样式**：

```scss
html, body {
  overscroll-behavior: none;
  -webkit-overflow-scrolling: touch;
  overflow-x: hidden;
}
::-webkit-scrollbar { display: none; }
```

#### 3.2.2 拍摄页 UI 优化（需求 8）

##### 全屏切换

新增顶部按钮 `ph-frame-corners` / `ph-frame`，状态 `isFullscreen`：

```scss
.capture-fullscreen .viewfinder {
  position: fixed; inset: 0; z-index: 10;
  border-radius: 0; margin: 0; padding-bottom: 0;
}
.capture-fullscreen .param-pill-bar,
.capture-fullscreen .bottom-action-area {
  position: fixed; z-index: 20;
  background: rgba(0,0,0,0.5); backdrop-filter: blur(12px);
}
```

状态持久化到 `localStorage` key `lumira_capture_fullscreen`。

##### 底部操作栏折叠

新增 `bottomPanelExpanded`，展开时显示模板/场景横滑条：

```html
<view class="bottom-action-area" :class="{ expanded: bottomPanelExpanded }">
  <view class="shutter-row">...</view>
  <view v-if="bottomPanelExpanded" class="expandable-panel">
    <view class="panel-section">
      <text>🎨 模板</text>
      <scroll-view scroll-x>...</scroll-view>
    </view>
    <view class="panel-section">
      <text>📍 场景</text>
      <scroll-view scroll-x>...</scroll-view>
    </view>
  </view>
  <view class="toggle-btn" @click="bottomPanelExpanded = !bottomPanelExpanded">
    <text :class="bottomPanelExpanded ? 'ph-caret-down' : 'ph-caret-up'" />
  </view>
</view>
```

##### 顶部参数 pill 椭圆修复

固定尺寸 + 等宽数字：

```scss
.param-pill {
  width: 88rpx; height: 56rpx;
  padding: 0; border-radius: 28rpx;
  display: flex; align-items: center; justify-content: center;
  font-variant-numeric: tabular-nums;
}
```

显示格式：
- EV: `+0.30` / `-1.50`（2 位小数）
- WB: `5500K`（整数）
- ISO: `ISO 200`

##### ParamPanel slider step

- EV: `step="0.05"`，范围 `-3 ~ +3`
- WB: `step="50"`，范围 `2000 ~ 10000`
- ISO: `step="50"`，范围 `100 ~ 6400`

### 3.3 模块 B：场景模块增强

#### 3.3.1 场景推荐卡片简化（需求 2）

修改 `components/ScenePresetView.vue` 的 `variant="card"`：

- 移除：`vibe`、`tips`、`whereToShoot`、`bestTime`
- 保留：`name`、`description`（2 行省略）、`icon`、`exampleImages[0]`、照片计数 badge

#### 3.3.2 加入组合 → 跳转组合编辑器（需求 3）

**新建文件**：`/pages/shootkit/editor.vue`

```
路径：/pages/shootkit/editor?sceneId=xxx&kitId=xxx（编辑模式可选）
入口：
  - scene-detail.vue 的"加入组合"按钮
  - scene-manage.vue 的 kit tab "新建组合"按钮
```

页面结构：
- 顶部导航：返回 | 新建组合 | 保存
- 组合名称输入
- 绑定场景（只读，从 URL）
- 选择模板（grid 2 列单选）
- 参数覆盖（EV/WB/ISO slider，可选）
- 实时预览
- 保存按钮 → `useShootKit.createKit()` → `navigateBack`

#### 3.3.3 使用此场景拍摄滤镜应用（需求 3）

现有 `goCapture()` 已传 `scenePreset`，capture/index.vue 已应用 `preset.filter.lut/systemFilter`。补充：

- capture 顶部新增"场景滤镜已套用"badge
- 确保 `lut !== 'none'` 时 `buildCssFilter` 生成正确字符串
- 跨平台预览见模块 D

#### 3.3.4 独立场景页（需求 4）

**新建文件**：`/pages/scenes/index.vue`

入口（多入口跳转，不改 tab）：
- 首页"查看全部场景"
- 拍摄页"场景"pill
- 个人中心"场景库"

页面结构：
- 顶部：返回 | 场景库 | 搜索
- 分类 tab：全部 | 室内 | 室外 | 光线 | 情绪
- 场景列表（grid 2 列）：预设 18 + 自定义
- 卡片：缩略图 + 名称 + 标签 + 拍摄数
- 点击 → `/pages/capture/scene-detail?id=xxx`
- 浮动按钮：+ 新建自定义场景

复用 `ScenePresetView` 新增 `variant="list"` 模式。

#### 3.3.5 场景标签 add/display（需求 5）

修改 `pages/capture/scene-detail.vue`：
- 展示 `recommendedTagIds`（预设）或 `tagIds`（自定义）解析为 UserTag
- 预设场景：只读
- 自定义场景：点击"+ 添加标签"弹出 TagSelector sheet
- 保存：`useTagManager.updateSceneTags(sceneId, tagIds)`

修改 `pages/capture/scene-manage.vue` 自定义场景编辑表单：增加 TagSelector 组件。

### 3.4 模块 C：模板模块增强

#### 3.4.1 模板推荐机制（需求 6）

**useTemplate.ts 新增**：

```typescript
export interface TemplateRecommendation {
  template: PhotoTemplate
  reason: string
  score: number
  source: 'recent_used' | 'scene_match' | 'category_match' | 'system_pick'
}

export function getRecommendedTemplates(limit = 6): TemplateRecommendation[]
// 综合多因素加权：
// 1. 近 30 天使用最多的模板（35%）
//    数据源：photos 中 templateId 频次 + recentTemplates
// 2. 当前场景关联模板（25%）
//    数据源：当前选中场景的 recommendedTagIds 与模板 tagIds 重合度
// 3. 同分类未使用模板（20%）
//    数据源：用户最常用分类的未使用模板
// 4. 系统精选（20%）
//    数据源：根据时间段匹配适合场景的模板
```

#### 3.4.2 模板 tab 页改造

`pages/templates/index.vue` 改为推荐结构：

```
┌─────────────────────────────────┐
│ Hero 区：今日为你推荐            │
│ [推荐模板横向滚动 1-3]          │
│ 推荐理由：基于你最近常拍人像...   │
├─────────────────────────────────┤
│ 📊 你的拍摄偏好                  │
│ 最常用分类：人像 (42%)           │
│ 常用参数：EV +0.3, 暖色调        │
├─────────────────────────────────┤
│ 🎯 同好用户都在用                │
│ [模板卡片1] [模板卡片2]          │
├─────────────────────────────────┤
│ 查看全部模板 ›                   │
│ 点击 → /pages/templates/all     │
└─────────────────────────────────┘
```

**新建文件**：`/pages/templates/all.vue`（承载完整列表 + 三层分类筛选 + TagSelector + "我的"切换）

#### 3.4.3 模板详情页标签 add/display（需求 5）

修改 `pages/templates/detail.vue`：
- 同时展示 `tags`（旧字段，字符串数组）+ `tagIds`（新字段，解析为 UserTag）
- 新增"编辑标签"按钮 → 弹出 TagSelector
- 保存：`useTagManager.updateTemplateTags(templateId, tagIds)` + `useTemplate.saveCustomTemplate` 同步 `meta.tagIds`

### 3.5 模块 E：数据闭环

#### 3.5.1 今日拍摄贴士算法化（需求 7）

**useSceneManager.ts 新增**：

```typescript
export interface ShootingTip {
  text: string
  sub?: string
  sceneName: string
  source: 'recent_scene' | 'recent_template' | 'recent_param' | 'time_match' | 'fallback'
  priority: number
}

export function getShootingTip(): ShootingTip
// 算法：
// 1. 近期最常用场景的 tips（35%）
// 2. 近期最常用模板关联场景的 tips（25%）
// 3. 参数偏好贴士（20%）：高 ISO→降噪 / 暖色→色温 / 高 EV→曝光
// 4. 时间段匹配（15%）：早晨→黄金光 / 夜晚→夜景
// 5. 兜底随机预设（5%）

export function getNextShootingTip(current: ShootingTip): ShootingTip
```

**pages/home/index.vue 接入**：

```typescript
const currentTip = ref<ShootingTip>(getShootingTip())
function refreshTip() {
  currentTip.value = getNextShootingTip(currentTip.value)
}
```

#### 3.5.2 照片墙分类与场景关联（需求 11）

**useSceneManager.ts 新增**：

```typescript
export function updatePhotoScene(photoId: string, sceneId: ScenePresetId | CustomSceneId | null): void
export function getPhotosGroupedByScene(): Record<string, LocalPhoto[]>
```

**pages/gallery/index.vue 改造**：

- 读取 `useSceneManager.photos`（移除硬编码 picsum）
- 动态生成分类 pills：全部 | 各场景 | 未分类 | 收藏
- 按 activePill 过滤
- 点击照片 → `/pages/gallery/detail?id=xxx`

**pages/gallery/detail.vue 改造**：

- 新增"场景：xxx [更换 ›]"行
- 点击"更换"弹出场景选择 sheet
- 调用 `updatePhotoScene(photoId, sceneId)` → 刷新 UI

**preview.vue 保持不变**：用户未选场景时 `sceneId: null`，照片进入"未分类"。

## 4. 文件清单

### 4.1 修改文件

| 文件 | 改动 |
|---|---|
| `App.vue` | bounce 移除配置 + 全局 CSS |
| `pages.json` | globalStyle bounce + 新页面注册 |
| `composables/useCamera.ts` | captureAppPlus 改造为完整烘焙 |
| `utils/captureBake.ts` | 抽取 bakePhotoForCanvas 公共函数 |
| `utils/filterRecipe.ts` | ISO 公式 + 滤镜合法性校验 API |
| `pages/capture/index.vue` | 全屏切换 + 底部折叠 + pill 修复 + ISO 应用 + 场景 badge |
| `pages/capture/preview.vue` | 保持不变（sceneId 可为 null） |
| `pages/capture/scene-detail.vue` | 加入组合跳转 KitEditor + 标签 add/display |
| `pages/capture/scene-manage.vue` | 自定义场景表单增加 TagSelector |
| `pages/templates/index.vue` | 改为推荐结构 |
| `pages/templates/detail.vue` | 标签 add/display |
| `pages/home/index.vue` | 接入动态贴士 + 卡片简化 |
| `pages/gallery/index.vue` | 读取真实数据 + 场景分类 |
| `pages/gallery/detail.vue` | 归类到场景功能 |
| `composables/useSceneManager.ts` | getShootingTip + updatePhotoScene + getPhotosGroupedByScene |
| `composables/useTemplate.ts` | getRecommendedTemplates + getOtherTemplates |
| `composables/useTagManager.ts` | updateSceneTags + updateTemplateTags |
| `components/ScenePresetView.vue` | 卡片简化 + 新增 variant="list" |
| `components/TagSelector.vue` | 复用，无需改动 |

### 4.2 新建文件

| 文件 | 用途 |
|---|---|
| `pages/scenes/index.vue` | 独立场景库页面 |
| `pages/shootkit/editor.vue` | 组合编辑器 |
| `pages/templates/all.vue` | 完整模板列表 |

### 4.3 文档同步

实施完成后同步更新：
- `docs/superpowers/specs/2026-07-16-scene-management-design.md`
- `docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`
- `docs/superpowers/specs/2026-07-11-template-system-and-capture-guide-design.md`
- `docs/superpowers/specs/2026-07-03-lumira-prd.md`

## 5. 实施顺序

1. **模块 D**（核心 bug 修复 + 跨平台对等）→ 最高优先级
2. **模块 A**（体验层：bounce + 拍摄页 UI）
3. **模块 B**（场景模块增强）
4. **模块 C**（模板模块增强）
5. **模块 E**（数据闭环：贴士 + 照片墙）
6. **文档同步**

## 6. 风险与缓解

| 风险 | 缓解 |
|---|---|
| App-Plus WebView `ctx.filter` 不支持 | 增加像素级 filter 实现 `applyFilterFromPost`，作为降级 |
| 离屏 canvas 性能问题 | 限制最大烘焙尺寸为 2048px，超过时等比缩小 |
| `<camera>` backdrop-filter 在旧 Android 不支持 | 降级为仅显示原图预览，烘焙后照片仍含效果 |
| useSceneManager localStorage 容量 | 照片 dataUrl 改为文件路径（uni.saveFile），dataUrl 仅在 H5 |
| 推荐算法计算开销 | 缓存计算结果，5 分钟内复用 |
