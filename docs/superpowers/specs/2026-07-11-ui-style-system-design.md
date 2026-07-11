# 如画 App UI 风格切换系统设计

**日期**: 2026-07-11
**状态**: 已批准，待实现

## 1. 概述

在现有的颜色主题切换（4 套：暖米白/浓墨/胶片复古/日系清新）基础上，新增 **UI 风格切换**功能，支持 4 种视觉设计语言。风格与主题正交独立，可自由组合（如"莫兰迪色 + 玻璃拟态"）。

### 1.1 两层正交系统

```
data-theme  →  颜色变量（--color-canvas, --color-brand, --color-surface …）
data-style  →  效果变量（--shadow-*, --card-border, --surface-alpha, --card-radius …）
```

- **主题 (Theme)** = 颜色调色板，控制所有颜色变量
- **风格 (Style)** = 视觉设计语言，控制阴影、边框、模糊、圆角、动效等效果
- 两者独立设置，任意组合

## 2. 四种 UI 风格定义

### 2.1 新拟态 `neumorphism`（当前默认，保持现状）

- **阴影**：双向凸/凹阴影（亮色 + 暗色双向投影）
- **边框**：无
- **背景**：实色 = canvas 颜色
- **圆角**：`28rpx`（卡片）
- **现有变量**：`--shadow-convex`, `--shadow-concave`, `--shadow-convex-subtle`, `--shadow-concave-subtle`, `--shadow-pressed`, `--shadow-convex-brand`

### 2.2 扁平化 `flat`

- **阴影**：无（`--shadow-*: none`）
- **边框**：`1rpx solid var(--color-divider)`（新增 `--card-border` 变量）
- **背景**：实色
- **圆角**：`20rpx`（卡片）
- **Toggle**：用色块填充表示激活态，去除阴影旋钮效果
- **按钮**：纯色背景，无边框/阴影，`:active` 仅 `scale(0.97)`

### 2.3 玻璃拟态 `glass`

- **阴影**：柔和环境光阴影 `0 8px 32px rgba(0,0,0,0.08)`
- **边框**：半透明细边 `1rpx solid rgba(255,255,255,0.3)`（浅色主题）/ `rgba(255,255,255,0.1)`（深色主题）
- **背景**：半透明 `rgba(255,255,255,0.55)` + `backdrop-filter: blur(20px)`
- **圆角**：`28rpx`
- **定向规则**：`[data-style="glass"] .neu-card, [data-style="glass"] .lumira-card` 应用 blur + 半透明

### 2.4 女性美学 `female`

基于女性美学设计系统，玻璃拟态的女性化升级版：

- **阴影**：暖粉弥散阴影 `0 8px 32px rgba(var(--color-brand-rgb), 0.15)`
- **边框**：无（摒弃粗重实线边框）
- **背景**：半透明白底 `rgba(255, 255, 255, 0.75)` + `backdrop-filter: blur(20px)`
- **圆角**：`48rpx`（比其他风格更大，消除尖锐感）
- **微动效**：
  - 所有过渡：`cubic-bezier` 缓动，`0.3s`
  - 按压反馈：`scale(0.96)`
  - 悬浮反馈：`translateY(-4px)` + 加深阴影
  - 激活态导航：`pulse` 呼吸光晕动画
- **克制原则**：动效轻量，仅关键时刻触发

## 3. 八套颜色主题定义

### 3.1 现有 4 套（保留，不修改）

| 主题 | id | canvas | brand | 描述 |
|------|----|--------|-------|------|
| 暖米白 | `warm` | `#FAF7F2` | `#C9A96E` | 温润如玉，东方留白 |
| 浓墨 | `ink` | `#1C1A17` | `#D4B57A` | 深邃墨色，暗夜专注 |
| 胶片复古 | `retro` | `#F5E6D3` | `#C4956A` | 温暖胶片质感 |
| 日系清新 | `fresh` | `#F8FAF6` | `#8BAD72` | 清新自然，柔和明亮 |

### 3.2 新增 4 套女性向颜色主题

