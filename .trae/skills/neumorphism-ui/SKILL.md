---
name: "neumorphism-ui"
description: "新拟态 Neumorphism 双轨 UI 设计技能。涵盖标准纯色新拟态与图像悬浮改良新拟态两套完整体系，包含设计令牌、组件模板、交互规范与避坑准则。当用户需要设计新拟态风格 UI、搭建新拟态组件库、或遇到图片上方新拟态组件的落影问题时调用。"
---

# 新拟态 Neumorphism UI 设计技能

## 技能概述

掌握**标准纯色新拟态**与**图像悬浮改良新拟态**双轨设计体系，专注移动端轻量化拟物 UI 落地。摒弃传统拟物化复杂纹理与扁平化单调质感，以光影、材质、物理交互为核心，可独立搭建完整移动端新拟态组件库。

---

## 一、核心设计哲学

### 1. 同质材质雕刻原理

新拟态核心并非多层投影叠加，而是**同源背景材质的凹凸雕刻效果**。组件底色与页面底色保持高度统一，无边框、无分割线，仅通过双光源阴影模拟材质凸起、凹陷、挤压的物理质感。

### 2. 统一光源规则

全局固定光源：**左上自然光高光、右下暗部投影**。所有组件光影方向一致，杜绝视觉混乱。

### 3. 双形态语义化交互

- **Convex 凸起（外阴影）**：组件常态、可点击、悬浮状态
- **Concave 凹陷（inset 内阴影）**：组件激活、选中、输入嵌入状态

依靠光影切换实现状态区分，无需依赖颜色渐变、边框变化。

### 4. 场景二分落地体系（核心能力）

打破传统新拟态仅适配纯色背景的局限，区分两大落地场景：

| 场景 | 方案 | 适用 |
|------|------|------|
| 纯色静态页面 | **标准凹凸雕刻新拟态** | 表单、卡片、导航、数据展示 |
| 图片/视频/相机动态画面 | **半透悬浮改良新拟态** | 相机快门、图片预览浮层、悬浮按钮 |

---

## 二、设计令牌（Design Tokens）

### 2.1 莫兰迪色板（示例）

```css
:root {
  /* ===== 页面底色 ===== */
  --bg-1: #E7E2DB;            /* 页面底色上层（暖灰） */
  --bg-2: #E0DAD1;            /* 页面底色下层（渐变） */

  /* ===== 表面色（组件/卡片基色，必须与 --bg-1 一致） ===== */
  --surface: #E7E2DB;

  /* ===== 阴影色 ===== */
  --shadow-dk: rgba(146, 136, 124, .62);   /* 右下浮雕暗影 */
  --shadow-lt: rgba(255, 255, 255, .95);   /* 左上高光 */

  /* ===== 文字色 ===== */
  --ink-1: #4B4540;           /* 主文字（高对比度） */
  --ink-2: #8C847B;           /* 次要文字 */

  /* ===== 强调色 ===== */
  --accent: #9AAB9E;          /* 莫兰迪鼠尾草绿 */
  --accent-deep: #7D8F81;     /* 强调深 */
  --accent-soft: rgba(154, 171, 158, .16);

  /* ===== 尺寸 ===== */
  --radius: 22px;             /* 大圆角 */
  --radius-sm: 14px;          /* 小圆角 */
  --pad: 24px;                /* 紧凑间距 */
}
```

### 2.2 阴影公式速查

```
标准凸起（Convex）:
  box-shadow: 6px 6px 14px var(--shadow-dk), -6px -6px 14px var(--shadow-lt);

标准凹陷（Concave）:
  box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px var(--shadow-lt);

改良悬浮（仅暗色投影）:
  box-shadow: 0 8px 20px rgba(146, 136, 124, .45);
```

### 2.3 阴影参数调优指南

| 参数 | 小尺寸组件（< 48px） | 中尺寸组件（48-80px） | 大尺寸卡片（> 80px） |
|------|---------------------|----------------------|---------------------|
| 偏移量 | 3-4px | 5-6px | 6-8px |
| 模糊半径 | 8-10px | 12-14px | 14-20px |
| 暗色透明度 | .45-.55 | .55-.65 | .60-.70 |
| 高光透明度 | .85-.95 | .90-.98 | .92-1.0 |

---

## 三、标准纯色新拟态（基础规范）

### 3.1 视觉规范

- 无 border 边框，纯阴影界定组件边界
- 大圆角设计，适配移动端柔和触控视觉
- 低饱和单色底色系统，少量强调色区分信息层级
- 文字独立高对比度，规避新拟态低对比度的可读性缺陷

### 3.2 工具类

