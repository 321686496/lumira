# AtmoE01 氛围感推广短片实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 `lumira-promo-video` Remotion 工程内实现 35s 竖屏推广片《脸不好看怎么出片？氛围感拍照》+ 小红书封面。

**Architecture:** 复用 v2 手绘纸感 MG 体系（Paper/InkPath/Stamp/StickyCap），单文件场景 `src/atmo/AtmoE01.tsx`（仿 `src/replay37/E01.tsx` 的局部组件模式），素材为 AI 生成照片放 `public/atmo/`，Root.tsx 注册 `AtmoE01` 与 `AtmoCover` 两个 composition。

**Tech Stack:** Remotion 4.0.534、React 19、TypeScript；验证用 `npm run lint` + `npx remotion still` 抽帧目检 + 最终 `npx remotion render`。

**Spec:** `docs/superpowers/specs/2026-10-12-atmo-promo-design.md`

## Global Constraints

- 防限流红线：全片不得出现二维码、应用商店标、「下载」字样、点击手势、其他平台名称
- 颜色一律用 `v2/theme` 的 V tokens（paper/ink/inkSoft/gray/gold/goldDeep/red/white），禁止新调色板
- 无静态死图超过 2s（60 帧），每拍必须有 spring/interpolate 运镜
- 文案口语化折中、短句；字幕以 Cap（StickyCap 包装）呈现
- 素材人物一致性：所有 AI 图统一「年轻亚洲女生，齐肩黑发」描述
- Windows PowerShell 环境：命令链用 `;` 不用 `&&`
- 工程目录：`d:\app\projects\photo_post\lumira-promo-video`（若 node_modules 缺失先 `npm ci`）

## 参考实现（必须先读）

- `lumira-promo-video/src/replay37/E01.tsx` —— 竖屏范式：VPolaroid(L20-75)、SparkleBurst(L258-283)、Cap(L286-297)、SFX 数组模式(L301-323)、整体结构
- `lumira-promo-video/src/v2/ink.tsx` —— Paper/InkPath/Stamp/StickyCap/DrawOnImage
- `lumira-promo-video/src/v2/props.tsx` —— ShotClosedEyes/ShotTilted/ShotStiff（P1 废片卡复用）
- `lumira-promo-video/src/Root.tsx` —— 注册方式（L63-86 竖屏 composition 示例）

## 帧表（30fps，总 1050f）

| 帧段 | 拍 | 内容 | Cap / 印章 |
|---|---|---|---|
| 0–90 | P0 钩子 | bad-closeup.png 拍立得急推(scale 1→1.6)抖动 | Cap「脸不好看，怎么出片？」f60–150；红章「脸不好看」 |
| 90–240 | P1 共鸣 | 三张手绘废片卡（ShotClosedEyes/ShotTilted/ShotStiff）f100/150/200 甩入 | Cap「每次拍照都翻车？」f110–230 |
| 240–360 | P2 转折 | 金光一闪 + SparkleBurst，竖排大字「别拍脸，拍氛围」goldInk | 无 Cap |
| 360–460 | P3-藏 | tip-hide.png 拍立得 + 手绘箭头标注 | Cap「侧身藏进光影里」f380–450；金章「藏」 |
| 460–560 | P3-光 | tip-light.png + 光斑手绘圈注 | Cap「让光替你说话」f480–550；金章「光」 |
| 560–660 | P3-远 | tip-far.png + 三分线手绘 | Cap「退远，环境讲故事」f580–650；金章「远」 |
| 660–900 | P4 产品 | DemoPhone：模板列表 f680 → 详情(三分线+剪影+参数 pill) f740 → before/after 擦除对比 f830–900 | Cap「不用学，跟着模板拍就行」f690–880 |
| 900–1050 | P5 CTA | 4 张成片拍立得散落(f910–970 依次弹入) + 金章「如画」+ slogan | Cap「跟着拍，就有氛围感」f940–1040 |

## SFX 表（Audio + Sequence，staticFile）

| 帧 | 音效 | 音量 |
|---|---|---|
| 40 | sfx/shutter.wav | 0.5 |
| 100/150/200 | sfx/pop.wav | 0.32 |
| 250 | sfx/riser.wav | 0.45 |
| 300 | sfx/ding.wav | 0.45 |
| 370/470/570 | sfx/pop.wav | 0.3 |
| 660 | sfx/shutter.wav | 0.5 |
| 680/740/830 | sfx/pop.wav | 0.3 |
| 910/940/955/970 | sfx/pop.wav | 0.28 |
| 1010 | sfx/whoosh.wav | 0.4 |