#### 温馨粉 `cozy`
```css
--color-canvas: #FFF5F5;
--color-surface: #FFFFFF;
--color-surface-alt: #FAEDED;
--color-canvas-deep: #F5EAEA;
--color-text-primary: #4A3A3A;
--color-text-secondary: #8C7070;
--color-text-tertiary: #B89A9A;
--color-divider: #F0E0E0;
--color-brand: #E8A0A0;
--color-brand-deep: #D4858A;
--color-brand-light: #F0B5B5;
--color-brand-subtle: #FCE8E8;
--color-brand-text: #C47070;
--color-brand-rgb: 232, 160, 160;
--color-danger: #D47070;
--color-danger-subtle: #FCE8E8;
--color-success: #8FB088;
--color-success-subtle: #EDF2E8;
```
气质：柔粉温暖，温馨治愈

#### 马卡龙 `macaron`
```css
--color-canvas: #FFF8F0;
--color-surface: #FFFFFF;
--color-surface-alt: #F5F0E8;
--color-canvas-deep: #F0EAE0;
--color-text-primary: #5A4A4A;
--color-text-secondary: #8C7A7A;
--color-text-tertiary: #B8A8A0;
--color-divider: #E8E0D5;
--color-brand: #A8D8C8;
--color-brand-deep: #8CC5B5;
--color-brand-light: #C5E8DD;
--color-brand-subtle: #E0F0EA;
--color-brand-text: #5E9882;
--color-brand-rgb: 168, 216, 200;
--color-danger: #E8A0A0;
--color-danger-subtle: #FCE8E8;
--color-success: #A8D8C8;
--color-success-subtle: #E0F0EA;
```
气质：薄荷糖果，甜美活泼

#### 莫兰迪 `morandi`
```css
--color-canvas: #E8E4E0;
--color-surface: #F2EFEA;
--color-surface-alt: #E0DCD6;
--color-canvas-deep: #DDD9D3;
--color-text-primary: #4A4540;
--color-text-secondary: #7A7570;
--color-text-tertiary: #A8A29C;
--color-divider: #D5D0CA;
--color-brand: #8B9DAF;
--color-brand-deep: #6B7D8F;
--color-brand-light: #A8B8C8;
--color-brand-subtle: #D5DDE5;
--color-brand-text: #5B6D7F;
--color-brand-rgb: 139, 157, 175;
--color-danger: #A88080;
--color-danger-subtle: #E8DDDD;
--color-success: #8FA590;
--color-success-subtle: #DDE5DD;
```
气质：灰调优雅，安静内敛

#### 玫瑰金 `rosegold`
```css
--color-canvas: #FAF6F2;
--color-surface: #FFFFFF;
--color-surface-alt: #F5EDE8;
--color-canvas-deep: #F0E8E2;
--color-text-primary: #3D2E2A;
--color-text-secondary: #6B5450;
--color-text-tertiary: #A89088;
--color-divider: #E8DDD5;
--color-brand: #C9A0A0;
--color-brand-deep: #B08585;
--color-brand-light: #DDB8B8;
--color-brand-subtle: #F0E0E0;
--color-brand-text: #A06868;
--color-brand-rgb: 201, 160, 160;
--color-danger: #C47878;
--color-danger-subtle: #F0E0E0;
--color-success: #9AB088;
--color-success-subtle: #E8F0E0;
```
气质：轻奢优雅，玫瑰金质感

## 4. 数据模型

### 4.1 类型定义（theme-configs.ts）

```typescript
export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh' | 'cozy' | 'macaron' | 'morandi' | 'rosegold'

export type StyleId = 'neumorphism' | 'flat' | 'glass' | 'female'

export interface StyleMeta {
  id: StyleId
  label: string
  description: string
  icon: string
}

export const STYLE_METAS: Record<StyleId, StyleMeta> = {
  neumorphism: { id: 'neumorphism', label: '新拟态', description: '双向阴影，柔和立体', icon: 'ph-circle-half' },
  flat: { id: 'flat', label: '扁平化', description: '干净利落，无多余修饰', icon: 'ph-square' },
  glass: { id: 'glass', label: '玻璃拟态', description: '半透明毛玻璃，通透感', icon: 'ph-transparent' },
  female: { id: 'female', label: '女性美学', description: '暖粉弥散，大圆角，呼吸感', icon: 'ph-heart' }
}

export const STYLE_IDS: StyleId[] = ['neumorphism', 'flat', 'glass', 'female']
```

### 4.2 Composable（useTheme.ts 扩展）

