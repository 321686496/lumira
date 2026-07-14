# 拍照页核心功能完善设计文档

**日期**：2026-07-14
**主题**：拍照页参数调整体系重构 + 系统内置滤镜 + 原相机模式

---

## 一、背景与问题

当前拍照页（`lumira-app/src/pages/capture/index.vue`）存在以下核心问题：

1. **未套用模板时无任何参数调整入口**：ParamPanel 与顶部 pill 栏均通过 `v-if="currentTemplate"` 控制渲染，直接进入 `/pages/capture/index` 时用户无法调整任何参数。
2. **"一键应用"按钮状态与实际滤镜脱节**：`applied` 是装饰性 ref，`toggleApply` 只切换布尔值，但 `viewfinderFilterStyle`、`applyVideoFilter`、`onShutter` 都不读取 `applied`，参数本来就实时生效。存在死代码 `activeCamera`/`activePost`。
3. **没有"取消模板效果/切换原相机"按钮**：用户进入模板后无法显式回到无滤镜状态。
4. **ParamPanel 中的"已应用"按钮无法取消**：`ParamPanel.vue#L486` `@click="!applied && emit('apply')"` 一旦应用就无法再次点击。
5. **多个参数只读不可调**：快门速度、ISO 模式、镜头建议、构图类型/网格/宽高比/主体框、剪影位置、裁剪比 等只能查看不能修改。
6. **缺少系统内置滤镜体系**：当前仅有 8 个 LUT 预设，没有苹果原相机风格的滤镜组。

---

## 二、需求决策汇总

| 决策点 | 选择 |
|--------|------|
| 高级设置入口形式 | ParamPanel 各 Tab 内折叠「高级参数」 |
| 未套用模板时 | 进入「自由调参」模式 |
| 取消模板效果按钮 | 独立的「原相机 ↔ 模板」切换按钮 |
| 参数偏离判定范围 | 所有可调参数都参与比较 |
| 苹果原相机参照范围 | 全面参照 |
| 模板调整 | 本阶段不动模板，只改造拍摄页 |
| 实现方案 | 方案 C（模块化，拆分独立组件） |
| 系统内置滤镜范围 | 新增苹果风格 6 种 + 扩展 LUT 至 16 种 |
| 滤镜入口 | 顶部 pill 栏快捷入口 + ParamPanel 后期 Tab 都提供 |

---

## 三、架构总览

### 3.1 三种使用模式

| 模式 | 触发条件 | 取景器预览 | ParamPanel |
|------|---------|-----------|-----------|
| **模板模式** | 通过模板列表/分享链接进入（携带 templateId） | 应用 editableTemplate 滤镜 | 显示，参数可调 |
| **自由调参模式** | 直接进入拍照页（无 templateId） | 应用 emptyTemplate 滤镜（默认无效果） | 显示，参数可调 |
| **原相机模式** | 在以上任一模式下点击"原相机"按钮 | 无任何滤镜（CSS filter: none） | 显示但参数控件灰化，调整不影响预览 |

### 3.2 两个独立状态

```ts
const rawMode = ref(false)        // 是否原相机模式（不应用任何滤镜）
const applied = computed(() => {  // 参数是否与模板原值一致
  if (!originalTemplate.value) return false  // 自由调参模式下永远 false
  return isParametersMatchingTemplate(
    editableTemplate.value!,
    originalTemplate.value
  )
})
```

- **`applied`**（computed）：反映"参数是否与模板原值一致"。用户调整任一可调参数 → 自动变 `false`；点击"一键应用"按钮 → 把 originalTemplate 深拷贝回 editableTemplate → 自动变 `true`
- **`rawMode`**（独立 ref）：反映"是否叠加任何滤镜"。点击"原相机↔模板"按钮切换。rawMode=true 时预览和拍照都不应用滤镜，但 ParamPanel 仍可见（控件灰化）

### 3.3 组件树（新增标 *）