---

### Task 1: AI 素材生成

**Files:**
- Create: `lumira-promo-video/public/atmo/{bad-closeup,tip-hide,tip-light,tip-far,before,after,wall-1,wall-2,wall-3,wall-4}.png`

**Interfaces:**
- Produces: 10 张 1080 级方形图，供 Task 2–6 的 `<Img src={staticFile('atmo/xxx.png')}>` 引用

- [ ] **Step 1: 生成基础人物图 before.png**

用 GenerateImage，`image_size: "1024x1024"`，path `d:\app\projects\photo_post\lumira-promo-video\public\atmo\before`，prompt：
`[PURPOSE] 短视频素材·普通直闪对照照：年轻亚洲女生，齐肩黑发，站在城市街边，正面平拍，直闪平光，白平衡偏平，无氛围感，生活感手机直出质感，真实摄影`

- [ ] **Step 2: 生成 after.png（引用 before.png 保持同场景同人物）**

GenerateImage 传 `image_paths: [".../atmo/before.png"]`，prompt 说明：同一位女生同一街角同一构图，改为黄昏逆光、暖橙胶片调、光斑、氛围感人像摄影、胶片颗粒。

- [ ] **Step 3: 生成其余 8 张**

统一人物描述「年轻亚洲女生，齐肩黑发」。`bad-closeup`：怼脸大头自拍、表情僵硬、室内惨白顶光、背景杂乱、灰调低饱和。`tip-hide`：逆光侧脸剪影、夕阳金色轮廓光。`tip-light`：窗边自然光、光斑洒在脸上、浅景深。`tip-far`：远景小人物、人物占画面约 1/10、大环境黄昏街道、电影感。`wall-1..4`：四种氛围片（咖啡馆暖光 / 夜晚霓虹光斑 / 花田夕阳逆光 / 雨天窗边剪影）。氛围类统一追加「暖橙胶片调，胶片颗粒，氛围感人像摄影」；`bad-closeup` 用灰调。

- [ ] **Step 4: 目视检查**

逐张打开：人物为同一女生形象、风格统一、无畸形、无文字水印；不合格的重生成。`bad-closeup` 不得猎奇丑化。

- [ ] **Step 5: Commit**

```powershell
git add lumira-promo-video/public/atmo ; git commit -m "assets: AtmoE01 AI 素材图 10 张"
```

### Task 2: Composition 注册 + 基础组件 + P0 钩子

**Files:**
- Create: `lumira-promo-video/src/atmo/AtmoE01.tsx`
- Modify: `lumira-promo-video/src/Root.tsx`

**Interfaces:**
- Consumes: v2/ink 的 Paper/Stamp/InkPath/StickyCap、v2/theme 的 V/FONT2/goldInk、v2/props
- Produces: `AtmoE01` composition（1080×1920@30, 1050f）；局部组件 `VPolaroid({frame,fps,start,w,rotate,children})`、`SparkleBurst({frame,start,cx,cy})`、`Cap({text,frame,fps,start,duration,rotate,highlight})`（三者从 replay37/E01.tsx 对应行原样拷贝）；后续拍以 `{frame >= N && (...)}` 段落式追加

- [ ] **Step 1: 写 AtmoE01 骨架 + P0**

AtmoE01.tsx：`AbsoluteFill` 包 `Paper`；拷入 VPolaroid/SparkleBurst/Cap；P0 段落：f0–90 拍立得内嵌 `Img src={staticFile('atmo/bad-closeup.png')}` objectFit cover，容器 `scale = interpolate(frame,[10,55],[1,1.6],clamp)` + `shake = Math.sin(frame*1.7)*3`，f58–70 opacity 退场；红章 `Stamp text="脸不好看" start={34} size={110} color={V.red} border rotate={-4}`；Cap1。Root.tsx import 并注册：

```tsx
<Composition id="AtmoE01" component={AtmoE01} width={1080} height={1920} fps={FPS} durationInFrames={1050} />
```

- [ ] **Step 2: 验证**

Run: `npm run lint` → 0 error；`npx remotion still AtmoE01 out/check-p0.png --frame=60` → 图中拍立得放大中、红章与字幕可见

- [ ] **Step 3: Commit**