```typescript
// 现有 currentTheme / followSystem / setTheme / loadTheme / setFollowSystem 保留
// 新增：
const currentStyle = ref<StyleId>('neumorphism')

function applyStyle(id: StyleId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-style', id)
  }
  // #endif
}

function setStyle(id: StyleId) {
  currentStyle.value = id
  applyStyle(id)
  try { uni.setStorageSync('uiStyle', id) } catch (e) { console.warn('Failed to persist style', e) }
}

function loadStyle() {
  try {
    const saved = uni.getStorageSync('uiStyle') as StyleId
    if (saved && STYLE_IDS.includes(saved)) {
      currentStyle.value = saved
    }
  } catch (e) { console.warn('Failed to load style', e) }
  applyStyle(currentStyle.value)
}
```

## 5. UI 入口

### 5.1 设置页（settings.vue）

在"通用"分组中"主题选择"下方新增"风格选择"行：

```
通用
├── 主题选择    [当前主题名] >
├── 风格选择    [当前风格名] >   ← 新增
└── 语言       简体中文 >
```

### 5.2 主题页（theme.vue 重构为两段式）

```
主题与风格

── UI 风格 ──
[新拟态]  [扁平化]
[玻璃拟态] [女性美学]
（4 张卡片，2×2 网格，带风格预览效果）

── 颜色主题 ──
[暖米白] [浓墨]
[胶片复古] [日系清新]
[温馨粉] [马卡龙]
[莫兰迪] [玫瑰金]
（8 张卡片，2×4 网格，带色彩预览点）

── 选项 ──
跟随系统 [toggle]
```

## 6. CSS 实现细节

### 6.1 变量重定义策略

所有风格通过 `data-style` 属性重定义现有 `--shadow-*` 变量 + 新增变量：

**默认（新拟态）** — `:root` 或 `[data-style="neumorphism"]`
```css
/* 保持现有定义不变 */
--shadow-convex: 6px 6px 14px #D8D4CC, -6px -6px 14px #FFFFFF;
/* ... */
--card-border: none;
--card-radius: 28rpx;
--surface-alpha: 1;
```

**扁平化** — `[data-style="flat"]`
```css
--shadow-convex: none;
--shadow-concave: none;
--shadow-convex-subtle: none;
--shadow-concave-subtle: none;
--shadow-pressed: none;
--shadow-convex-brand: none;
--shadow-float: none;
--card-border: 1rpx solid var(--color-divider);
--card-radius: 20rpx;
--surface-alpha: 1;
```

**玻璃拟态** — `[data-style="glass"]`
```css
--shadow-convex: 0 8px 32px rgba(0,0,0,0.08);
--shadow-concave: inset 0 2px 8px rgba(0,0,0,0.06);
--shadow-convex-subtle: 0 4px 16px rgba(0,0,0,0.06);
--shadow-concave-subtle: inset 0 1px 4px rgba(0,0,0,0.04);
--shadow-pressed: inset 0 2px 8px rgba(0,0,0,0.08);
--shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.3);
--shadow-float: 0 8px 32px rgba(0,0,0,0.08);
--card-border: 1rpx solid rgba(255,255,255,0.3);
--card-radius: 28rpx;
--surface-alpha: 0.55;
```

**女性美学** — `[data-style="female"]`
```css
--shadow-convex: 0 8px 32px rgba(var(--color-brand-rgb), 0.15);
--shadow-concave: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.08);
--shadow-convex-subtle: 0 4px 16px rgba(var(--color-brand-rgb), 0.1);
--shadow-concave-subtle: inset 0 1px 4px rgba(var(--color-brand-rgb), 0.05);
--shadow-pressed: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.1);
--shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.25);
--shadow-float: 0 8px 32px rgba(var(--color-brand-rgb), 0.12);
--card-border: none;
--card-radius: 48rpx;
--surface-alpha: 0.75;
```

### 6.2 定向覆盖规则

玻璃拟态和女性美学需要 `backdrop-filter`，无法纯变量驱动，用定向 CSS：

