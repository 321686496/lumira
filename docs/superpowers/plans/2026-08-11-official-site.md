# 如画 Lumira 官网落地页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在项目根创建 `official-site/` 独立静态目录，构建如画 Lumira App 的官方网站落地页（9 区块单页长滚动，桌面优先 + 移动端适配）。

**Architecture:** 纯静态 HTML + CSS + JS，无构建步骤。一页 9 个区块，顶部粘性导航锚点，滚动淡入动效。所有视觉严格遵循品牌文档（米白暖金墨配色、衬线标题、1px 边框卡片、无渐变无重影）。

**Tech Stack:** HTML5 + CSS3 + 原生 JS（IntersectionObserver 滚动动效），Google Fonts（Noto Serif SC + Noto Sans SC），Phosphor Icons（CDN），picsum.photos（图片）

## Global Constraints

- 严格使用品牌色板：背景 `#FAF7F2`、卡片 `#FFFFFF`、主文字 `#1A1A1A`、品牌 `#C9A96E`（仅 CTA/点缀）、分隔线 `#EAE5DC`
- 禁用渐变背景、禁用 `box-shadow` 重阴影、禁用纯黑文字（用 `#1A1A1A`）
- 字体：中文标题 Noto Serif SC（衬线，字距 -0.02em ~ -0.03em），中文正文 Noto Sans SC；禁用 Inter / Roboto / Open Sans
- Google Fonts 通过 `<link>` 引入，不用 `@import`
- 卡片：1px 边框 `#EAE5DC`，圆角 12px，无阴影
- 按钮：主按钮暖金底白字圆角 6px；次按钮 1px 暖金描边
- 间距：8px 栅格，页面边距 24-32px，区块间距 64px+
- 图片：`https://picsum.photos/seed/<seed>/<w>/<h>`
- 图标：Phosphor Icons（CDN 引入）
- 动效：仅 `transform` 与 `opacity`，`fill-mode: both`
- 文案：禁用 AI 套话（"无缝"/"提升"/"释放"/"下一代"/"颠覆"）
- 下载链接：暂用占位 `#`
- 响应式：桌面内容容器 `max-width: 1200px`，移动端单列堆叠

---

### Task 1: 目录结构与基础骨架

**Files:**
- Create: `official-site/index.html`
- Create: `official-site/css/style.css`
- Create: `official-site/js/main.js`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p official-site/css official-site/js
```

- [ ] **Step 2: 编写 `index.html` 骨架**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>如画 Lumira · 如你所见，皆成画卷</title>
  <meta name="description" content="如画 Lumira — 完全离线的随身摄影工具。内置拍摄模板，构图叠图、姿势引导、参数预设、后期调优，让普通人拍出专业级好照片。">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@400;500;600;700&family=Noto+Sans+SC:wght@300;400;500;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css">
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <div id="app">
    <!-- ① Nav -->
    <!-- ② Hero -->
    <!-- ③ Pain Points -->
    <!-- ④ Core Features -->
    <!-- ⑤ Template Showcase -->
    <!-- ⑥ Workflow -->
    <!-- ⑦ Offline Privacy -->
    <!-- ⑧ Download CTA -->
    <!-- ⑨ Footer -->
  </div>
  <script src="js/main.js"></script>
</body>
</html>
```

- [ ] **Step 3: 编写 `style.css` 基础层**

CSS 变量 + reset + 原子工具类 + 动效类：