```powershell
git add lumira-promo-video/src/atmo/AtmoE01.tsx lumira-promo-video/src/Root.tsx ; git commit -m "feat(atmo): AtmoE01 骨架 + P0 钩子"
```

### Task 3: P1 共鸣 + P2 转折

**Files:**
- Modify: `lumira-promo-video/src/atmo/AtmoE01.tsx`

**Interfaces:**
- Consumes: Task 2 的 VPolaroid/Cap；v2/props 的 ShotClosedEyes/ShotTilted/ShotStiff；v2/theme goldInk
- Produces: 无（段落追加）

- [ ] **Step 1: P1（90–240）**

三张 700 宽拍立得分别在 f100/150/200 spring 甩入（rotate 交替 ±1.6°），内嵌 `<ShotTilted frame start={104}/>`、`<ShotClosedEyes .../>`、`<ShotStiff .../>`，各自 f+34 后被下一张顶出（opacity interpolate 退场）；Cap2 f110–230。

- [ ] **Step 2: P2（240–360）**

金光层：`AbsoluteFill` 背景 `radial-gradient(circle at 50% 55%, rgba(201,169,110,α) 0%, transparent 62%)`，α 用 interpolate f240–262 [0,0.5] 再 f300+ 回落 0.25；`SparkleBurst start={252} cx={540} cy={880}`；竖排大字：容器 `writingMode:'vertical-rl'`，fontSize 130、fontWeight 900、goldInk，两个词「别拍脸」「拍氛围」分两列 spring 弹入 f260/280，f330–355 微上浮退场。

- [ ] **Step 3: 验证 + Commit**

`npm run lint`；`npx remotion still AtmoE01 out/check-p1.png --frame=160`、`out/check-p2.png --frame=300` → P1 三卡与字幕可见 / P2 金光+竖排金字可见

```powershell
git add lumira-promo-video/src/atmo/AtmoE01.tsx ; git commit -m "feat(atmo): P1 共鸣 + P2 转折"
```

### Task 4: P3 三招（360–660）

**Files:**
- Modify: `lumira-promo-video/src/atmo/AtmoE01.tsx`

**Interfaces:**
- Consumes: Task 2 组件；素材 tip-hide/tip-light/tip-far.png
- Produces: 局部组件 `TipCard({frame,fps,start,img,label,annotations})` —— 860 宽拍立得 + 手绘 InkPath 标注 + 金章

- [ ] **Step 1: 写 TipCard 并接三段**

TipCard：拍立得内嵌 AI 图；InkPath 手绘标注——藏：沿人物轮廓画强调线 + 箭头指向剪影；光：光斑处画圆圈 + 短射线；远：画三分线(dash="0.03 0.04") + 交点金色呼吸光点(仿 replay37 TemplatePhone L226)；金章 `Stamp text="藏"|"光"|"远" size={96} color={V.goldDeep}` 右上角 rotate。三段各 100f：前 10f 上一张退场、f360/460/560 spring 入场，Cap 按帧表。

- [ ] **Step 2: 验证 + Commit**

`npm run lint`；`npx remotion still AtmoE01 out/check-p3a.png --frame=420`、`check-p3b --frame=520`、`check-p3c --frame=620` → 各招图片+标注+金章+字幕齐备

```powershell
git add lumira-promo-video/src/atmo/AtmoE01.tsx ; git commit -m "feat(atmo): P3 氛围感三招"
```

### Task 5: P4 产品演示（660–900）

**Files:**
- Modify: `lumira-promo-video/src/atmo/AtmoE01.tsx`

**Interfaces:**
- Consumes: Task 2 组件；v2/ink InkPath
- Produces: 局部组件 `DemoPhone({frame,start,fps})`、`BeforeAfter({frame,start})`

- [ ] **Step 1: DemoPhone（660–830）**

430×860 白底墨框圆角手机（仿 replay37 TemplatePhone L181-255，居中 top 500 spring 入场 rotate 1.5°）。屏内三幕：①f680–740 模板库列表（3 行卡片：缩略色块 + 「黄昏逆光」「窗边光斑」「街角远景」文字 + ambience 小标签）；②f740–830 模板详情：三分线 InkPath + 人物剪影(右下交点) + 参数 pill `['构图·三分线','姿势·侧身','场景·黄昏']` 金框依次弹入；③f830–900 BeforeAfter。

- [ ] **Step 2: BeforeAfter（830–900）**

