# 如画 Lumira · 东方新拟态主题系统设计

> 文档版本：v1.0
> 创建日期：2026-07-10
> 文档类型：UI 风格升级 + 主题系统实施
> 参考原型：`ruhua-neumorphism/`（东方新拟态原型）
> 参考文档：`2026-07-08-lumira-v2-theme-system-design.md`（v2 主题系统设计）

---

## 0. 概述

### 0.1 目标

将 `ruhua-neumorphism` 原型中的东方新拟态（Oriental Neumorphism）风格集成到 uni-app 项目中，实现：
1. 4 套主题切换（暖米白/浓墨/胶片复古/日系清新），全应用真正生效
2. 新拟态阴影系统（凸起/凹陷/按下/品牌凸起）
3. 设置页与主题选择页新拟态改造
4. 核心页面样式层升级为新拟态风格
5. 完善剩余功能（拍摄引导、模板解锁流程等）

### 0.2 设计原则

| 原则 | 说明 |
|---|---|
| CSS Variables 驱动 | 通过 `data-theme` 属性切换 CSS Variables，运行时零延迟 |
| 样式层改造 | 保留现有页面结构与内容，将卡片/按钮/开关升级为新拟态 |
| 向后兼容 | 保留 `.lumira-card` 等旧类名，内部映射到新拟态变量 |
| H5 优先 | 目标平台为 H5，CSS Variables 原生支持级联 |

---

## 1. 主题 Schema

### 1.1 四套主题颜色规范

来自 `ruhua-neumorphism/colors_and_type.css`：

| Token | 暖米白 (warm) | 浓墨 (ink) | 胶片复古 (retro) | 日系清新 (fresh) |
|-------|--------------|-----------|-----------------|-----------------|
| `--color-canvas` | #FAF7F2 | #1C1A17 | #F5E6D3 | #F8FAF6 |
| `--color-surface` | #FFFFFF | #262320 | #FFF8F0 | #FFFFFF |
| `--color-surface-alt` | #F2EEE6 | #2E2B27 | #EBDAC4 | #EDF2EB |
| `--color-text-primary` | #1A1A1A | #F2EEE6 | #3D2817 | #4A3F35 |
| `--color-text-secondary` | #5C5852 | #A39D94 | #6B4C2F | #8C7F70 |
| `--color-text-tertiary` | #9C9690 | #6E695F | #9C8060 | #B8AEA0 |
| `--color-divider` | #EAE5DC | #3A3630 | #D9C9B3 | #DDE5D8 |
| `--color-brand` | #C9A96E | #D4B57A | #C4956A | #8BAD72 |
| `--color-brand-deep` | #A88550 | #B8985A | #A67B52 | #6E9458 |
| `--color-brand-subtle` | #F5EDDB | #2E2820 | #F0E0C8 | #E8F0E2 |
| `--color-danger` | #B85450 | #D4706C | #A04030 | #C87878 |
| `--color-success` | #7A8B5C | #8FA06A | #6B7B4C | #9AAB7C |

### 1.2 新拟态阴影系统

```css
/* 凸起 — 标准卡片 */
--shadow-convex:         6px 6px 14px #D8D4CC, -6px -6px 14px #FFFFFF;
/* 凸起 — 微妙（小元素） */
--shadow-convex-subtle:  3px 3px 6px #E0DCD4, -3px -3px 6px #FFFFFF;
/* 凸起 — 品牌色 */
--shadow-convex-brand:   4px 4px 10px #B89A5E, -4px -4px 10px #DABB82;
/* 凹陷 — 输入框 */
--shadow-concave:        inset 4px 4px 10px #E0DCD4, inset -4px -4px 10px #FFFFFF;
/* 凹陷 — 微妙 */
--shadow-concave-subtle: inset 2px 2px 5px #E5E0D8, inset -2px -2px 5px #FFFFFF;
/* 按下态 */
--shadow-pressed:        inset 3px 3px 8px #E0DCD4, inset -3px -3px 8px #FFFFFF;
/* 悬浮层 */
--shadow-float:          0 8px 32px rgba(26, 26, 26, 0.08);
```

各主题的阴影暗面色不同（见原型 CSS），通过 `[data-theme]` 覆盖。

---

## 2. 文件结构