```css
/* ========== CSS Variables ========== */
:root {
  --color-bg: #FAF7F2;
  --color-card: #FFFFFF;
  --color-surface: #F2EEE6;
  --color-text-primary: #1A1A1A;
  --color-text-secondary: #5C5852;
  --color-text-tertiary: #9C9690;
  --color-border: #EAE5DC;
  --color-brand: #C9A96E;
  --color-brand-hover: #A88550;
  --color-brand-light: #F5EDDB;
  --font-serif: 'Noto Serif SC', serif;
  --font-sans: 'Noto Sans SC', sans-serif;
  --container-max: 1200px;
  --spacing-section: 96px;
  --spacing-block: 64px;
  --radius-card: 12px;
  --radius-btn: 6px;
}

/* ========== Reset ========== */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  font-family: var(--font-sans);
  background: var(--color-bg);
  color: var(--color-text-primary);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}
a { color: inherit; text-decoration: none; }
img { max-width: 100%; display: block; }

/* ========== Container ========== */
.container {
  max-width: var(--container-max);
  margin: 0 auto;
  padding: 0 32px;
}

/* ========== Utility ========== */
.section { padding: var(--spacing-section) 0; }
.section-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-brand);
  margin-bottom: 12px;
}
.section-title {
  font-family: var(--font-serif);
  font-size: 32px;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
  margin-bottom: 16px;
}
.section-subtitle {
  font-size: 15px;
  color: var(--color-text-secondary);
  max-width: 520px;
  line-height: 1.7;
}

/* ========== Cards ========== */
.card {
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: 32px;
}

/* ========== Buttons ========== */
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: var(--color-brand);
  color: #fff;
  border: none;
  border-radius: var(--radius-btn);
  padding: 14px 28px;
  font-family: var(--font-sans);
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, transform 0.1s;
}
.btn-primary:hover { background: var(--color-brand-hover); }
.btn-primary:active { transform: scale(0.98); }

.btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: transparent;
  color: var(--color-brand);
  border: 1px solid var(--color-brand);
  border-radius: var(--radius-btn);
  padding: 14px 28px;
  font-family: var(--font-sans);
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, transform 0.1s;
}
.btn-outline:hover { background: var(--color-brand-light); }
.btn-outline:active { transform: scale(0.98); }

/* ========== Animations ========== */
.reveal {
  opacity: 0;
  transform: translateY(16px);
  transition: opacity 0.5s ease, transform 0.5s ease;
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}
```

---

### Task 2: 顶部导航栏

**Files:**
- Modify: `official-site/index.html`（插入 Nav 区）
- Modify: `official-site/css/style.css`（追加 Nav 样式）

- [ ] **Step 1: 在 `index.html` 的 `#app` 内插入 Nav**

```html
<!-- ① 顶部导航 -->
<nav class="site-nav">
  <div class="container nav-inner">
    <a href="#" class="nav-logo">
      <img src="../assets/logos/lumira/logo-lumira-symbol.svg" alt="如画" class="nav-logo-icon">
      <span class="nav-logo-text">Lumira</span>
    </a>
    <div class="nav-links">
      <a href="#features">功能</a>
      <a href="#templates">模板</a>
      <a href="#workflow">流程</a>
      <a href="#download">下载</a>
    </div>
    <a href="#download" class="btn-primary nav-cta">立即下载</a>
  </div>
</nav>
```

- [ ] **Step 2: 追加 Nav CSS**

```css
/* ========== Nav ========== */
.site-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(250, 247, 242, 0.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--color-border);
}
.nav-inner {
  display: flex;
  align-items: center;
  height: 64px;
  gap: 40px;
}
.nav-logo {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.nav-logo-icon { width: 28px; height: 28px; }
.nav-logo-text {
  font-family: var(--font-serif);
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}
.nav-links {
  display: flex;
  align-items: center;
  gap: 28px;
  flex: 1;
}
.nav-links a {
  font-size: 14px;
  color: var(--color-text-secondary);
  transition: color 0.2s;
}
.nav-links a:hover { color: var(--color-brand); }
.nav-cta {
  padding: 10px 20px;
  font-size: 14px;
  flex-shrink: 0;
}
```

---

### Task 3: Hero 区

**Files:**
- Modify: `official-site/index.html`（插入 Hero 区）
- Modify: `official-site/css/style.css`（追加 Hero 样式）

- [ ] **Step 1: 插入 Hero HTML**