```
capture/index.vue
├── 顶部 nav
│   └── (无变化)
├── 取景器
│   ├── video / viewfinder
│   └── 顶部 pill 栏
│       ├── EV pill (现有)
│       ├── WB pill (现有)
│       ├── *ApplyButton.vue          ← 一键应用按钮（独立组件）
│       ├── *RawModeToggle.vue        ← 原相机↔模板切换按钮（独立组件）
│       └── *FilterPicker.vue         ← 滤镜选择面板（pill 点击弹出）
├── *AdvancedSection.vue              ← 高级参数折叠区（独立组件，ParamPanel 内复用）
├── ParamPanel.vue
│   ├── 相机 Tab
│   │   ├── 常用参数
│   │   └── *AdvancedSection (含快门/镜头/拍照风格/HDR)
│   ├── 构图 Tab
│   │   ├── 常用参数
│   │   └── *AdvancedSection (含构图类型/网格/主体框)
│   ├── 场景 Tab (保持只读)
│   ├── 姿势 Tab
│   │   ├── 常用参数
│   │   └── *AdvancedSection (含剪影类型/位置X/Y)
│   └── 后期 Tab
│       ├── 系统滤镜区（6 项缩略图列表）
│       ├── LUT 预设区（16 项缩略图列表）
│       ├── 常用参数
│       └── *AdvancedSection (含色温/色调/磨皮/裁剪比)
├── template-strip (现有)
└── 底部快门区 (现有)
```

### 3.4 死代码清理

- 删除 `capture/index.vue` 行 262-275 的 `activeCamera` / `activePost` computed
- 删除 `toggleApply` 中的 toast 假重置逻辑
- 修复 `viewfinderFilterStyle` / `applyVideoFilter` / `onShutter`：读取 `rawMode` 决定是否应用滤镜
- 修复 `ParamPanel.vue` 行 486：允许点击取消（实际是重置为模板原值）

---

## 四、参数体系（全面参照苹果原相机）

> **技术约束**：本项目运行在 H5/小程序环境（uni-app），无法真正控制手机原生相机的光圈/快门/ISO/镜头切换等硬件参数。所有"相机参数"本质是**记录 + CSS filter 模拟预览 + Canvas 像素处理导出**。所以"参照苹果原相机"只是参数集和交互的参照，不是真正的硬件控制。

### 4.1 相机 Tab 参数集

| 参数 | 字段 | 控件 | 范围/选项 | 苹果对应 | 备注 |
|------|------|------|-----------|---------|------|
| 曝光补偿 | `exposureCompensation` | slider | -3 ~ +3, step 0.3 | EV | 现有 |
| ISO | `iso` | slider | 0-6400, step 50 | ISO | 现有 |
| **快门速度** | `shutterSpeed` | pill | 1/2000~30" | 快门 | **改可调** |
| 白平衡预设 | `whiteBalance` | pill | 6项 | WB | 现有 |
| 色温 K | `whiteBalanceK` | slider | 2500-8000 | 色温 | 现有 |
| 闪光模式 | `flashMode` | pill | 4项 | 闪光 | 现有 |
| 对焦模式 | `focusMode` | pill | 3项 | 对焦 | 现有 |
| **镜头切换** | `lensType` *新增* | pill | 0.5x/1x/2x/3x | 镜头 | **新增**（仅记录，不真切换硬件） |
| **拍照风格** | `photographicStyle` *新增* | pill | 5项 | 拍照风格 | **新增**（标准/高对比/暖/冷/单色） |
| **HDR** | `hdr` *新增* | switch | on/off | HDR | **新增** |
| ~~ISO 模式~~ | `isoMode` | 删除 | - | - | 无意义字段 |
| ~~镜头建议~~ | `lensSuggestion` | 删除 | - | - | 改为 lensType |
| ~~滤镜预设~~ | `filterPreset` | 删除 | - | - | 改用独立滤镜系统 |

### 4.2 构图 Tab 参数集

| 参数 | 字段 | 控件 | 范围 | 备注 |
|------|------|------|------|------|
| 构图类型 | `overlayType` | pill | 4项 | **改可调** |
| 网格细分 | `gridType` | pill | 3项 | **改可调** |
| 宽高比 | `aspectRatio` | pill | 4:3/1:1/16:9/3:4 | **改可调**（影响取景器框） |
| 主体建议框 | `subjectFrame` | switch | on/off | **改可调** |
| 叠图透明度 | `opacity` | slider | 0-100% | 现有 |
| 构图说明 | 文本 | 只读 | - | 保持只读 |

### 4.3 姿势 Tab 参数集