```css
/* 玻璃拟态 */
[data-style="glass"] .neu-card,
[data-style="glass"] .lumira-card,
[data-style="glass"] .floating-tabbar {
  background-color: rgba(255, 255, 255, var(--surface-alpha));
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

/* 女性美学 */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .floating-tabbar {
  background-color: rgba(255, 255, 255, var(--surface-alpha));
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

/* 女性美学呼吸光晕 */
@keyframes female-pulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(var(--color-brand-rgb), 0.4); }
  50% { box-shadow: 0 0 0 8rpx rgba(var(--color-brand-rgb), 0); }
}

[data-style="female"] .tabbar-item.active,
[data-style="female"] .tabbar-center {
  animation: female-pulse 2s ease-in-out infinite;
}

/* 扁平化 toggle 色块填充 */
[data-style="flat"] .neu-toggle.active {
  background-color: var(--color-brand);
  box-shadow: none;
}

[data-style="flat"] .neu-toggle.active .neu-toggle-knob {
  background-color: #FFFFFF;
  box-shadow: none;
}

/* 扁平化卡片边框 */
[data-style="flat"] .neu-card,
[data-style="flat"] .lumira-card {
  border: var(--card-border);
}

/* 女性美学卡片大圆角 */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card {
  border-radius: var(--card-radius);
}
```

### 6.3 深色主题适配

玻璃拟态和女性美学的半透明背景在深色主题下需调整：
```css
[data-theme="ink"][data-style="glass"] .neu-card,
[data-theme="ink"][data-style="glass"] .lumira-card {
  background-color: rgba(38, 35, 32, 0.55);
  border-color: rgba(255,255,255,0.1);
}

[data-theme="ink"][data-style="female"] .neu-card,
[data-theme="ink"][data-style="female"] .lumira-card {
  background-color: rgba(38, 35, 32, 0.75);
}
```

## 7. 文件改动清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `src/theme/theme-configs.ts` | 修改 | 新增 4 主题元数据 + 新增 `STYLE_METAS`/`STYLE_IDS`/`StyleId` 类型 |
| `src/composables/useTheme.ts` | 修改 | 新增 `currentStyle`/`applyStyle`/`setStyle`/`loadStyle`，导出扩展 |
| `src/App.vue` | 修改 | 新增 `data-style` 应用 + 4 套新主题 CSS 变量 + 4 种风格 CSS 变量重定义 + 定向覆盖规则 + 深色适配 |
| `src/pages/profile/settings/theme.vue` | 重构 | 两段式 UI：风格选择（4 卡）+ 主题选择（8 卡）+ 跟随系统 |
| `src/pages/profile/settings.vue` | 修改 | 新增"风格选择"行，显示当前风格名 |
| `src/uni.scss` | 修改 | 新增 4 套主题的 SCSS 变量定义（可选，用于编译时变量） |

### 各页面组件（自动适配为主）

现有组件通过 `var(--shadow-*)`、`var(--color-*)` 引用变量，切换风格时变量自动重定义，无需逐个修改。以下组件可能需要少量定向微调：

- `FloatingTabBar.vue` — 玻璃拟态/女性美学的 blur 效果
- 各页面的卡片组件 — 扁平化边框、女性美学圆角（通过定向 CSS 规则覆盖，无需改组件代码）

## 8. 实现策略

采用 **CSS 变量重定义 + 定向覆盖** 方案：

1. **变量层**：4 种风格重定义 `--shadow-*` + 新增 `--card-border`/`--card-radius`/`--surface-alpha`
2. **定向规则层**：玻璃拟态/女性美学的 `backdrop-filter`、扁平化的边框/toggle、女性美学的呼吸动画
3. **组件层**：绝大多数组件无需修改（引用变量自动级联）
4. **深色适配**：`[data-theme="ink"]` 下的玻璃/女性美学半透明背景调整

## 9. 验收标准

- [ ] 设置页有"风格选择"入口，显示当前风格名
- [ ] 主题页分两段：风格（4 卡）+ 主题（8 卡）
- [ ] 切换风格即时生效，所有页面同步更新
- [ ] 切换主题即时生效，所有页面同步更新
- [ ] 风格和主题任意组合均正常显示
- [ ] 跟随系统切换时，风格保持用户选择不变
- [ ] 风格和主题选择持久化，重启应用后恢复
- [ ] 玻璃拟态：卡片半透明 + backdrop-filter 生效
- [ ] 女性美学：暖粉阴影 + 大圆角 + 呼吸光晕
- [ ] 扁平化：无阴影 + 细边框
- [ ] 新拟态：保持现状不变