```html
<!-- ② Hero -->
<section class="hero section">
  <div class="container hero-inner">
    <div class="hero-content">
      <p class="hero-label">如画 Lumira</p>
      <h1 class="hero-title">如你所见<br>皆成画卷</h1>
      <p class="hero-desc">不会构图？不会摆姿？不懂参数？<br>打开如画，跟拍即出片。</p>
      <div class="hero-actions">
        <a href="#download" class="btn-primary hero-btn"><i class="ph ph-apple-logo"></i> App Store</a>
        <a href="#download" class="btn-outline hero-btn"><i class="ph ph-robot"></i> 安卓版</a>
        <a href="#download" class="btn-outline hero-btn"><i class="ph ph-device-mobile"></i> 鸿蒙版</a>
      </div>
    </div>
    <div class="hero-visual">
      <div class="hero-phone">
        <img src="https://picsum.photos/seed/lumira-hero/400/600" alt="如画取景器界面">
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: 追加 Hero CSS**

```css
/* ========== Hero ========== */
.hero {
  padding-top: 48px;
  padding-bottom: 96px;
}
.hero-inner {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 64px;
  align-items: center;
}
.hero-content { max-width: 520px; }
.hero-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-brand);
  margin-bottom: 16px;
}
.hero-title {
  font-family: var(--font-serif);
  font-size: 52px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.15;
  color: var(--color-text-primary);
  margin-bottom: 20px;
}
.hero-desc {
  font-size: 16px;
  color: var(--color-text-secondary);
  line-height: 1.8;
  margin-bottom: 32px;
}
.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}
.hero-btn { font-size: 14px; padding: 12px 24px; }
.hero-visual {
  display: flex;
  justify-content: center;
  align-items: center;
}
.hero-phone {
  width: 280px;
  border: 1px solid var(--color-border);
  border-radius: 24px;
  overflow: hidden;
  padding: 8px;
  background: var(--color-card);
}
.hero-phone img {
  width: 100%;
  aspect-ratio: 2/3;
  object-fit: cover;
  border-radius: 16px;
}
```

---

### Task 4: 痛点区

**Files:**
- Modify: `official-site/index.html`（Hero 后插入痛点区）
- Modify: `official-site/css/style.css`（追加痛点样式）

- [ ] **Step 1: 插入痛点区 HTML**

```html
<!-- ③ 痛点 -->
<section class="pain-points section">
  <div class="container">
    <div class="pain-grid">
      <div class="pain-item reveal">
        <div class="pain-icon"><i class="ph ph-frame-corners"></i></div>
        <h3 class="pain-title">不会构图</h3>
        <p class="pain-desc">取景框叠加构图线，主体放哪一目了然</p>
      </div>
      <div class="pain-item reveal">
        <div class="pain-icon"><i class="ph ph-user"></i></div>
        <h3 class="pain-title">不会摆姿</h3>
        <p class="pain-desc">姿势轮廓叠在取景器里，跟着摆就自然</p>
      </div>
      <div class="pain-item reveal">
        <div class="pain-icon"><i class="ph ph-sliders"></i></div>
        <h3 class="pain-title">不懂参数</h3>
        <p class="pain-desc">模板预设好曝光白平衡，一键应用</p>
      </div>
      <div class="pain-item reveal">
        <div class="pain-icon"><i class="ph ph-palette"></i></div>
        <h3 class="pain-title">不会后期</h3>
        <p class="pain-desc">后期参数包自动套用，成片直出</p>
      </div>
    </div>
    <p class="pain-punchline">把专业摄影师的"脑子里的经验"<br>变成你取景框里看得见的引导。</p>
  </div>