| 参数 | 字段 | 控件 | 范围 | 备注 |
|------|------|------|------|------|
| 剪影类型 | `silhouetteType` | pill | 3项 | **改可调** |
| 剪影位置 X | `pose.positionX` *新增* | slider | -100~100 | **新增** |
| 剪影位置 Y | `pose.positionY` *新增* | slider | -100~100 | **新增** |
| 缩放 | `pose.scale` | slider | 0.3-3 | 现有 |
| 旋转 | `pose.rotation` | slider | -180~180 | 现有 |
| 姿势描述 | 文本 | 只读 | - | 保持只读 |

### 4.4 后期 Tab 参数集

| 参数 | 字段 | 控件 | 范围 | 备注 |
|------|------|------|------|------|
| **系统滤镜** | `systemFilter` *新增* | pill（6项缩略图） | 苹果6种 | **新增** |
| **LUT 预设（扩展）** | `lut` | pill（16项缩略图） | 8现有+8新增 | **扩展** |
| 裁剪比 | `cropRatio` | pill | 4项 | **改可调** |
| 亮度 | `color.brightness` | slider | -100~100 | 现有 |
| 对比度 | `color.contrast` | slider | -100~100 | 现有 |
| 饱和度 | `color.saturation` | slider | -100~100 | 现有 |
| 色温 | `color.temperature` | slider | -100~100 | 现有（移入高级） |
| 色调 | `color.tint` | slider | -100~100 | 现有（移入高级） |
| 磨皮 | `smoothStrength` | slider | 0-100 | 现有（移入高级） |
| 锐化 | `sharpen` | slider | 0-100 | 现有 |
| 暗角 | `vignette` | slider | 0-100 | 现有 |
| 颗粒 | `grain` | slider | 0-100 | 现有 |

---

## 五、系统内置滤镜体系

### 5.1 苹果风格系统滤镜（6 种）

| ID | 名称 | filter 链 | 说明 |
|----|------|-----------|------|
| `vivid` | 鲜明 | `contrast(1.1) saturate(1.25) brightness(1.02)` | 增强对比与饱和 |
| `vivid_warm` | 鲜暖色 | `sepia(0.15) saturate(1.2) contrast(1.08) brightness(1.03) hue-rotate(-5deg)` | 暖调鲜明 |
| `vivid_cool` | 鲜冷色 | `saturate(1.15) contrast(1.08) brightness(1.02) hue-rotate(8deg)` | 冷调鲜明 |
| `mono` | 单色 | `grayscale(1) contrast(1.05)` | 纯黑白 |
| `silver` | 银色调 | `grayscale(1) sepia(0.2) contrast(0.95) brightness(1.08)` | 银灰调 |
| `noir` | 黑白 | `grayscale(1) contrast(1.3) brightness(0.95)` | 高对比黑白 |

### 5.2 LUT 预设扩展（8 现有 + 8 新增 = 16 种）

新增 8 种：

| ID | 名称 | filter 链 | 说明 |
|----|------|-----------|------|
| `portrait` | 人像 | `saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05)` | 人像优化 |
| `japanese` | 日系 | `saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg)` | 低饱和青调 |
| `cyberpunk` | 赛博朋克 | `saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95)` | 紫青高对比 |
| `sepia_classic` | 褐调 | `sepia(0.7) contrast(1.05) brightness(1.02)` | 经典棕褐 |
| `mist` | 薄雾 | `contrast(0.88) brightness(1.12) saturate(0.9)` | 雾感朦胧 |
| `rouge` | 胭脂 | `sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02)` | 红调 |
| `twilight` | 暮光 | `saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95)` | 紫调黄昏 |
| `cyan` | 青调 | `saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02)` | 青绿调 |

### 5.3 类型扩展

```ts
// types/template.ts
export type SystemFilter =
  | 'none' | 'vivid' | 'vivid_warm' | 'vivid_cool'
  | 'mono' | 'silver' | 'noir'

export type LutPreset =
  | 'none' | 'cinematic' | 'vintage' | 'bw'
  | 'warm_film' | 'cool_film' | 'pastel' | 'fuji'
  // 新增 8 种
  | 'portrait' | 'japanese' | 'cyberpunk' | 'sepia_classic'
  | 'mist' | 'rouge' | 'twilight' | 'cyan'

export interface CameraParams {
  // ...现有字段
  lensType?: '0.5x' | '1x' | '2x' | '3x'
  photographicStyle?: 'standard' | 'high_contrast' | 'warm' | 'cool' | 'mono'
  hdr?: boolean
}

export interface PostProcess {
  // ...现有字段
  systemFilter?: SystemFilter
}
```