```css
/* 凸起 — 常态、可点击、悬浮 */
.neo-raised {
  background: var(--surface);
  box-shadow: 6px 6px 14px var(--shadow-dk), -6px -6px 14px var(--shadow-lt);
}

/* 凹陷 — 激活、选中、输入嵌入 */
.neo-flat {
  background: var(--surface);
  box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px var(--shadow-lt);
}

/* 强调凸起 — 用于 chip、标签等小元素 */
.neo-chip {
  background: linear-gradient(145deg, var(--bg-1), var(--bg-2));
  box-shadow: 5px 5px 12px var(--shadow-dk), -5px -5px 12px var(--shadow-lt);
}
```

### 3.3 组件模板

#### 按钮

```css
.neo-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;          /* 触控热区 ≥ 44px */
  padding: 0 24px;
  border-radius: 999px;      /* 胶囊形 */
  border: none;
  background: var(--surface);
  color: var(--accent-deep);
  font-weight: 700;
  cursor: pointer;
  box-shadow: 5px 5px 12px var(--shadow-dk), -5px -5px 12px var(--shadow-lt);
  transition: box-shadow .15s ease;
}
.neo-btn:active {
  box-shadow: inset 3px 3px 8px var(--shadow-dk), inset -3px -3px 8px var(--shadow-lt);
}
```

#### 圆形 FAB 按钮

```css
.neo-fab {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  border: none;
  background: var(--surface);
  color: var(--accent-deep);
  display: grid;
  place-items: center;
  cursor: pointer;
  box-shadow: 6px 6px 14px var(--shadow-dk), -6px -6px 14px var(--shadow-lt);
}
.neo-fab:active {
  box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px var(--shadow-lt);
}
```

#### 输入框

```css
.neo-input {
  width: 100%;
  min-height: 48px;
  padding: 0 18px;
  border: none;
  border-radius: 14px;
  background: var(--surface);
  color: var(--ink-1);
  font-family: inherit;
  box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px var(--shadow-lt);
  outline: none;
}
.neo-input::placeholder {
  color: var(--ink-2);
}
```

#### 开关（Toggle）

```css
.neo-switch {
  width: 56px;
  height: 32px;
  border-radius: 99px;
  background: var(--surface);
  box-shadow: inset 3px 3px 7px var(--shadow-dk), inset -3px -3px 7px var(--shadow-lt);
  position: relative;
  cursor: pointer;
}
.neo-switch::after {
  content: "";
  position: absolute;
  top: 3px;
  left: 3px;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: var(--surface);
  box-shadow: 2px 2px 5px var(--shadow-dk), -1px -1px 3px var(--shadow-lt);
  transition: all .18s ease;
}
.neo-switch.on::after {
  left: calc(100% - 29px);
}
.neo-switch.on {
  background: var(--accent);
  box-shadow: inset 2px 2px 5px rgba(0, 0, 0, .12);
}
```

#### 进度条

```css
.neo-progress-track {
  height: 8px;
  border-radius: 99px;
  background: var(--surface);
  box-shadow: inset 2px 2px 5px var(--shadow-dk), inset -2px -2px 5px var(--shadow-lt);
}
.neo-progress-fill {
  height: 100%;
  border-radius: 99px;
  background: var(--accent);
}
```

#### 卡片容器

```css
.neo-card {
  background: var(--surface);
  border-radius: var(--radius);
  padding: 22px;
  box-shadow: 6px 6px 14px var(--shadow-dk), -6px -6px 14px var(--shadow-lt);
}
```

#### 分段控制器

```css
.neo-segment {
  display: flex;
  background: var(--surface);
  border-radius: 999px;
  padding: 4px;
  box-shadow: inset 3px 3px 7px var(--shadow-dk), inset -3px -3px 7px var(--shadow-lt);
}
.neo-segment-item {
  flex: 1;
  padding: 8px 16px;
  border-radius: 999px;
  text-align: center;
  font-size: 13px;
  font-weight: 700;
  color: var(--ink-2);
  cursor: pointer;
  transition: all .18s ease;
}
.neo-segment-item.active {
  background: var(--surface);
  color: var(--accent-deep);
  box-shadow: 3px 3px 7px var(--shadow-dk), -3px -3px 7px var(--shadow-lt);
}
```

---

## 四、改良悬浮新拟态（图像/动态画面适配）

### 4.1 适用场景

相机实时预览、图片背景、视频图层、动态内容界面（相机类、可视化工具类 App 核心场景）

### 4.2 解决痛点

传统新拟态纯白高光、内嵌阴影在图像背景中会出现脏边、断层、光影错乱问题，无法适配动态画面。

### 4.3 改良设计逻辑

摒弃"同源材质雕刻"，改为**独立柔性材质悬浮叠加**，组件浮于画面上层，兼顾拟物质感与画面可读性。

### 4.4 核心改造规则

| 规则 | 说明 |
|------|------|
| 取消纯白高光 | 全程使用暗色投影，避免画面脏边干扰 |
| 半透明底色 | 不遮挡底层图片、视频画面内容 |
| backdrop-filter 模糊 | 实现图层隔离，强化悬浮质感 |
| 禁用 inset 内嵌阴影 | 规避动态画面光影错乱问题 |
| 按压反馈用 scale 缩放 | 交互更稳定、贴合移动端触控逻辑 |