```
src/
├── theme/
│   └── theme-configs.ts          # 主题元数据（id/label/desc/colors 预览）
├── stores/
│   └── theme.ts                  # useThemeStore（状态+持久化+切换+跟随系统）
├── App.vue                       # CSS 变量定义 + 全局 neu-* 类
├── uni.scss                      # 保留旧 SCSS 变量（兼容）+ 新增 SCSS→CSS 映射
├── main.ts                       # 导入 theme store
├── components/
│   └── FloatingTabBar.vue        # 新拟态 TabBar 样式
└── pages/
    ├── profile/settings.vue      # 新拟态重做
    └── profile/settings/theme.vue # 真正生效的主题切换
```

---

## 3. 核心实现

### 3.1 App.vue 全局样式

在 `<style>`（非 scoped，纯 CSS）中定义：

1. **`:root`** — warm 默认主题所有 CSS 变量
2. **`[data-theme="ink"]`** — 浓墨覆盖
3. **`[data-theme="retro"]`** — 胶片复古覆盖
4. **`[data-theme="fresh"]`** — 日系清新覆盖
5. **全局新拟态类**：
   - `.neu-card` — 凸起卡片
   - `.neu-inset` — 凹陷区域
   - `.neu-pill` — 凸起药丸（分类标签）
   - `.neu-block` — 小凸起方块（图标容器）
   - `.neu-toggle` — 新拟态开关
   - `.neu-btn-convex` — 凸起按钮
   - `.neu-btn-brand` — 品牌色凸起按钮
6. **向后兼容**：`.lumira-card` 等旧类内部使用 CSS 变量，自动响应主题

### 3.2 theme store

```typescript
// src/stores/theme.ts
type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

export const useThemeStore = defineStore('theme', () => {
  const currentTheme = ref<ThemeId>('warm')
  const followSystem = ref(false)

  function setTheme(id: ThemeId) {
    currentTheme.value = id
    // H5: 设置 data-theme 属性
    document.documentElement.setAttribute('data-theme', id)
    // 持久化
    uni.setStorageSync('theme', id)
  }

  function loadTheme() {
    const saved = uni.getStorageSync('theme') as ThemeId
    if (saved) setTheme(saved)
    else setTheme('warm')
  }

  function setFollowSystem(enabled: boolean) {
    followSystem.value = enabled
    uni.setStorageSync('followSystem', enabled)
    if (enabled) {
      const mq = window.matchMedia('(prefers-color-scheme: dark)')
      setTheme(mq.matches ? 'ink' : 'warm')
    }
  }

  return { currentTheme, followSystem, setTheme, loadTheme, setFollowSystem }
})
```

### 3.3 主题选择页改造

参照 `ruhua-neumorphism/pages/theme.html`：
- 4 张新拟态主题卡（凸起样式）
- 选中态：凹陷 + 金边
- 每张卡含：图标（凸起方块）+ 名称 + 描述 + 4 色彩预览点
- 点击立即调用 `setTheme`，全应用实时响应
- 底部"应用"按钮（品牌色凸起）

### 3.4 设置页改造

参照 `ruhua-neumorphism/pages/settings.html`：
- 分组卡片（凸起）+ 分组标题（大写微小字）
- 每个设置项：凹陷图标容器 + 标题 + 右侧值/箭头
- 新拟态开关（凸起→按下变凹陷，旋钮移到右侧变品牌色）

---

## 4. 页面改造范围

### 4.1 全局自动生效（零改动）

所有使用以下类的页面自动变为新拟态风格：
- `.lumira-card` → 新拟态凸起
- `.floating-tabbar` → 新拟态凸起胶囊
- `.lumira-btn-*` → 新拟态按钮
- `.lumira-tag` → 新拟态小凸起

### 4.2 重点改造页面

| 页面 | 改造内容 |
|------|---------|
| 设置页 | 完整新拟态重做（分组+开关+图标） |
| 主题选择页 | 完整新拟态重做（主题卡+色彩点） |
| 首页 | 卡片类替换为 neu-card，按钮替换为 neu-btn |
| 模板库 | 卡片+分类 pill 替换为新拟态 |
| 挑战页 | 卡片替换为新拟态 |
| 个人中心 | 卡片+菜单列表替换为新拟态 |

---

## 5. 剩余功能完善

参照需求文档，完善以下功能：
- 拍摄页/场景引导：拍摄流程 UI 完善
- 模板详情/解锁：解锁逻辑 + 付费流程 UI
- 整体交互细节补全

---

## 6. 兼容性

- **H5**：CSS Variables 原生支持，`data-theme` 属性切换零延迟
- **SCSS 变量**：保留 `uni.scss` 中的 SCSS 变量供旧代码使用，但其值改为引用 CSS 变量或保持默认色
- **向后兼容**：所有旧类名（`.lumira-*`）继续可用，内部升级为新拟态