### 5.4 滤镜叠加规则

`buildCssFilter` 中应用顺序：
1. 相机参数（EV、白平衡、色温）的基础调整
2. `systemFilter`（基础调色，类似苹果原相机滤镜）
3. 后期参数（brightness/contrast/saturation/temperature/tint）
4. `lut`（叠加风格化效果）

**特殊处理**：当 `systemFilter` 为 `mono`/`noir`/`silver` 时，LUT 的彩色效果会失效（已 grayscale），但仍保留 LUT 的对比度/亮度调整。

---

## 六、状态机与数据流

### 6.1 状态字段

```ts
// capture/index.vue
const rawMode = ref(false)                                // 是否原相机模式
const originalTemplate = ref<PhotoTemplate | null>(null)  // 模板原值快照（不可变）
const editableTemplate = ref<PhotoTemplate | null>(null)  // 可编辑副本
const emptyTemplate = createEmptyTemplate()               // 空白模板（自由调参模式）

const applied = computed(() => {
  if (!originalTemplate.value) return false
  return isParametersMatchingTemplate(
    editableTemplate.value!,
    originalTemplate.value
  )
})

const activeTemplate = computed(() => {
  if (rawMode.value) return null
  return editableTemplate.value ?? emptyTemplate
})
```

### 6.2 参数匹配判定函数

新增 `utils/parameterMatch.ts`：

```ts
const ADJUSTABLE_PARAM_PATHS = [
  'camera.exposureCompensation',
  'camera.iso',
  'camera.shutterSpeed',
  'camera.whiteBalance',
  'camera.whiteBalanceK',
  'camera.flashMode',
  'camera.focusMode',
  'camera.lensType',
  'camera.photographicStyle',
  'camera.hdr',
  'composition.overlayType',
  'composition.gridType',
  'composition.aspectRatio',
  'composition.subjectFrame',
  'composition.opacity',
  'pose.silhouetteType',
  'pose.positionX',
  'pose.positionY',
  'pose.scale',
  'pose.rotation',
  'postProcess.systemFilter',
  'postProcess.lut',
  'postProcess.cropRatio',
  'postProcess.color.brightness',
  'postProcess.color.contrast',
  'postProcess.color.saturation',
  'postProcess.color.temperature',
  'postProcess.color.tint',
  'postProcess.smoothStrength',
  'postProcess.sharpen',
  'postProcess.vignette',
  'postProcess.grain'
]

export function isParametersMatchingTemplate(
  current: PhotoTemplate,
  original: PhotoTemplate
): boolean {
  for (const path of ADJUSTABLE_PARAM_PATHS) {
    if (get(current, path) !== get(original, path)) return false
  }
  return true
}
```

### 6.3 三种模式渲染逻辑修复

```ts
// viewfinderFilterStyle（修复：读取 rawMode）
const viewfinderFilterStyle = computed(() => {
  if (rawMode.value) return {}
  if (!editableTemplate.value) {
    return buildCssFilter(emptyTemplate.camera, emptyTemplate.postProcess)
  }
  const filter = buildCssFilter(
    editableTemplate.value.camera,
    editableTemplate.value.postProcess
  )
  return filter ? { filter, webkitFilter: filter } : {}
})

// applyVideoFilter（修复：读取 rawMode）
function applyVideoFilter() {
  if (!videoRef.value) return
  if (rawMode.value) {
    videoRef.value.style.filter = ''
    return
  }
  const tpl = editableTemplate.value ?? emptyTemplate
  const filter = buildCssFilter(tpl.camera, tpl.postProcess)
  videoRef.value.style.filter = filter
}

// onShutter（修复：读取 rawMode）
const onShutter = async () => {
  let cameraParams: Partial<CameraParams>
  let postParams: Partial<PostProcess>
  if (rawMode.value) {
    cameraParams = {}
    postParams = {}
  } else {
    const tpl = editableTemplate.value ?? emptyTemplate
    cameraParams = tpl.camera
    postParams = tpl.postProcess
  }
  const result = await camera.capture(cameraParams, postParams)
  // ...
}
```

### 6.4 一键应用 / 取消应用逻辑