</section>
```

- [ ] **Step 2: 追加痛点 CSS**

```css
/* ========== Pain Points ========== */
.pain-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 24px;
  margin-bottom: 48px;
}
.pain-item {
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: 32px 24px;
  text-align: center;
}
.pain-icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: var(--color-brand-light);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  font-size: 22px;
  color: var(--color-brand);
}
.pain-title {
  font-family: var(--font-serif);
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 8px;
}
.pain-desc {
  font-size: 13px;
  color: var(--color-text-secondary);
  line-height: 1.6;
}
.pain-punchline {
  text-align: center;
  font-family: var(--font-serif);
  font-size: 22px;
  font-weight: 500;
  color: var(--color-text-primary);
  line-height: 1.6;
  letter-spacing: -0.01em;
}
```

---

### Task 5: 核心功能区

**Files:**
- Modify: `official-site/index.html`（痛点区后插入功能区）
- Modify: `official-site/css/style.css`（追加功能样式）

- [ ] **Step 1: 插入功能区 HTML**

```html
<!-- ④ 核心功能 -->
<section id="features" class="features section">
  <div class="container">
    <p class="section-label reveal">核心功能</p>
    <h2 class="section-title reveal">打开如画，跟拍即出片</h2>
    <p class="section-subtitle reveal">一个拍摄模板＝构图叠图＋姿势参考＋相机参数＋后期调优包。套用，跟拍，出片。</p>
    <div class="features-grid">
      <div class="feature-card card reveal">
        <div class="feature-icon"><i class="ph ph-frame-corners"></i></div>
        <h3 class="feature-title">构图叠图</h3>
        <p class="feature-desc">三分法、黄金螺旋、引导线……取景器里实时叠加，再也不怕歪构图。</p>
      </div>
      <div class="feature-card card reveal">
        <div class="feature-icon"><i class="ph ph-person-simple"></i></div>
        <h3 class="feature-title">姿势引导</h3>
        <p class="feature-desc">半透明轮廓叠在取景器上，手臂怎么放、脸朝哪，跟着摆就自然。</p>
      </div>
      <div class="feature-card card reveal">
        <div class="feature-icon"><i class="ph ph-camera"></i></div>
        <h3 class="feature-title">参数预设</h3>
        <p class="feature-desc">曝光补偿、ISO、白平衡……模板一键应用，无需理解任何参数含义。</p>
      </div>
      <div class="feature-card card reveal">
        <div class="feature-icon"><i class="ph ph-image-square"></i></div>
        <h3 class="feature-title">后期调优</h3>
        <p class="feature-desc">LUT 滤镜、磨皮、锐化、暗角、颗粒——模板参数包自动套用，成片直出。</p>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: 追加功能 CSS**

```css
/* ========== Features ========== */
.features-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 24px;
  margin-top: 40px;
}
.feature-card { text-align: center; }
.feature-icon {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  background: var(--color-brand-light);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  font-size: 26px;
  color: var(--color-brand);
}
.feature-title {
  font-family: var(--font-serif);
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 8px;
}
.feature-desc {
  font-size: 13px;
  color: var(--color-text-secondary);
  line-height: 1.7;
}
```

---

### Task 6: 模板展示区

**Files:**
- Modify: `official-site/index.html`（功能区后插入模板展示）
- Modify: `official-site/css/style.css`（追加模板展示样式）

- [ ] **Step 1: 插入模板展示 HTML**