同尺寸圆角容器内叠两层 Img：底层 after.png，上层 before.png 以 `clipPath: inset(0 ${100 - p}% 0 0)` 露出，p = interpolate(frame,[830,880],[100,0],clamp) 模拟左→右擦除；分隔竖线 3px V.ink 随 p 移动；f880 停在 after 全露 + 金章「出片」。

- [ ] **Step 3: 验证 + Commit**

`npm run lint`；`npx remotion still AtmoE01 out/check-p4a.png --frame=700`、`check-p4b --frame=790`、`check-p4c --frame=890` → 列表/详情三分线+剪影+pill/擦除对比各自正确

```powershell
git add lumira-promo-video/src/atmo/AtmoE01.tsx ; git commit -m "feat(atmo): P4 产品演示"
```

### Task 6: P5 CTA + 全片 SFX（900–1050）

**Files:**
- Modify: `lumira-promo-video/src/atmo/AtmoE01.tsx`

**Interfaces:**
- Consumes: Task 2 组件；素材 wall-1..4.png；Task 3–5 的段落（确保拍间退场衔接）
- Produces: 完整 1050f 正片

- [ ] **Step 1: P5（900–1050）**

4 张 480 宽拍立得 f910/925/940/955 spring 弹入散落（位置左上/右上/左下/右下，rotate ±3–8°），内嵌 wall-1..4.png；中央偏下金章 `Stamp text="如画" size={150} color={V.goldDeep} border` f970 + 下方 slogan 文字「跟着拍，就有氛围感」fontSize 44 inkSoft f990 弹入；Cap7 f940–1040。**终帧审查：无二维码/商店标/「下载」字样/手势/他平台名。**

- [ ] **Step 2: 全片 SFX**

按帧表以 `SFX.map(...)` + `Sequence`+`Audio`+`staticFile` 接入（仿 replay37 L301-323/L540-544）。

- [ ] **Step 3: 全片抽帧目检 + Commit**

`npx remotion still AtmoE01 out/check-p5.png --frame=1000`；再抽 f20/120/280/400/700/1000 六帧确认拍间无穿帮、无静态死图

```powershell
git add lumira-promo-video/src/atmo/AtmoE01.tsx ; git commit -m "feat(atmo): P5 CTA + 全片音效"
```

### Task 7: 小红书封面 AtmoCover

**Files:**
- Create: `lumira-promo-video/src/atmo/AtmoCover.tsx`
- Modify: `lumira-promo-video/src/Root.tsx`

**Interfaces:**
- Consumes: v2/ink Paper/Stamp、v2/theme V/goldInk、素材 tip-hide/tip-light/tip-far.png
- Produces: `AtmoCover` composition（1080×1440@30, 30f，静帧设计）

- [ ] **Step 1: 封面布局**

Paper 底；顶部大字两行「氛围感」「三招」goldInk fontSize 150/190 spring 弹入；中部三张 300 宽拍立得横排微旋转（tip-hide/tip-light/tip-far），下方各标「藏」「光」「远」金章；底部小字「脸不好看怎么出片」inkSoft。Root.tsx 注册 30f。

- [ ] **Step 2: 验证 + Commit**

`npm run lint`；`npx remotion still AtmoCover out/atmo-cover.png --frame=29` → 三联+标题完整不溢出

```powershell
git add lumira-promo-video/src/atmo/AtmoCover.tsx lumira-promo-video/src/Root.tsx ; git commit -m "feat(atmo): 小红书封面 AtmoCover"
```

### Task 8: 终渲染与验收

**Files:**
- Create: `lumira-promo-video/out/atmo-e01.mp4`（不入库，out/ 已 ignore 则跳过 commit）

- [ ] **Step 1: 渲染**

Run: `npx remotion render AtmoE01 out/atmo-e01.mp4`（首次若提示浏览器缺失先 `npx remotion browser ensure`）；`npx remotion still AtmoCover out/atmo-cover.png --frame=29`

- [ ] **Step 2: 验收清单（对照 spec §7）**

lint 0 error；播放 mp4 全片 35s；0–3s 有急推+大字；f8s 色调突变；无静态死图>2s；终帧零导流元素；P4 演示与 app 真实链路一致（模板→引导→出片）；封面图完整。

- [ ] **Step 3: 收尾**

向用户报告产物路径 `lumira-promo-video/out/atmo-e01.mp4`、`out/atmo-cover.png`；提示 slogan 为占位可替换；发布侧转化（抖音蓝 V 应用锚点/小红书报备组件+置顶评论）由用户操作。