```ts
// ApplyButton 点击处理
const onApplyClick = () => {
  if (!originalTemplate.value) return  // 自由调参模式下无意义
  if (applied.value) {
    // 已应用：点击无操作（或 toast "参数已是模板原值"）
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
  } else {
    // 未应用：把 originalTemplate 深拷贝回 editableTemplate
    editableTemplate.value = JSON.parse(JSON.stringify(originalTemplate.value))
    // applied 会自动变 true（computed）
  }
}
```

### 6.5 切换模板时重置

```ts
const switchTemplate = (id: string) => {
  currentTemplateId.value = id
  // originalTemplate 通过 watch 自动更新
  // editableTemplate 通过 watch 自动深拷贝
  // applied 自动变 true（参数与原值一致）
  rawMode.value = false  // 切换模板时退出原相机模式
  pushRecent(id)
}
```

---

## 七、UI 改动

### 7.1 顶部 pill 栏（新增 2 个按钮 + 滤镜入口）

```
[EV] [WB] [一键应用✓] [原相机] [滤镜]   ← 5 个 pill（原有 3 + 新增 2）
```

**ApplyButton.vue**（独立组件）：
- applied=true 时：绿色 Phosphor `ph-check` + "已应用"
- applied=false 时：原色 Phosphor `ph-sparkle` + "一键应用"
- 点击：未应用时把 originalTemplate 深拷贝回 editableTemplate；已应用时 toast 提示
- 仅在模板模式（`originalTemplate` 存在）下显示

**RawModeToggle.vue**（独立组件）：
- rawMode=false 时：Phosphor `ph-camera` + "模板"（或"自由"）
- rawMode=true 时：高亮 Phosphor `ph-camera` + "原相机"
- 点击：切换 rawMode
- 始终显示

**FilterPicker.vue**（独立组件，pill 点击弹出）：
- 横向滚动列表，每项含缩略图（取景器当前帧 + 滤镜预览）+ 名称
- 分两组：系统滤镜（6 项）+ LUT 预设（16 项）
- 选中态：高亮边框
- 选中后写入 `editableTemplate.postProcess.systemFilter` 或 `lut`
- 自由调参模式也可用（写入 emptyTemplate）
- 原相机模式下点击弹出 toast "已切换至原相机模式，请先退出"

### 7.2 ParamPanel 各 Tab 内 AdvancedSection（折叠区）

```vue
<view class="advanced-toggle" @click="advancedOpen = !advancedOpen">
  <text>高级参数</text>
  <text class="ph" :class="advancedOpen ? 'ph-caret-up' : 'ph-caret-down'" />
</view>
<AdvancedSection v-if="advancedOpen" title="高级参数">
  <!-- 快门速度 pill -->
  <!-- 镜头切换 pill -->
  <!-- 拍照风格 pill -->
  <!-- HDR switch -->
</AdvancedSection>
```

**AdvancedSection.vue**（独立组件）：
- props: `title`, `open`
- 通过 `<slot>` 接收高级参数控件
- 通用折叠容器，每个 Tab 实例化一次

### 7.3 ParamPanel 后期 Tab 滤镜区

```vue
<view class="filter-section">
  <text class="section-title">系统滤镜</text>
  <scroll-view scroll-x class="filter-list">
    <view v-for="f in systemFilters" :key="f.id"
          class="filter-item" :class="{ active: post.systemFilter === f.id }"
          @click="updatePost('systemFilter', f.id)">
      <view class="filter-thumb" :style="thumbFilter(f.filter)">
        <image :src="currentViewfinderSnapshot" mode="aspectFill" />
      </view>
      <text class="filter-name">{{ f.name }}</text>
    </view>
  </scroll-view>
</view>

<view class="filter-section">
  <text class="section-title">LUT 预设</text>
  <scroll-view scroll-x class="filter-list">
    <!-- 16 项 LUT -->
  </scroll-view>
</view>
```

### 7.4 自由调参模式 UI

- ParamPanel 始终渲染（移除 `v-if="editableTemplate"`，改为 `v-if="activeTemplate"`）
- 顶部 pill 栏始终渲染（移除 `v-if="currentTemplate"`）
- ApplyButton 在自由调参模式下隐藏（无 originalTemplate 可对齐）
- 标题栏：模板模式显示模板名；自由调参模式显示"自由调参"；原相机模式显示"原相机"

### 7.5 原相机模式 UI

- ParamPanel 仍可见，但参数控件灰化（添加 `raw-mode-disabled` class）
- 顶部 pill 栏所有参数 pill 仍可见，但点击无效（或显示 toast"已切换至原相机模式"）
- 取景器：无任何 filter
- 标题栏显示"原相机"