```html
<!-- ⑤ 模板展示 -->
<section id="templates" class="templates section">
  <div class="container">
    <p class="section-label reveal">精选模板</p>
    <h2 class="section-title reveal">覆盖日常拍摄场景</h2>
    <p class="section-subtitle reveal">咖啡馆半身、旅行人像、复古胶片、夜景人像……打开即用，持续更新。</p>
    <div class="templates-grid">
      <div class="template-card reveal">
        <div class="template-img">
          <img src="https://picsum.photos/seed/template-cafe/400/600" alt="咖啡馆半身人像">
          <span class="template-tag">人像</span>
        </div>
        <div class="template-info">
          <h3 class="template-name">咖啡馆半身</h3>
          <p class="template-desc">柔和窗光 · 半身构图 · 暖调后期</p>
        </div>
      </div>
      <div class="template-card reveal">
        <div class="template-img">
          <img src="https://picsum.photos/seed/template-travel/400/600" alt="旅行人像">
          <span class="template-tag">人像</span>
        </div>
        <div class="template-info">
          <h3 class="template-name">旅行人像</h3>
          <p class="template-desc">广角构图 · 逆光剪影 · 胶片后期</p>
        </div>
      </div>
      <div class="template-card reveal">
        <div class="template-img">
          <img src="https://picsum.photos/seed/template-film/400/600" alt="复古胶片">
          <span class="template-tag">胶片</span>
        </div>
        <div class="template-info">
          <h3 class="template-name">复古胶片</h3>
          <p class="template-desc">颗粒感 · 暖色温 · 暗角氛围</p>
        </div>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: 追加模板展示 CSS**

```css
/* ========== Templates ========== */
.templates-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
  margin-top: 40px;
}
.template-card {
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  overflow: hidden;
  transition: border-color 0.2s;
}
.template-card:hover { border-color: var(--color-brand); }
.template-img {
  position: relative;
  aspect-ratio: 3/4;
  overflow: hidden;
}
.template-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.template-tag {
  position: absolute;
  top: 12px;
  left: 12px;
  background: var(--color-card);
  color: var(--color-brand);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.04em;
  padding: 4px 10px;
  border-radius: 9999px;
}
.template-info {
  padding: 16px 20px 20px;
}
.template-name {
  font-family: var(--font-serif);
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 4px;
}
.template-desc {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
```

---

### Task 7: 使用流程 + 完全离线 + 下载 CTA + 页脚

**Files:**
- Modify: `official-site/index.html`（模板后插入 ⑥⑦⑧⑨）
- Modify: `official-site/css/style.css`（追加对应样式）

- [ ] **Step 1: 插入使用流程区 HTML**

```html
<!-- ⑥ 使用流程 -->
<section id="workflow" class="workflow section">
  <div class="container">
    <p class="section-label reveal">使用流程</p>
    <h2 class="section-title reveal">三步，拍出好照片</h2>
    <div class="workflow-steps">
      <div class="workflow-step reveal">
        <div class="step-number">01</div>
        <div class="step-icon"><i class="ph ph-magnifying-glass"></i></div>
        <h3 class="step-title">选模板</h3>
        <p class="step-desc">从模板库挑选适合场景的拍摄方案</p>
      </div>
      <div class="workflow-arrow"><i class="ph ph-arrow-right"></i></div>
      <div class="workflow-step reveal">
        <div class="step-number">02</div>
        <div class="step-icon"><i class="ph ph-camera"></i></div>
        <h3 class="step-title">跟拍</h3>
        <p class="step-desc">取景器跟随构图线和姿势轮廓，对齐拍摄</p>
      </div>
      <div class="workflow-arrow"><i class="ph ph-arrow-right"></i></div>
      <div class="workflow-step reveal">
        <div class="step-number">03</div>
        <div class="step-icon"><i class="ph ph-image-check"></i></div>
        <h3 class="step-title">出片</h3>
        <p class="step-desc">一键应用后期参数包，成片直出</p>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: 插入完全离线区 HTML**

```html
<!-- ⑦ 完全离线 -->
<section class="offline section">
  <div class="container">
    <div class="offline-inner">
      <div class="offline-content">
        <p class="section-label">完全离线</p>
        <h2 class="section-title">零网络权限<br>数据不出手机</h2>
        <p class="section-subtitle">如画是一款完全离线的本地工具。无需注册账户、不请求任何网络权限、不上传你的任何照片。所有模板、参数、后期算法都在本地运行。隐私，是底线。</p>
        <ul class="offline-list">
          <li><i class="ph ph-shield-check"></i> 零网络权限声明</li>
          <li><i class="ph ph-cpu"></i> 本地 LUT 滤镜引擎</li>
          <li><i class="ph ph-database"></i> 数据仅存本地文件系统</li>
          <li><i class="ph ph-export"></i> 模板导出分享，不经过服务器</li>
        </ul>
      </div>
      <div class="offline-visual">
        <div class="offline-graphic">
          <i class="ph ph-shield"></i>
        </div>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 3: 插入下载区 HTML**

```html
<!-- ⑧ 下载 CTA -->
<section id="download" class="download section">
  <div class="container">
    <div class="download-card">
      <p class="section-label" style="color: #fff;">立即体验</p>
      <h2 class="download-title">开始拍出好照片</h2>
      <p class="download-desc">免费下载 · 内置精选模板 · 无广告 · 无网络要求</p>
      <div class="download-actions">
        <a href="#" class="btn-download"><i class="ph ph-apple-logo"></i> App Store</a>
        <a href="#" class="btn-download"><i class="ph ph-robot"></i> 安卓版</a>
        <a href="#" class="btn-download"><i class="ph ph-device-mobile"></i> 鸿蒙版</a>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 4: 插入页脚 HTML**

```html
<!-- ⑨ 页脚 -->
<footer class="site-footer">
  <div class="container footer-inner">
    <div class="footer-brand">
      <img src="../assets/logos/lumira/logo-lumira-symbol.svg" alt="如画" class="footer-logo">
      <span class="footer-name">如画 Lumira</span>
    </div>
    <p class="footer-tagline">如你所见，皆成画卷</p>
    <p class="footer-copy">&copy; 2026 如画 Lumira · 备案号待提交</p>
  </div>
</footer>
```

- [ ] **Step 5: 追加所有剩余 CSS**

```css
/* ========== Workflow ========== */
.workflow-steps {
  display: flex;
  align-items: flex-start;
  justify-content: center;
  gap: 24px;
  margin-top: 48px;
}
.workflow-step {
  flex: 1;
  max-width: 280px;
  text-align: center;
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: 40px 24px;
}
.step-number {
  font-family: var(--font-serif);
  font-size: 13px;
  font-weight: 600;
  color: var(--color-brand);
  letter-spacing: 0.06em;
  margin-bottom: 16px;
}
.step-icon {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--color-brand-light);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  font-size: 26px;
  color: var(--color-brand);
}
.step-title {
  font-family: var(--font-serif);
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 8px;
}
.step-desc {
  font-size: 13px;
  color: var(--color-text-secondary);
  line-height: 1.6;
}
.workflow-arrow {
  display: flex;
  align-items: center;
  padding-top: 64px;
  font-size: 24px;
  color: var(--color-text-tertiary);
}

/* ========== Offline ========== */
.offline-inner {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 64px;
  align-items: center;
}
.offline-list {
  list-style: none;
  margin-top: 24px;
}
.offline-list li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--color-text-secondary);
  padding: 8px 0;
  border-bottom: 1px solid var(--color-border);
}
.offline-list li:last-child { border-bottom: none; }
.offline-list li i {
  font-size: 18px;
  color: var(--color-brand);
  flex-shrink: 0;
}
.offline-graphic {
  width: 240px;
  height: 240px;
  border-radius: 50%;
  background: var(--color-brand-light);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
  font-size: 96px;
  color: var(--color-brand);
}

/* ========== Download CTA ========== */
.download-card {
  background: var(--color-text-primary);
  border-radius: var(--radius-card);
  padding: 64px;
  text-align: center;
}
.download-title {
  font-family: var(--font-serif);
  font-size: 36px;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: #fff;
  margin-bottom: 12px;
}
.download-desc {
  font-size: 15px;
  color: var(--color-text-tertiary);
  margin-bottom: 32px;
}
.download-actions {
  display: flex;
  justify-content: center;
  gap: 16px;
  flex-wrap: wrap;
}
.btn-download {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #fff;
  color: var(--color-text-primary);
  border: none;
  border-radius: var(--radius-btn);
  padding: 14px 28px;
  font-family: var(--font-sans);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, transform 0.1s;
}
.btn-download:hover { background: var(--color-brand-light); }
.btn-download:active { transform: scale(0.98); }

/* ========== Footer ========== */
.site-footer {
  border-top: 1px solid var(--color-border);
  padding: 48px 0;
}
.footer-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  text-align: center;
}
.footer-brand {
  display: flex;
  align-items: center;
  gap: 8px;
}
.footer-logo { width: 24px; height: 24px; }
.footer-name {
  font-family: var(--font-serif);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: -0.02em;
}
.footer-tagline {
  font-family: var(--font-serif);
  font-size: 14px;
  color: var(--color-text-tertiary);
  font-style: italic;
}
.footer-copy {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
```

---

### Task 8: 响应式适配

**Files:**
- Modify: `official-site/css/style.css`（追加 `@media` 查询）

- [ ] **Step 1: 追加移动端 `< 768px` 样式**

```css
/* ========== Responsive ========== */
@media (max-width: 768px) {
  .container { padding: 0 20px; }
  .section { padding: 48px 0; }
  .section-title { font-size: 24px; }
  .section-subtitle { font-size: 14px; }

  /* Nav */
  .nav-links { display: none; }
  .nav-cta { padding: 8px 16px; font-size: 13px; }

  /* Hero */
  .hero-inner { grid-template-columns: 1fr; gap: 32px; }
  .hero-title { font-size: 32px; }
  .hero-actions { flex-direction: column; }
  .hero-phone { width: 200px; }

  /* Pain Points */
  .pain-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
  .pain-punchline { font-size: 18px; }

  /* Features */
  .features-grid { grid-template-columns: 1fr; }

  /* Templates */
  .templates-grid { grid-template-columns: 1fr; gap: 16px; }

  /* Workflow */
  .workflow-steps { flex-direction: column; align-items: center; }
  .workflow-arrow { transform: rotate(90deg); padding-top: 0; padding: 8px 0; }

  /* Offline */
  .offline-inner { grid-template-columns: 1fr; gap: 32px; }
  .offline-graphic { width: 160px; height: 160px; font-size: 64px; }

  /* Download */
  .download-card { padding: 40px 20px; }
  .download-title { font-size: 26px; }
  .download-actions { flex-direction: column; align-items: center; }
}
```

---

### Task 9: JavaScript 滚动动效

**Files:**
- Modify: `official-site/js/main.js`

- [ ] **Step 1: 使用 IntersectionObserver 实现滚动淡入**

```javascript
(function() {
  'use strict';

  // Scroll reveal with IntersectionObserver
  const revealElements = document.querySelectorAll('.reveal');
  if (revealElements.length > 0) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.1,
      rootMargin: '0px 0px -40px 0px'
    });

    revealElements.forEach(el => observer.observe(el));
  }

  // Sticky nav background on scroll
  const nav = document.querySelector('.site-nav');
  if (nav) {
    const observer = new IntersectionObserver(
      ([e]) => {
        nav.style.borderBottomColor = e.isIntersecting
          ? 'transparent'
          : 'var(--color-border)';
      },
      { threshold: [0], rootMargin: '-64px 0px 0px 0px' }
    );
    const hero = document.querySelector('.hero');
    if (hero) observer.observe(hero);
  }
})();
```

---

### Task 10: 最终验证

- [ ] **Step 1: 在浏览器中打开 `official-site/index.html` 逐一检查**

检查清单：
1. 导航栏：LOGO 显示正确，4 个锚点链接可点击，右侧「立即下载」按钮可见
2. Hero 区：大标题展示，副标题，三个下载按钮，手机 Mockup 图片加载
3. 痛点区：4 个卡片均展示，底部金句居中
4. 功能区：4 个卡片排列，2×2 网格
5. 模板区：3 个模板卡片，图片加载，标签可见
6. 流程区：3 步骤 + 箭头，水平排列
7. 离线区：左侧文案 + 列表，右侧圆形图标
8. 下载区：深色背景 CTA，3 个白色按钮
9. 页脚：LOGO 文字 + 版权
10. 缩小浏览器到 480px 以下，验证移动端布局
11. 页面滚动时，区块淡入动效生效