### 4.5 组件模板

#### 悬浮按钮（图片中央）

```css
.float-btn {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  display: inline-flex;
  align-items: center;
  gap: 10px;
  height: 54px;
  padding: 0 28px;
  border-radius: 999px;
  border: none;
  background: rgba(231, 226, 219, .72);      /* 半透明底色 */
  backdrop-filter: blur(8px);                 /* 毛玻璃隔离 */
  -webkit-backdrop-filter: blur(8px);
  color: var(--accent-deep);
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 8px 20px rgba(146, 136, 124, .45);  /* 仅暗色投影 */
  transition: transform .15s ease;
}
.float-btn:active {
  transform: translate(-50%, -50%) scale(.92);  /* 按压缩放，禁用 inset */
}
```

#### 悬浮圆形按钮（图片角落）

```css
.float-circle-btn {
  position: absolute;
  right: 14px;
  top: 42px;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: none;
  background: rgba(231, 226, 219, .72);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  color: var(--accent-deep);
  display: grid;
  place-items: center;
  cursor: pointer;
  box-shadow: 0 6px 16px rgba(146, 136, 124, .4);
  transition: transform .15s ease;
}
.float-circle-btn:active {
  transform: scale(.88);
}
```

#### 悬浮面板（图片上方信息层）

```css
.float-panel {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  width: 82%;
  max-width: 360px;
  padding: 24px;
  border-radius: 20px;
  background: rgba(231, 226, 219, .78);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  box-shadow: 0 10px 30px rgba(146, 136, 124, .35);
}
```

### 4.6 核心业务组件

- 相机快门按钮
- 悬浮参数调节面板
- 滤镜选择器
- 顶部状态栏控件
- 底部模式切换栏
- 图片预览浮层
- 收藏/点赞悬浮按钮

---

## 五、移动端交互规范

- 适配移动端交互逻辑，**舍弃桌面端 hover 效果**，仅保留 active 按压反馈
- 所有可交互组件触控热区 **≥ 44px**，符合移动端设计规范
- 状态统一语义：未选中凸起、选中/激活凹陷（标准场景）
- 改良悬浮场景：禁用凹陷态，改用 scale 缩放反馈
- 过渡动画时长控制在 **120-180ms**，避免拖沓

---

## 六、主题切换方案

通过 CSS 变量实现主题色全局切换，所有组件自动跟随：

```css
/* 切换强调色时，只需更新以下变量 */
:root {
  --accent: #9AAB9E;          /* 鼠尾草绿 */
  --accent-deep: #7D8F81;
  --accent-soft: rgba(154, 171, 158, .16);
}

/* 其他预设色板 */
/* 玫瑰: --accent:#C09A94; --accent-deep:#A87B73; */
/* 雾蓝: --accent:#93A7BF; --accent-deep:#7189A6; */
/* 沙金: --accent:#C2A878; --accent-deep:#A88F5E; */
```

---

## 七、设计禁忌 & 避坑准则

| 禁忌 | 原因 | 替代方案 |
|------|------|----------|
| 高密度信息页面全局使用新拟态 | 层级模糊、可读性不足 | 局部质感点缀，核心组件强化 |
| 多层嵌套凹凸阴影 | 移动端渲染臃肿、边缘模糊 | 单层阴影，保持干净 |
| 图片/动态画面中使用标准 inset 凹陷 | 光影错乱、显脏 | 改用改良悬浮方案 |
| 文字跟随组件低饱和色调 | 可读性不足 | 文字始终高对比度 |
| 在图片上方使用纯白高光阴影 | 与照片色调冲突，显脏 | 仅用暗色投影 + 半透明底 |
| 混合不同 UI 风格 | 视觉混乱 | 全站统一新拟态语言 |

---

## 八、场景决策树

```
用户需要新拟态组件？
├── 组件下方是纯色/渐变背景？
│   └── 使用「标准纯色新拟态」
│       ├── 常态 → .neo-raised（凸起双影）
│       └── 激活 → .neo-flat（凹陷 inset）
│
└── 组件下方是图片/视频/动态画面？
    └── 使用「改良悬浮新拟态」
        ├── 半透明底 rgba(surface, .72)
        ├── backdrop-filter: blur(8px)
        ├── 仅暗色投影（无纯白高光）
        ├── 禁用 inset
        └── 按压用 scale(.92)
```

---

## 九、技能总结

精通 Neumorphism 双轨设计体系，熟练掌握标准纯色雕刻新拟态与图像悬浮改良新拟态设计逻辑。具备完整移动端新拟态组件库搭建能力，熟悉光影原理、材质规范、移动端触控交互规则，可针对性适配工具、相机、极简面板类产品，解决传统新拟态的落地短板，实现轻量化、高适配、高颜值的现代柔和拟物 UI 设计。