---

## 八、文件改动清单

### 8.1 新增文件

| 文件路径 | 说明 |
|---------|------|
| `lumira-app/src/components/ApplyButton.vue` | 一键应用按钮组件 |
| `lumira-app/src/components/RawModeToggle.vue` | 原相机↔模板切换按钮组件 |
| `lumira-app/src/components/FilterPicker.vue` | 滤镜选择面板组件 |
| `lumira-app/src/components/AdvancedSection.vue` | 高级参数折叠区组件 |
| `lumira-app/src/utils/parameterMatch.ts` | 参数匹配判定工具 |
| `lumira-app/src/utils/emptyTemplate.ts` | 空白模板工厂（createEmptyTemplate） |

### 8.2 修改文件

| 文件路径 | 改动要点 |
|---------|---------|
| `lumira-app/src/pages/capture/index.vue` | 重构状态机（rawMode/applied computed）；修复 viewfinderFilterStyle/applyVideoFilter/onShutter 读取 rawMode；删除死代码 activeCamera/activePost；移除 v-if 让 ParamPanel/pill 栏始终渲染；集成新组件 |
| `lumira-app/src/components/ParamPanel.vue` | 各 Tab 内增加 AdvancedSection 折叠区；只读参数改可调；后期 Tab 增加系统滤镜区与扩展 LUT 区；修复 apply-btn 点击逻辑 |
| `lumira-app/src/types/template.ts` | 新增 SystemFilter 类型；扩展 LutPreset 类型；CameraParams 增加 lensType/photographicStyle/hdr；PostProcess 增加 systemFilter；Pose 增加 positionX/positionY |
| `lumira-app/src/utils/filterRecipe.ts` | 扩展 LUT_FILTERS 字典（+8 项）；新增 SYSTEM_FILTERS 字典（6 项）；buildCssFilter 增加 systemFilter 应用逻辑；新增 getSystemFilterLabel 函数 |

### 8.3 不动文件（本阶段）

- `lumira-app/src/data/templates/*.ts`（12 个内置模板，下阶段调整）
- `lumira-app/src/composables/useTemplate.ts`
- `lumira-app/src/composables/useCamera.ts`
- `lumira-app/src/utils/captureBake.ts`

---

## 九、风险与边界

### 9.1 已知风险

1. **CSS filter 性能**：叠加 systemFilter + LUT + 后期参数可能产生较长 filter 链，需在真机测试预览帧率
2. **取景器缩略图实时性**：FilterPicker 的缩略图若使用取景器实时帧，需要 capture frame → dataURL，可能影响性能；备选方案是使用固定样图
3. **模板兼容性**：现有 12 个模板没有 systemFilter 字段，默认为 `'none'`，不影响兼容
4. **原相机模式与模板模式切换**：切换时 editableTemplate 不变，仅 rawMode 变化，避免参数丢失

### 9.2 不在本次范围

- 模板参数调整（下阶段单独处理）
- 真正的硬件镜头切换（受 uni-app 能力限制）
- 滤镜缩略图的实时取景器帧捕获（备选固定样图方案）
- 自定义滤镜保存

---

## 十、验收标准

1. **自由调参模式**：直接进入 `/pages/capture/index` 时，ParamPanel 与顶部 pill 栏可见可调
2. **模板模式**：通过 templateId 进入时，参数默认为模板值，applied=true
3. **参数偏离**：调整任一可调参数后，applied 自动变 false，按钮变为"一键应用"
4. **一键应用**：点击未应用按钮，参数重置为模板原值，applied 变 true
5. **原相机切换**：点击"原相机"按钮，预览立即无滤镜；再次点击恢复
6. **原相机模式 UI**：ParamPanel 控件灰化但可见
7. **高级参数**：各 Tab 内"高级参数"折叠区可展开，包含快门/镜头/拍照风格/HDR/构图类型/网格/宽高比/主体框/剪影类型/位置/裁剪比等
8. **系统滤镜**：顶部"滤镜"按钮点击弹出面板，含 6 种苹果风格 + 16 种 LUT；后期 Tab 也有完整列表
9. **滤镜应用**：选中滤镜后预览实时变化，拍照导出应用对应滤镜
10. **死代码清理**：activeCamera/activePost 已删除，toggleApply 假重置已移除
