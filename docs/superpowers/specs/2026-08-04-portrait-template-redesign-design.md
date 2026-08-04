# 人像拍照模板重构设计规范

| 字段 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 创建日期 | 2026-08-04 |
| 状态 | 待评审 |
| 适用工程 | lumira_app_flutter（主开发）+ lumira-app（参考实现） |
| 涵盖范围 | 17 款人像拍照模板的完整定义 + 设计规范 + AI 生成输入规范 |
| 后续依赖 | AI 大模型封面图生成脚本、AI 剪影生成脚本、底层算法重构（下一轮） |

---

## 目录

1. [背景与问题诊断](#1-背景与问题诊断)
2. [设计哲学与原则](#2-设计哲学与原则)
3. [风格分类体系](#3-风格分类体系)
4. [参数校准规则](#4-参数校准规则)
5. [AI 生成输入规范](#5-ai-生成输入规范)
6. [17 款模板完整定义](#6-17-款模板完整定义)
7. [避坑指南与自检清单](#7-避坑指南与自检清单)
8. [附录：调研依据](#8-附录调研依据)

---

## 1. 背景与问题诊断

### 1.1 现状

如画（Lumira）以拍照模板为核心卖点，当前内置 12 套模板（8 免费 + 4 付费）。用户反馈：**套用模板拍出的照片比原图更丑**。

### 1.2 根因诊断

经代码审计，当前模板存在 11 类问题，归为三层：

**参数层（本规范重点解决）**

| 问题编号 | 描述 | 典型案例 |
|---|---|---|
| P-1 | 同方向强化手段三重叠加，导致对比失控 | street_bw：contrast+35 + LUT bw(contrast 1.1) + sharpen 40 |
| P-2 | WB 与 postProcess.temperature 方向冲突或过冷过暖 | night_cityscape：WB tungsten(冷) + temperature-10(冷) 叠加过冷 |
| P-3 | ISO 亮度修正与 EV 叠加导致过曝 | cafe_portrait：EV+0.3 + brightness+5 实际过曝 |
| P-4 | 颗粒强度过高且固定随机种子 | film_vintage：grain=40 + 固定种子 42 |
| P-5 | 磨皮强度过高毁掉人像细节 | soft_portrait：smoothStrength=40 全图模糊 |
| P-6 | sharpen 过强产生白边光晕 | macro_flower/street_bw：sharpen=40 |

**剪影层（本规范提供 AI 生成规范，迁移实现留下一轮）**

| 问题编号 | 描述 |
|---|---|
| S-1 | Flutter 版剪影为 `Icon(Icons.person_outline)` 占位符，12 个 SVG 剪影未迁移 |
| S-2 | SVG 解析器仅支持 M/L 命令，不支持 C 贝塞尔曲线 |

**算法层（本规范不涉及，留待下一轮按本规范分阶段实现）**

| 问题编号 | 描述 |
|---|---|
| A-1 | LUT 用 4×5 ColorMatrix 线性近似，丢失胶片非线性质感 |
| A-2 | 磨皮为全图统一高斯模糊，不区分皮肤/眼睛/背景 |
| A-3 | 所见即所得存在色彩空间差异（GPU 管线与 worker Isolate 不一致） |

### 1.3 本规范的目标

- 建立模板设计的完整规范体系，作为后续所有模板工作的单一事实来源
- 重新定义 17 款人像模板的完整参数，使套用后照片比原图更好看
- 为 AI 大模型生成封面图和剪影提供结构化输入规范
- 参数层问题（P-1 ~ P-6）在本规范中直接修正；算法层问题（A-1 ~ A-3）留待下一轮按本规范分阶段实现

---

## 2. 设计哲学与原则

### 2.1 核心目标

**让套用模板的照片比原图更好看，而非更丑。** 模板是降低拍照门槛的工具，不是炫技的滤镜堆叠。

### 2.2 三大设计哲学

#### ① 自然不失真（Anti-Plastic）

- 拒绝"塑料假人"：磨皮保留皮肤纹理与五官轮廓，眼睛/睫毛/发丝必须清晰
- 拒绝"滤镜景点"式过度美化：色彩调整幅度可控，不出现明显色偏
- 拒绝"塑料质感"：锐化不产生白边光晕，颗粒不掩盖主体
- 调研依据：用户最大痛点是"滤镜失真严重，想摔手机"

#### ② 单一主调（One Mood）

- 每个模板只表达一种明确的情绪/氛围，不混合冲突风格
- 色温/色调/LUT/饱和度四者方向一致，不出现"暖中带冷"的矛盾
- 对比当前问题：street_bw 同时 contrast+35 + LUT bw(contrast 1.1) + sharpen 40，三种"强化对比"手段叠加导致失控

#### ③ 场景适配（Scene-Aware）

- 参数与场景光线匹配：夜景不强行提亮、逆光不强行压暗、阴天不强行加饱和
- pose 与构图匹配：全身有动线、半身有手部安排、特写有表情指引
- 画幅与主体匹配：人像默认 3:4 / 9:16，竖构图为主

### 2.3 五条硬约束（所有模板必须满足）

| 编号 | 约束 | 阈值 | 反例（当前问题） |
|---|---|---|---|
| C1 | 磨皮强度上限 | ≤30，默认值 ≤20 | soft_portrait=40 全图模糊 |
| C2 | 锐化强度上限 | ≤25，卷积核 a≤0.25 | street_bw=40 白边光晕 |
| C3 | 颗粒强度上限 | ≤25，随机种子每张变化 | film_vintage=40 + 固定种子 42 |
| C4 | 对比度叠加冲突 | 同方向强化手段不超过 2 处 | contrast+35 + LUT contrast + sharpen 三重 |
| C5 | 色温方向一致性 | WB 与 postProcess.temperature 同向，偏差 ≤15 | night_cityscape WB tungsten + temperature-10 过冷 |

### 2.4 设计纪律

- 不在模板层堆砌效果：氛围感由单一主调（LUT 或色温）承担，其余参数做微调
- 所有数值有依据：每个参数值都要能在"风格定位"中找到理由，不凭感觉设值
- 为 AI 生成留接口：pose 和封面图描述需结构化，可直接作为大模型 prompt 输入

---

## 3. 风格分类体系

### 3.1 三层分类（对接现有 schema）

沿用现有 `classification: { type, style, method }` 字段：

- **type**（主体类型）：本次全部为 `portrait`
- **style**（风格）：见下表
- **method**（取景方式）：`close_up`(特写) / `half_body`(半身) / `full_body`(全身) / `seven_body`(七分身)

### 3.2 17 款模板总览（按优先级排序）

| # | 模板名 | ID | 优先级 | style | method | 画幅 | 一句话定位 |
|---|---|---|---|---|---|---|---|
| 1 | CCD 胶片复古 | `ccd_retro_portrait` | P0 | ccd_retro | half_body | 3:4 | 90 年代 CCD 质感，暖黄颗粒，自带柔光磨皮 |
| 2 | 港风夜景人像 | `hk_noir_portrait` | P0 | hk_noir | half_body | 3:4 | 霓虹夜景，暖黄低对比，王家卫式氛围 |
| 3 | 日系小清新 | `japanese_fresh_portrait` | P0 | japanese_fresh | seven_body | 3:4 | 干净清透，低对比空气感，樱花校园 |
| 4 | 奶油治愈风 | `cream_healing_portrait` | P1 | cream_healing | half_body | 3:4 | 奶油橙暖调，海边夕阳，温柔治愈 |
| 5 | 新中式古风 | `chinese_classical_portrait` | P1 | chinese_classical | full_body | 3:4 | 莫兰迪冷调，园林竹林，东方意境 |
| 6 | 法式慵懒高雅 | `french_lazy_portrait` | P1 | french_lazy | half_body | 4:5 | 慵懒倚靠，白床单窗光，颗粒质感 |
| 7 | 莫兰迪高级冷淡 | `morandi_minimal_portrait` | P1 | morandi_minimal | half_body | 4:5 | 低饱和莫兰迪，纯色背景，知性简约 |
| 8 | 室内暗调氛围 | `dark_indoor_portrait` | P2 | dark_indoor | half_body | 3:4 | 咖啡馆暗调，锐化质感，精致高级 |
| 9 | 夜景霓虹人像 | `neon_city_portrait` | P2 | neon_city | half_body | 9:16 | 城市霓虹，青紫冷暖对比，爱乐之城 |
| 10 | 清新淡雅绿 | `fresh_green_portrait` | P2 | fresh_green | full_body | 3:4 | 户外森系露营，净白滤镜，空气感 |
| 11 | Y2K 千禧风 | `y2k_portrait` | P2 | y2k | half_body | 3:4 | 千禧回潮，高饱和闪光，飒爽酷 girl |
| 12 | 动漫温柔青 | `anime_dream_portrait` | P2 | anime_dream | full_body | 3:4 | 宫崎骏感，饱和提亮，晴天草地 |
| 13 | 复古暗夜蓝 | `blue_night_portrait` | P3 | blue_night | seven_body | 3:4 | 逆光天空大海，爱乐之城深色，冷峻浪漫 |
| 14 | 温柔日暮紫 | `purple_dusk_portrait` | P3 | purple_dusk | half_body | 3:4 | 夕阳克莱因蓝，HSL 蓝饱和提升，梦幻 |
| 15 | 探店美食人像 | `foodie_portrait` | P3 | foodie_portrait | half_body | 1:1 | 美食+人物，对角线构图，暖调下午茶 |
| 16 | 甜妹元气少女 | `sweet_girl_portrait` | P3 | sweet_girl | half_body | 3:4 | 高亮暖粉，比心托腮，九宫格甜美 |
| 17 | 知性优雅轻熟女 | `elegant_lady_portrait` | P3 | elegant_lady | seven_body | 4:5 | 莫兰迪淡雅，三分法，成熟大气 |

### 3.3 风格族群关系

- **暖调系**（1/2/4/6/15/16）：以暖黄/奶油橙为主，区分颗粒感与柔光感
- **冷调系**（3/5/7/9/10/13）：以冷青/莫兰迪为主，区分饱和度高低
- **氛围系**（8/12/14）：以光影特效为主，区分室内外
- **风格系**（11/17）：以造型姿态为主，区分年龄气质

---

## 4. 参数校准规则

本规则是所有模板参数设计的硬性约束，直接修正 P-1 ~ P-6 类参数层问题。

### 4.1 三段式参数结构

每个模板的后期参数分为三段，**主效果只选一个承担者**，避免多手段叠加：

| 段位 | 角色 | 承担者 | 幅度 |
|---|---|---|---|
| 第一段：主效果 | 决定模板的核心氛围 | LUT 或 色温(temperature) 二选一为主调 | LUT 全强度 / temperature ±10~±20 |
| 第二段：辅助微调 | 让主效果更自然，不抢戏 | brightness / contrast / saturation / tint | 各项幅度 ≤ ±15，且同方向不超过 2 项 |
| 第三段：质感修饰 | 增加胶片/空气感 | grain / vignette / smoothStrength / sharpen | 遵守 C1-C3 上限 |

### 4.2 各参数合理范围

| 参数 | 范围 | 说明 |
|---|---|---|
| exposureCompensation (EV) | -1.0 ~ +0.7 | 夜景可到 -1.0，人像一般 ±0.3 |
| ISO | 100 ~ 800 | 夜景 800，室内 400，户外 100-200 |
| brightness | -15 ~ +15 | 超出范围说明 EV 设错了 |
| contrast | -15 ~ +15 | 超出范围说明 LUT 选错了 |
| saturation | -25 ~ +20 | 莫兰迪/黑白可到 -25，Y2K 可到 +20 |
| temperature | -20 ~ +20 | 暖调 +10~+20，冷调 -10~-20 |
| tint | -15 ~ +15 | 一般为 0，特殊风格（日暮紫）可到 +15 |
| highlights | -20 ~ +10 | 逆光压高光 -20，平淡提高光 +10 |
| shadows | -10 ~ +20 | 暗调压阴影 -10，清新提阴影 +20 |
| clarity | -10 ~ +15 | 柔光风 -10，质感风 +15 |
| vibrance | -10 ~ +15 | 自然饱和度，保守使用 |
| smoothStrength | 0 ~ 30 | C1 约束，人像默认 15，特写 20 |
| sharpen | 0 ~ 25 | C2 约束，默认 10，质感风 20 |
| vignette | 0 ~ 25 | 暗角，氛围风 20，清新风 0 |
| grain | 0 ~ 25 | C3 约束，胶片风 20，清新风 0 |

### 4.3 叠加冲突检查矩阵（C4 落地）

设计模板时检查以下"同方向叠加"不超过 2 处：

| 叠加维度 | 涉及参数 | 冲突示例 |
|---|---|---|
| 对比度增强 | contrast + LUT内置contrast + sharpen + clarity | street_bw 旧版四重叠加 |
| 暖色调 | temperature + WB暖向 + LUT暖向 + tint+红 | cafe_portrait 旧版三重 |
| 冷色调 | temperature- + WB冷向 + LUT冷向 | night_cityscape 旧版三重 |
| 饱和度提升 | saturation + vibrance + LUT饱和 | Y2K 需控制 |
| 亮度提升 | EV+ + brightness+ + ISO修正 + shadows+ | cafe_portrait 旧版三重 |

**规则**：同一维度内，主动选择的强化手段不超过 2 处；第 3 处必须归零或反向微调平衡。

### 4.4 色温方向一致性检查（C5 落地）

- WB 与 postProcess.temperature 必须同向（同暖或同冷）
- 若 WB 已设为 tungsten(3200K, 冷)，则 temperature 不可再设负值（更冷），最多设 0 或正值微调
- 若 WB 已设为 cloudy(6000K, 暖)，则 temperature 不可设负值（反暖），最多设 +5~+15 同向增强
- 特殊情况：若需要"WB 冷 + 后期暖"的反差效果（如夜景霓虹冷暖对比），temperature 与 WB 方向相反时，temperature 幅度 ≤ ±10

### 4.5 LUT 选择原则

现有 16 种 LUT 预设，按主调归类：

| LUT | 主调方向 | 适用模板 |
|---|---|---|
| none | 无 | 已有足够色温调整的模板 |
| warm_film | 暖黄胶片 | CCD 复古、港风夜景、奶油治愈 |
| cool_film | 冷青胶片 | 霓虹城市、暗夜蓝 |
| vintage | 复古褐黄 | CCD 复古、法式慵懒 |
| cinematic | 电影青橙 | 新中式、暗调氛围、知性优雅 |
| pastel | 柔粉低饱 | 日系清新、清新淡雅绿、甜妹、动漫青 |
| bw | 黑白 | （本批人像不含黑白款） |
| fuji | 富士低饱和高对比 | （预留） |

**规则**：选定 LUT 后，temperature 方向应与 LUT 方向一致或为 0，不可反向抵消 LUT 主调。

---

## 5. AI 生成输入规范

本章定义两个结构化输入格式，供后续 AI 大模型生成脚本使用。

### 5.1 封面图生成 prompt 规范

每个模板提供一个结构化 prompt，格式如下：

```
[风格类型] {风格名} 风格人像照片
[主体] {人物描述：性别/年龄段/服装/发型}
[动作] {pose 一句话描述}
[场景] {背景/环境/道具}
[构图] {画幅比例/人像位置/留白方向}
[光影] {光线方向/光线质感/时间}
[色调] {主色调/对比度/饱和度方向}
[质感] {颗粒/磨皮/锐化方向}
[参考] 小红书/抖音热门 {风格关键词} 教程风格，自然不失真，避免过度滤镜
[画幅] {aspectRatio}
[禁忌] 不要过度磨皮，不要塑料质感，不要失真色偏
```

### 5.2 剪影 pose 结构化描述规范

每个模板提供一个结构化 pose 描述，用于 AI 生成 SVG 剪影或供画师绘制参考：

```yaml
pose_id: {唯一标识}
pose_name: {pose 名称}
body_orientation: {身体朝向：正面/侧身/背影/回眸}
body_posture: {身体姿态：站立/坐姿/倚靠/行走/蹲下}
head_angle: {头部角度：正视/侧脸/低头/仰头/回眸}
gaze_direction: {视线方向：看镜头/看侧方/看远方/闭眼}
hand_action: {手部动作：自然下垂/托腮/叉腰/比心/举杯/遮面/插袋}
leg_posture: {腿部姿态：并拢/交叉/一前一后/蹲/盘腿}
expression: {表情：微笑/沉思/大笑/无表情/俏皮}
clothing_type: {服装类型：日常/裙装/汉服/西装/休闲}
props: {道具：无/咖啡杯/花/扇子/相机/书}
composition_hint: {构图提示：居中/三分位左/三分位右/对角线}
scale_hint: {缩放提示：0.5~1.5，默认 0.8}
svg_drawing_notes: {SVG 绘制要点：突出轮廓的哪些部分，viewBox 建议 0 0 100 200}
```

### 5.3 AI 生成质量要求

- 封面图必须为竖图（3:4 或 9:16 或 4:5），分辨率 ≥ 1080px
- 剪影 SVG 使用 `viewBox="0 0 100 200"`（1:2 人像比例），`fill="currentColor"`
- 剪影需支持贝塞尔曲线（C 命令），绘制流畅轮廓
- 封面图不得出现明显 AI 瑕疵（多余手指、畸形五官、文字水印）

---

## 6. 17 款模板完整定义

> 以下每款模板按统一结构定义。参数值已通过三段式校准和 C1-C5 约束检查。

---

### 模板 1：CCD 胶片复古

| 字段 | 值 |
|---|---|
| ID | `ccd_retro_portrait` |
| 优先级 | P0 |
| 分类 | portrait / ccd_retro / half_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：模拟 90 年代 CCD 数码相机的复古质感，暖黄色调、轻微颗粒、自带柔光磨皮感，拍出"老照片"氛围。当前最火风格，手机厂商（vivo/荣耀）和 App（ProCCD）双重驱动。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.28, y: 0.15, w: 0.45, h: 0.7 }
- 人像位置: 三分线左侧，半身取景，头部位于上三分线
- opacity: 0.3

**pose 结构化描述**：
```yaml
pose_id: ccd_retro_pose
pose_name: 随性侧身回眸
body_orientation: 侧身
body_posture: 站立
head_angle: 回眸
gaze_direction: 看镜头
hand_action: 一手自然下垂，一手轻触发梢
leg_posture: 一前一后，重心后移
expression: 微笑
clothing_type: 日常休闲
props: 无
composition_hint: 三分位左
scale_hint: 0.75
svg_drawing_notes: 侧身站立轮廓，头部回眸转向镜头，一手下垂一手举至耳侧，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: +0.3
- iso: 200
- shutterSpeed: '1/125'
- whiteBalance: cloudy
- whiteBalanceK: 6000
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +8
- contrast: -5
- saturation: +5
- temperature: +15
- tint: 0
- highlights: -10
- shadows: +10
- clarity: -5
- vibrance: +5

**滤镜与质感**：
- lut: vintage
- smoothStrength: 15
- sharpen: 8
- vignette: 15
- grain: 20

**光影场景**：
- lightDirection: 侧顺光
- lightDirectionAngle: 45
- shootingDistance: 1.5-2m
- background: 老街/室内暖光/复古墙面
- props: 无
- bestTime: 下午 15:00-17:00
- bestTimeFrom: '15:00'
- bestTimeTo: '17:00'
- tips: ['利用午后暖光营造复古氛围', '可轻微晃动模拟 CCD 对焦不准', '服装选择纯色或格纹']

**封面图 prompt**：
```
[风格类型] CCD 胶片复古风格人像照片
[主体] 20-25岁女性，自然妆容，穿米色针织衫，黑色长发微卷
[动作] 侧身站立回眸看镜头，一手轻触发梢，微笑
[场景] 复古老街墙面背景，午后暖阳
[构图] 3:4竖图，人像位于三分线左侧，半身取景，右侧留白
[光影] 侧顺光45度，午后暖黄色调，柔和
[色调] 暖黄主调，对比度略降，饱和度微提，复古褐黄
[质感] 轻微颗粒（CCD质感），柔光磨皮保留纹理，轻度锐化
[参考] 小红书热门 CCD 复古拍照教程风格，自然不失真
[画幅] 3:4
[禁忌] 不要过度磨皮，不要塑料质感，不要现代数码清晰感
```

**模板描述**：90 年代 CCD 复古质感，暖黄颗粒自带柔光，拍出老照片的温柔记忆。

**适用场景**：老街、咖啡馆、校园、室内暖光环境。

**避坑指南**：
- 颗粒勿超 25，否则像噪点而非胶片感
- 磨皮勿超 20，CCD 的柔光感来自低像素而非模糊
- 不要叠加 flash，CCD 复古靠环境光

**校准检查**：
- C4 对比度叠加：contrast-5 + LUT vintage(微对比) + sharpen 8 = 1 处增强，合规
- C5 色温方向：WB cloudy(暖) + temperature+15(暖)，同向，合规

---

### 模板 2：港风夜景人像

| 字段 | 值 |
|---|---|
| ID | `hk_noir_portrait` |
| 优先级 | P0 |
| 分类 | portrait / hk_noir / half_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：王家卫电影式港风夜景，霓虹灯下的暖黄低对比氛围，90 年代香港街头浪漫感。夜景人像热门风格，算法一键还原。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 }
- 人像位置: 居中偏左，半身取景
- opacity: 0.3

**pose 结构化描述**：
```yaml
pose_id: hk_noir_pose
pose_name: 倚墙回眸
body_orientation: 侧身
body_posture: 倚靠
head_angle: 回眸
gaze_direction: 看镜头
hand_action: 一手插袋，一手自然垂下
leg_posture: 交叉倚墙
expression: 沉思微怅
clothing_type: 深色外套/风衣
props: 无
composition_hint: 三分位左
scale_hint: 0.75
svg_drawing_notes: 侧身倚墙轮廓，头部回眸，一手插袋，风衣下摆微飘，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.3
- iso: 800
- shutterSpeed: '1/60'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -5
- contrast: +8
- saturation: +5
- temperature: +15
- tint: +5
- highlights: -15
- shadows: +5
- clarity: 0
- vibrance: 0

**滤镜与质感**：
- lut: warm_film
- smoothStrength: 12
- sharpen: 10
- vignette: 20
- grain: 15

**光影场景**：
- lightDirection: 侧光/逆光（霓虹光源）
- lightDirectionAngle: 120
- shootingDistance: 1.5-2m
- background: 霓虹招牌/老街夜景/路灯
- props: 无
- bestTime: 夜晚 19:00-22:00
- bestTimeFrom: '19:00'
- bestTimeTo: '22:00'
- tips: ['利用霓虹灯做侧光光源', '让模特倚靠墙面增加故事感', '选择暖色霓虹招牌做背景虚化']

**封面图 prompt**：
```
[风格类型] 港风夜景复古人像照片
[主体] 25-30岁女性，红唇妆容，穿深色风衣，黑色长发
[动作] 侧身倚靠墙面回眸看镜头，一手插袋，沉思表情
[场景] 香港老街夜景，霓虹招牌暖光虚化背景
[构图] 3:4竖图，人像位于三分线左侧，半身取景
[光影] 霓虹侧光120度，暖黄主光，暗部深沉
[色调] 暖黄低对比，王家卫电影色调，轻微颗粒
[质感] 颗粒15，轻度磨皮保留质感，暗角氛围
[参考] 王家卫电影风格，小红书港风夜景教程
[画幅] 3:4
[禁忌] 不要过亮，不要高饱和现代感，不要冷调
```

**模板描述**：王家卫式港风夜景，霓虹暖黄低对比，街头浪漫故事感。

**适用场景**：霓虹街、老城区夜景、城市夜行。

**避坑指南**：
- ISO 800 已是上限，勿再提亮度，夜景要暗
- temperature+15 与 WB cloudy 同向，勿再加 tint 到 +10 以上
- 暗角勿超 25，否则四角死黑

**校准检查**：
- C4 暖调叠加：temperature+15 + WB cloudy + LUT warm_film = 3 处，超限。调整：WB 改为 daylight(5500K) 中性，让 temperature+15 和 LUT warm_film 承担暖调，共 2 处，合规。**修正后 WB: daylight, whiteBalanceK: 5500**
- C5 色温方向：WB daylight(中性) + temperature+15(暖)，不冲突，合规

---

### 模板 3：日系小清新

| 字段 | 值 |
|---|---|
| ID | `japanese_fresh_portrait` |
| 优先级 | P0 |
| 分类 | portrait / japanese_fresh / seven_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：干净清透、低对比空气感，樱花校园感，日系小清新长青风格。提亮、降对比饱和、色温微冷。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.25, y: 0.1, w: 0.5, h: 0.8 }
- 人像位置: 三分线左侧，七分身取景，留白充足
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: japanese_fresh_pose
pose_name: 自然行走侧脸
body_orientation: 侧身
body_posture: 行走
head_angle: 侧脸
gaze_direction: 看远方
hand_action: 双手自然摆动
leg_posture: 行走迈步
expression: 微笑
clothing_type: 白色衬衫/校服/浅色连衣裙
props: 无
composition_hint: 三分位左
scale_hint: 0.7
svg_drawing_notes: 侧身行走轮廓，迈步动态，长发微飘，裙摆轻摆，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/200'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +12
- contrast: -10
- saturation: -5
- temperature: -5
- tint: 0
- highlights: +5
- shadows: +15
- clarity: -8
- vibrance: +5

**滤镜与质感**：
- lut: pastel
- smoothStrength: 10
- sharpen: 5
- vignette: 0
- grain: 0

**光影场景**：
- lightDirection: 顺光/漫射光
- lightDirectionAngle: 30
- shootingDistance: 2-3m
- background: 樱花树/校园/蓝天白云/草地
- props: 无
- bestTime: 上午 7:00-10:00
- bestTimeFrom: '07:00'
- bestTimeTo: '10:00'
- tips: ['选择阴天或晨光获得柔和光线', '留白要足，人物占比不超过 60%', '服装选择浅色系']

**封面图 prompt**：
```
[风格类型] 日系小清新风格人像照片
[主体] 18-22岁女性，淡妆，穿白色衬衫，黑色长直发
[动作] 侧身自然行走，侧脸看向远方，微笑
[场景] 樱花树下小径，晨光柔和
[构图] 3:4竖图，人像位于三分线左侧，七分身，右侧大量留白
[光影] 顺光晨光30度，柔和漫射，空气感
[色调] 低对比低饱和，微冷色温，明亮通透
[质感] 无颗粒，轻度磨皮，几乎不锐化
[参考] 日系写真风格，小红书小清新教程
[画幅] 3:4
[禁忌] 不要暖调，不要高对比，不要颗粒，不要暗角
```

**模板描述**：干净清透的日系空气感，低对比微冷调，樱花校园的青春记忆。

**适用场景**：樱花季、校园、公园草地、晴天户外。

**避坑指南**：
- 颗粒和暗角必须为 0，清新风不需要质感修饰
- brightness+12 已是上限，勿超 +15
- contrast-10 配合 LUT pastel(低饱)，不要再加 clarity 负值太多

**校准检查**：
- C4 对比度降低：contrast-10 + clarity-8 = 2 处同向，合规
- C4 亮度提升：EV+0.3 + brightness+12 + shadows+15 = 3 处，超限。调整：EV 改为 0，让 brightness+12 和 shadows+15 承担提亮，共 2 处，合规。**修正后 exposureCompensation: 0**

---

### 模板 4：奶油治愈风

| 字段 | 值 |
|---|---|
| ID | `cream_healing_portrait` |
| 优先级 | P1 |
| 分类 | portrait / cream_healing / half_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：奶油橙暖调温柔治愈感，海边夕阳场景，小镰仓滤镜风格。温暖明亮，适合废片拯救。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.65 }
- 人像位置: 居中偏右，半身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: cream_healing_pose
pose_name: 坐姿托腮微笑
body_orientation: 正面
body_posture: 坐姿
head_angle: 微倾
gaze_direction: 看镜头
hand_action: 单手托腮
leg_posture: 盘腿或屈膝坐
expression: 温柔微笑
clothing_type: 米色/奶油色针织或连衣裙
props: 无
composition_hint: 三分位右
scale_hint: 0.75
svg_drawing_notes: 正面坐姿轮廓，单手托腮，头部微倾，裙装下摆自然铺展，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +12
- contrast: -8
- saturation: +5
- temperature: +12
- tint: 0
- highlights: -5
- shadows: +12
- clarity: -5
- vibrance: +5

**滤镜与质感**：
- lut: warm_film
- smoothStrength: 15
- sharpen: 8
- vignette: 5
- grain: 5

**光影场景**：
- lightDirection: 逆光/侧逆光（夕阳）
- lightDirectionAngle: 150
- shootingDistance: 1.5-2m
- background: 海边/夕阳/沙滩/暖色墙面
- props: 无
- bestTime: 下午 16:00-18:00
- bestTimeFrom: '16:00'
- bestTimeTo: '18:00'
- tips: ['利用夕阳逆光营造暖调氛围', '让发丝透光产生金色轮廓光', '服装选择奶油色系']

**封面图 prompt**：
```
[风格类型] 奶油治愈风人像照片
[主体] 20-25岁女性，淡妆，穿米色针织连衣裙，棕色中长发
[动作] 正面坐姿，单手托腮，头部微倾，温柔微笑看镜头
[场景] 海边沙滩，夕阳暖光，背景虚化
[构图] 3:4竖图，人像位于三分线右侧，半身取景
[光影] 夕阳侧逆光150度，金色轮廓光，暖调
[色调] 奶油橙暖调，亮度偏高，对比略降，温柔治愈
[质感] 轻度磨皮，极轻颗粒，无暗角
[参考] 小红书小镰仓滤镜教程，海边夕阳拍照
[画幅] 3:4
[禁忌] 不要冷调，不要高对比，不要暗角过重
```

**模板描述**：奶油橙暖调温柔治愈，夕阳海边氛围感，拯救废片的小镰仓风。

**适用场景**：海边、夕阳、沙滩、暖色室内。

**避坑指南**：
- 暖调叠加检查：temperature+12 + LUT warm_film + tint+5 = 3 处，调整 tint 为 0，保留 2 处，合规。**修正后 tint: 0**
- 颗粒保持 5 以下，治愈风要干净

**校准检查**：
- C4 暖调叠加：temperature+12 + LUT warm_film = 2 处，合规（tint 已归零）
- C4 亮度提升：EV+0.3 + brightness+12 + shadows+12 = 3 处，调整 EV 为 0，合规。**修正后 exposureCompensation: 0**
- C5 色温方向：WB daylight(中性) + temperature+12(暖)，不冲突，合规

---

### 模板 5：新中式古风

| 字段 | 值 |
|---|---|
| ID | `chinese_classical_portrait` |
| 优先级 | P1 |
| 分类 | portrait / chinese_classical / full_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：莫兰迪冷调古风，东方意境园林竹林，国潮稳定热门。侧逆光、压暗、对称构图。

**构图**：
- overlayType: `golden_ratio`
- subjectFrame: { x: 0.35, y: 0.1, w: 0.35, h: 0.8 }
- 人像位置: 黄金分割点，全身取景
- opacity: 0.3

**pose 结构化描述**：
```yaml
pose_id: chinese_classical_pose
pose_name: 扇遮面回眸
body_orientation: 侧身
body_posture: 站立
head_angle: 回眸
gaze_direction: 看镜头
hand_action: 执扇遮面半遮
leg_posture: 并拢微立
expression: 含蓄浅笑
clothing_type: 汉服/新中式裙装
props: 团扇/折扇
composition_hint: 黄金分割
scale_hint: 0.65
svg_drawing_notes: 侧身站立轮廓，执扇至面侧半遮，汉服袖摆垂落，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.3
- iso: 100
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5200
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -5
- contrast: +5
- saturation: -15
- temperature: -10
- tint: 0
- highlights: -10
- shadows: -5
- clarity: 0
- vibrance: -5

**滤镜与质感**：
- lut: cinematic
- smoothStrength: 12
- sharpen: 10
- vignette: 15
- grain: 8

**光影场景**：
- lightDirection: 侧逆光
- lightDirectionAngle: 135
- shootingDistance: 2-3m
- background: 园林/竹林/古建/白墙黛瓦
- props: 团扇/折扇/油纸伞
- bestTime: 上午 8:00-10:00 或下午 15:00-17:00
- bestTimeFrom: '08:00'
- bestTimeTo: '10:00'
- tips: ['侧逆光勾勒人物轮廓', '选择莫兰迪冷调背景（灰墙/竹林）', '服装选低饱和汉服']

**封面图 prompt**：
```
[风格类型] 新中式古风人像照片
[主体] 20-28岁女性，古风妆容，穿浅青色汉服，黑色长发盘发
[动作] 侧身站立执团扇半遮面，回眸看镜头，含蓄浅笑
[场景] 苏州园林白墙黛瓦，竹林背景
[构图] 3:4竖图，人像位于黄金分割点，全身取景
[光影] 侧逆光135度，轮廓光勾勒，莫兰迪冷调
[色调] 低饱和莫兰迪冷调，对比微提，色温偏冷
[质感] 轻度颗粒，轻度磨皮，暗角氛围
[参考] 小红书古风人像教程，莫兰迪冷色调风格
[画幅] 3:4
[禁忌] 不要高饱和，不要暖调，不要过度磨皮
```

**模板描述**：莫兰迪冷调东方意境，侧逆光园林古风，国潮新中式美学。

**适用场景**：园林、竹林、古建、白墙庭院。

**避坑指南**：
- 饱和度-15 是莫兰迪关键，勿超 -25 否则灰暗
- 侧逆光必须，顺光会失去古风韵味
- WB 5200 轻微偏冷，配合 temperature-10 同向，合规

**校准检查**：
- C4 冷调叠加：temperature-10 + WB 5200(微冷) = 2 处，合规
- C4 对比度提升：contrast+5 + clarity+5 + LUT cinematic(微对比) = 3 处，超限。调整 clarity 为 0，保留 contrast+5 和 LUT，共 2 处，合规。**修正后 clarity: 0**
- C5 色温方向：WB 5200(微冷) + temperature-10(冷)，同向，合规

---

### 模板 6：法式慵懒高雅

| 字段 | 值 |
|---|---|
| ID | `french_lazy_portrait` |
| 优先级 | P1 |
| 分类 | portrait / french_lazy / half_body |
| 画幅 | 4:5 |
| 价格 | 3（付费） |

**风格定位**：慵懒倚靠白床单窗光，颗粒质感，法式高雅氛围。室内氛围感代表，卧室/白床单场景。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.25, y: 0.2, w: 0.5, h: 0.6 }
- 人像位置: 三分线左侧，半身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: french_lazy_pose
pose_name: 倚靠侧坐慵懒
body_orientation: 侧身
body_posture: 倚靠
head_angle: 微仰
gaze_direction: 看侧方
hand_action: 一手撑床/桌面，一手自然放置
leg_posture: 侧坐屈膝
expression: 慵懒无表情
clothing_type: 白色丝质睡衣/简约上衣
props: 书/咖啡杯
composition_hint: 三分位左
scale_hint: 0.78
svg_drawing_notes: 侧身倚靠坐姿轮廓，头部微仰，一手撑面，慵懒线条，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 200
- shutterSpeed: '1/100'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -5
- contrast: +5
- saturation: -5
- temperature: +10
- tint: 0
- highlights: 0
- shadows: +5
- clarity: 0
- vibrance: 0

**滤镜与质感**：
- lut: vintage
- smoothStrength: 12
- sharpen: 12
- vignette: 10
- grain: 22

**光影场景**：
- lightDirection: 侧光（窗光）
- lightDirectionAngle: 90
- shootingDistance: 1.5-2m
- background: 白床单/白墙/木地板/窗帘
- props: 书/咖啡杯/干花
- bestTime: 上午 9:00-11:00
- bestTimeFrom: '09:00'
- bestTimeTo: '11:00'
- tips: ['利用窗光侧光营造明暗', '白床单/白墙做背景保持干净', '颗粒是法式质感核心']

**封面图 prompt**：
```
[风格类型] 法式慵懒高雅人像照片
[主体] 25-30岁女性，自然妆，穿白色丝质睡衣，微卷长发
[动作] 侧身倚靠白床单侧坐，头部微仰看侧方，慵懒表情
[场景] 卧室白床单，窗光侧照，木地板
[构图] 4:5竖图，人像位于三分线左侧，半身取景
[光影] 窗光侧光90度，明暗对比，慵懒氛围
[色调] 微暖复古，对比微提，颗粒质感
[质感] 颗粒22，轻度磨皮，中度锐化
[参考] 小红书法式慵懒风格教程，复古颗粒
[画幅] 4:5
[禁忌] 不要高饱和，不要过度磨皮，不要冷调
```

**模板描述**：白床单窗光下的法式慵懒，颗粒质感复古高雅，卧室里的慵懒时光。

**适用场景**：卧室、白床单、窗边、咖啡馆。

**避坑指南**：
- 颗粒 22 接近上限，勿超 25
- 法式靠颗粒和侧光，不要靠高饱和
- 锐化 12 配合颗粒，营造质感而非清晰度

**校准检查**：
- C4 暖调叠加：temperature+10 + LUT vintage(暖) = 2 处，合规
- C4 对比度提升：contrast+5 + clarity+5 + sharpen 12 = 3 处，超限。调整 clarity 为 0，保留 contrast+5 和 sharpen，共 2 处，合规。**修正后 clarity: 0**
- C5 色温方向：WB daylight(中性) + temperature+10(暖)，不冲突，合规

---

### 模板 7：莫兰迪高级冷淡

| 字段 | 值 |
|---|---|
| ID | `morandi_minimal_portrait` |
| 优先级 | P1 |
| 分类 | portrait / morandi_minimal / half_body |
| 画幅 | 4:5 |
| 价格 | 3（付费） |

**风格定位**：低饱和莫兰迪色系，纯色背景，知性简约高级感。轻熟女/知性风主力，莫兰迪色系达喜爱顶峰。

**构图**：
- overlayType: `center`
- subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 }
- 人像位置: 居中，半身取景
- opacity: 0.2

**pose 结构化描述**：
```yaml
pose_id: morandi_minimal_pose
pose_name: 正面端坐简约
body_orientation: 正面
body_posture: 坐姿
head_angle: 正视
gaze_direction: 看镜头
hand_action: 双手交叠放膝上
leg_posture: 并拢侧坐
expression: 知性无表情
clothing_type: 莫兰迪色系西装/针织衫
props: 无
composition_hint: 居中
scale_hint: 0.8
svg_drawing_notes: 正面端坐轮廓，双手交叠膝上，简约线条，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: 0
- contrast: +5
- saturation: -20
- temperature: -5
- tint: 0
- highlights: 0
- shadows: 0
- clarity: +5
- vibrance: -10

**滤镜与质感**：
- lut: none
- smoothStrength: 12
- sharpen: 10
- vignette: 5
- grain: 5

**光影场景**：
- lightDirection: 顺光/柔光
- lightDirectionAngle: 30
- shootingDistance: 1.5-2m
- background: 纯色灰墙/莫兰迪色背景纸
- props: 无
- bestTime: 全天（室内可控光）
- tips: ['纯色背景保持极简', '服装选莫兰迪灰粉/灰绿/灰蓝', '光线柔和不产生硬阴影']

**封面图 prompt**：
```
[风格类型] 莫兰迪高级冷淡风人像照片
[主体] 28-35岁女性，知性妆容，穿灰粉色西装，短发利落
[动作] 正面端坐，双手交叠放膝上，正视镜头，知性无表情
[场景] 纯灰背景墙，极简无道具
[构图] 4:5竖图，人像居中，半身取景
[光影] 顺光柔光30度，无明显阴影，均匀
[色调] 低饱和莫兰迪，色温微冷，高级冷淡
[质感] 轻度磨皮，轻度锐化，几乎无颗粒
[参考] 莫兰迪色系人像，轻熟女知性风
[画幅] 4:5
[禁忌] 不要高饱和，不要暖调，不要颗粒重，不要暗角重
```

**模板描述**：莫兰迪低饱和高级冷淡，纯色极简知性风，轻熟女的品质感。

**适用场景**：影棚、纯色背景墙、极简室内。

**避坑指南**：
- 饱和度-20 是莫兰迪核心，勿超 -25
- LUT 选 none，让饱和度调整承担主调
- 暗角 5 以下，极简风不需要氛围暗角

**校准检查**：
- C4 饱和度降低：saturation-20 + vibrance-10 = 2 处，合规
- C4 对比度提升：contrast+5 + clarity+5 = 2 处，合规
- C5 色温方向：WB daylight(中性) + temperature-5(微冷)，不冲突，合规

---

### 模板 8：室内暗调氛围

| 字段 | 值 |
|---|---|
| ID | `dark_indoor_portrait` |
| 优先级 | P2 |
| 分类 | portrait / dark_indoor / half_body |
| 画幅 | 3:4 |
| 价格 | 3（付费） |

**风格定位**：咖啡馆暗调精致高级感，锐化质感，黑森林滤镜风格。探店/咖啡馆高频场景。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.28, y: 0.18, w: 0.44, h: 0.65 }
- 人像位置: 三分线左侧，半身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: dark_indoor_pose
pose_name: 托腮倚桌沉思
body_orientation: 侧身
body_posture: 倚靠
head_angle: 微低头
gaze_direction: 看侧方
hand_action: 单手托腮撑桌
leg_posture: 坐姿
expression: 沉思
clothing_type: 深色简约上衣
props: 咖啡杯
composition_hint: 三分位左
scale_hint: 0.78
svg_drawing_notes: 侧身倚桌坐姿轮廓，单手托腮，咖啡杯在桌面，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.3
- iso: 400
- shutterSpeed: '1/80'
- whiteBalance: daylight
- whiteBalanceK: 5200
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -10
- contrast: +10
- saturation: -5
- temperature: +5
- tint: 0
- highlights: -10
- shadows: -5
- clarity: 0
- vibrance: 0

**滤镜与质感**：
- lut: cinematic
- smoothStrength: 12
- sharpen: 20
- vignette: 15
- grain: 8

**光影场景**：
- lightDirection: 侧光（室内灯/窗光）
- lightDirectionAngle: 90
- shootingDistance: 1-1.5m
- background: 咖啡馆/暗调室内/木质桌面
- props: 咖啡杯/书/餐具
- bestTime: 全天（室内）
- tips: ['选择暗调咖啡馆靠窗位', '侧光营造明暗对比', '锐化突出质感细节']

**封面图 prompt**：
```
[风格类型] 室内暗调氛围感人像照片
[主体] 25-30岁女性，淡妆，穿深色高领毛衣，中长发
[动作] 侧身倚靠桌面坐姿，单手托腮，微低头看侧方，沉思
[场景] 暗调咖啡馆，木质桌面，咖啡杯道具
[构图] 3:4竖图，人像位于三分线左侧，半身取景
[光影] 侧光90度，明暗对比，暗调氛围
[色调] 微暖暗调，对比偏高，锐化质感
[质感] 中度锐化，轻度颗粒，轻度磨皮，暗角
[参考] 小红书黑森林滤镜教程，咖啡馆暗调
[画幅] 3:4
[禁忌] 不要过亮，不要高饱和，不要过度磨皮
```

**模板描述**：咖啡馆暗调精致高级，锐化质感黑森林氛围，探店氛围感首选。

**适用场景**：咖啡馆、暗调餐厅、书房、酒吧。

**避坑指南**：
- 锐化 20 接近上限，勿超 25
- 暗调靠 brightness-10 和 shadows-5，不要再加 vignette 过重
- ISO 400 室内合理，勿超

**校准检查**：
- C4 对比度提升：contrast+10 + clarity+8 + sharpen 20 = 3 处，超限。调整 clarity 为 0，保留 contrast+10 和 sharpen 20，共 2 处，合规。**修正后 clarity: 0**
- C5 色温方向：WB 5200(微冷) + temperature+5(暖)，反差 ≤10，合规（特殊氛围）

---

### 模板 9：夜景霓虹人像

| 字段 | 值 |
|---|---|
| ID | `neon_city_portrait` |
| 优先级 | P2 |
| 分类 | portrait / neon_city / half_body |
| 画幅 | 9:16 |
| 价格 | 3（付费） |

**风格定位**：城市霓虹青紫冷暖对比，爱乐之城风格夜景人像。城市夜景人像热门，色温偏冷色调偏品。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.6 }
- 人像位置: 三分线左侧，半身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: neon_city_pose
pose_name: 叉腰站姿飒爽
body_orientation: 正面
body_posture: 站立
head_angle: 正视
gaze_direction: 看镜头
hand_action: 单手叉腰
leg_posture: 一前一后
expression: 酷无表情
clothing_type: 深色皮衣/亮色外套
props: 无
composition_hint: 三分位左
scale_hint: 0.75
svg_drawing_notes: 正面站立叉腰轮廓，一腿前一腿后，飒爽线条，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.3
- iso: 800
- shutterSpeed: '1/60'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -8
- contrast: +12
- saturation: +8
- temperature: -12
- tint: +10
- highlights: -10
- shadows: -5
- clarity: 0
- vibrance: +5

**滤镜与质感**：
- lut: cool_film
- smoothStrength: 12
- sharpen: 12
- vignette: 18
- grain: 12

**光影场景**：
- lightDirection: 多向光（霓虹光源）
- lightDirectionAngle: 0
- shootingDistance: 1.5-2m
- background: 霓虹招牌/城市夜景/车流光斑
- props: 无
- bestTime: 夜晚 20:00-23:00
- bestTimeFrom: '20:00'
- bestTimeTo: '23:00'
- tips: ['选择多色霓虹招牌背景', '冷暖对比是核心（青天+品红霓虹）', '人物着深色突出霓虹色彩']

**封面图 prompt**：
```
[风格类型] 夜景霓虹人像照片
[主体] 22-28岁女性，酷妆，穿黑色皮衣，短发利落
[动作] 正面站立单手叉腰，一腿前一腿后，酷无表情看镜头
[场景] 城市霓虹街景，青色品红色霓虹招牌虚化背景
[构图] 9:16竖图，人像位于三分线左侧，半身取景
[光影] 多向霓虹光，冷暖对比，青紫色调
[色调] 冷青品紫对比，对比偏高，爱乐之城风格
[质感] 中度锐化，轻度颗粒，暗角氛围
[参考] 小红书爱乐之城滤镜教程，城市夜景人像
[画幅] 9:16
[禁忌] 不要暖调主光，不要过亮，不要低对比
```

**模板描述**：城市霓虹青紫冷暖对比，爱乐之城夜景人像，夜晚街头的赛博浪漫。

**适用场景**：霓虹街、城市夜景、商圈灯光。

**避坑指南**：
- 冷调叠加：temperature-12 + WB fluorescent(冷) + LUT cool_film = 3 处，调整 WB 为 daylight(5500 中性)，保留 temperature-12 和 LUT，共 2 处，合规。**修正后 WB: daylight, whiteBalanceK: 5500**
- tint+10 营造品红，勿超 +15

**校准检查**：
- C4 冷调叠加：temperature-12 + LUT cool_film = 2 处，合规（WB 已中性化）
- C4 对比度提升：contrast+12 + clarity+5 + sharpen 12 = 3 处，调整 clarity 为 0，合规。**修正后 clarity: 0**
- C5 色温方向：WB daylight(中性) + temperature-12(冷)，不冲突，合规

---

### 模板 10：清新淡雅绿

| 字段 | 值 |
|---|---|
| ID | `fresh_green_portrait` |
| 优先级 | P2 |
| 分类 | portrait / fresh_green / full_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：户外森系露营净白滤镜，空气感清新淡雅绿。户外森系/露营场景，净白滤镜热门。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.25, y: 0.1, w: 0.5, h: 0.8 }
- 人像位置: 三分线左侧，全身取景，留白充足
- opacity: 0.2

**pose 结构化描述**：
```yaml
pose_id: fresh_green_pose
pose_name: 草地坐姿回眸
body_orientation: 侧身
body_posture: 坐姿（草地）
head_angle: 回眸
gaze_direction: 看镜头
hand_action: 双手撑地后撑
leg_posture: 屈膝坐地
expression: 自然微笑
clothing_type: 浅色休闲/棉麻
props: 草帽/野餐垫
composition_hint: 三分位左
scale_hint: 0.7
svg_drawing_notes: 侧身草地坐姿轮廓，回眸转向镜头，双手后撑，屈膝，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/200'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +12
- contrast: -8
- saturation: -8
- temperature: -8
- tint: 0
- highlights: +5
- shadows: +12
- clarity: -5
- vibrance: 0

**滤镜与质感**：
- lut: pastel
- smoothStrength: 10
- sharpen: 5
- vignette: 0
- grain: 0

**光影场景**：
- lightDirection: 漫射光（阴天/树荫）
- lightDirectionAngle: 0
- shootingDistance: 2-3m
- background: 草地/森林/露营地/野餐垫
- props: 草帽/野餐垫/帐篷
- bestTime: 上午 8:00-10:00 或阴天
- bestTimeFrom: '08:00'
- bestTimeTo: '10:00'
- tips: ['选择阴天或树荫漫射光', '服装浅色棉麻与自然融合', '留白要足，人景比例 4:6']

**封面图 prompt**：
```
[风格类型] 清新淡雅绿森系人像照片
[主体] 20-25岁女性，淡妆，穿米色棉麻连衣裙，长发自然
[动作] 侧身坐在草地，回眸看镜头，双手后撑，屈膝，自然微笑
[场景] 森林草地，树荫漫射光，野餐垫
[构图] 3:4竖图，人像位于三分线左侧，全身取景，右侧留白
[光影] 漫射光，柔和无硬阴影，空气感
[色调] 淡雅绿调，低对比低饱和，色温微冷，明亮
[质感] 无颗粒，轻度磨皮，不锐化
[参考] 小红书净白滤镜教程，户外森系露营
[画幅] 3:4
[禁忌] 不要暖调，不要高对比，不要颗粒，不要暗角
```

**模板描述**：户外森系净白空气感，清新淡雅绿调，草地森林的自然治愈。

**适用场景**：森林、草地、露营地、公园。

**避坑指南**：
- 与日系小清新相似但更强调绿调和户外场景
- 颗粒和暗角必须 0
- brightness+12 与 shadows+12 提亮，EV+0.3 三处，调整 EV 为 0，合规。**修正后 exposureCompensation: 0**

**校准检查**：
- C4 亮度提升：brightness+12 + shadows+12 = 2 处，合规（EV 已归零）
- C4 对比度降低：contrast-8 + clarity-5 = 2 处，合规
- C5 色温方向：WB daylight(中性) + temperature-8(微冷)，不冲突，合规

---

### 模板 11：Y2K 千禧风

| 字段 | 值 |
|---|---|
| ID | `y2k_portrait` |
| 优先级 | P2 |
| 分类 | portrait / y2k / half_body |
| 画幅 | 3:4 |
| 价格 | 3（付费） |

**风格定位**：千禧回潮高饱和闪光，飒爽酷 girl，Y2K 攻击性非甜美路线。年轻酷 girl 新兴风格。

**构图**：
- overlayType: `center`
- subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 }
- 人像位置: 居中，半身取景
- opacity: 0.2

**pose 结构化描述**：
```yaml
pose_id: y2k_pose
pose_name: 双手比叉腰飒爽
body_orientation: 正面
body_posture: 站立
head_angle: 正视微仰
gaze_direction: 直视镜头
hand_action: 双手叉腰
leg_posture: 开立站姿
expression: 酷无表情
clothing_type: 亮色短上衣/低腰裤/金属配饰
props: 墨镜/链条
composition_hint: 居中
scale_hint: 0.8
svg_drawing_notes: 正面双手叉腰站立轮廓，开立站姿，头部微仰，飒爽线条，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 200
- shutterSpeed: '1/125'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: on
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +5
- contrast: +12
- saturation: +15
- temperature: +5
- tint: 0
- highlights: -5
- shadows: -5
- clarity: 0
- vibrance: +5

**滤镜与质感**：
- lut: none
- smoothStrength: 8
- sharpen: 15
- vignette: 5
- grain: 5

**光影场景**：
- lightDirection: 正面闪光
- lightDirectionAngle: 0
- shootingDistance: 1-1.5m
- background: 纯色墙/涂鸦墙/街头
- props: 墨镜/链条/发夹
- bestTime: 全天（闪光为主光）
- tips: ['开启闪光灯直打', '服装亮色+金属配饰', '表情要酷不要甜']

**封面图 prompt**：
```
[风格类型] Y2K千禧风人像照片
[主体] 18-22岁女性，浓妆眼线，穿亮粉色短上衣低腰牛仔裤，金属链条配饰
[动作] 正面站立双手叉腰，开立站姿，头部微仰，酷无表情直视镜头
[场景] 涂鸦墙街头背景，闪光直打
[构图] 3:4竖图，人像居中，半身取景
[光影] 正面闪光灯直打，高对比硬光
[色调] 高饱和高对比，暖微调，千禧攻击性
[质感] 中度锐化，轻度颗粒，低磨皮保留质感
[参考] 小红书Y2K千禧风教程，酷girl非甜美
[画幅] 3:4
[禁忌] 不要低饱和，不要柔光，不要甜美表情，不要过度磨皮
```

**模板描述**：千禧回潮高饱和闪光，飒爽酷 girl 攻击性，Y2K 非甜美路线。

**适用场景**：街头、涂鸦墙、纯色墙、室内闪光。

**避坑指南**：
- 饱和度+15 接近上限，勿超 +20
- 闪光必须开，Y2K 靠闪光直打
- 磨皮 8 以下，保留皮肤质感

**校准检查**：
- C4 饱和度提升：saturation+15 + vibrance+5 = 2 处，合规
- C4 对比度提升：contrast+12 + clarity+8 + sharpen 15 = 3 处，调整 clarity 为 0，合规。**修正后 clarity: 0**
- C5 色温方向：WB daylight(中性) + temperature+5(微暖)，不冲突，合规

---

### 模板 12：动漫温柔青

| 字段 | 值 |
|---|---|
| ID | `anime_dream_portrait` |
| 优先级 | P2 |
| 分类 | portrait / anime_dream / full_body |
| 画幅 | 3:4 |
| 价格 | 3（付费） |

**风格定位**：宫崎骏感饱和提亮，晴天草地动漫风。梦境滤镜风格，晴天户外差异化。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.2, y: 0.1, w: 0.55, h: 0.8 }
- 人像位置: 三分线左侧偏中，全身取景，天空留白
- opacity: 0.2

**pose 结构化描述**：
```yaml
pose_id: anime_dream_pose
pose_name: 张开双臂仰望
body_orientation: 正面
body_posture: 站立
head_angle: 仰头
gaze_direction: 仰望天空
hand_action: 双臂张开
leg_posture: 微张站立
expression: 开心大笑
clothing_type: 浅色连衣裙/白衬衫
props: 无
composition_hint: 三分位左
scale_hint: 0.7
svg_drawing_notes: 正面站立张开双臂轮廓，仰头，裙摆飘动，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/200'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +12
- contrast: -5
- saturation: +10
- temperature: +5
- tint: 0
- highlights: -5
- shadows: +15
- clarity: -5
- vibrance: +8

**滤镜与质感**：
- lut: pastel
- smoothStrength: 10
- sharpen: 5
- vignette: 0
- grain: 0

**光影场景**：
- lightDirection: 顺光/顶光
- lightDirectionAngle: 30
- shootingDistance: 2-3m
- background: 蓝天白云/草地/花海
- props: 无
- bestTime: 上午 9:00-11:00
- bestTimeFrom: '09:00'
- bestTimeTo: '11:00'
- tips: ['晴天蓝天才有效果', '仰拍带天空', '服装浅色与天空呼应']

**封面图 prompt**：
```
[风格类型] 动漫温柔青人像照片
[主体] 18-22岁女性，淡妆，穿浅蓝色连衣裙，长发飘动
[动作] 正面站立张开双臂，仰头看天，开心大笑
[场景] 晴天草地，蓝天白云背景
[构图] 3:4竖图，人像位于三分线左侧，全身取景，天空留白
[光影] 顺光晴天，明亮通透，宫崎骏感
[色调] 饱和微提，亮度偏高，阴影提亮，梦幻青调
[质感] 无颗粒，轻度磨皮，不锐化
[参考] 小红书梦境滤镜教程，宫崎骏动漫感
[画幅] 3:4
[禁忌] 不要暗调，不要颗粒，不要高对比，不要暗角
```

**模板描述**：宫崎骏感饱和提亮梦境青，晴天草地张开双臂的动漫浪漫。

**适用场景**：晴天草地、花海、蓝天白云户外。

**避坑指南**：
- 必须晴天蓝天才有效果
- 饱和+10 配合 vibrance+8 共 2 处，合规
- brightness+12 + shadows+15 + EV+0.3 三处提亮，调整 EV 为 0，合规。**修正后 exposureCompensation: 0**

**校准检查**：
- C4 亮度提升：brightness+12 + shadows+15 = 2 处，合规（EV 已归零）
- C4 饱和度提升：saturation+10 + vibrance+8 = 2 处，合规
- C5 色温方向：WB daylight(中性) + temperature+5(微暖)，不冲突，合规

---

### 模板 13：复古暗夜蓝

| 字段 | 值 |
|---|---|
| ID | `blue_night_portrait` |
| 优先级 | P3 |
| 分类 | portrait / blue_night / seven_body |
| 画幅 | 3:4 |
| 价格 | 3（付费） |

**风格定位**：逆光天空大海，爱乐之城深色冷峻浪漫。逆光天空/大海差异化场景。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.25, y: 0.15, w: 0.5, h: 0.75 }
- 人像位置: 三分线左侧，七分身取景，天空大海占主体
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: blue_night_pose
pose_name: 背影望海
body_orientation: 背影
body_posture: 站立
head_angle: 仰头
gaze_direction: 望远方
hand_action: 双手自然下垂
leg_posture: 并拢站立
expression: 无（背影）
clothing_type: 深色长裙/风衣
props: 无
composition_hint: 三分位左
scale_hint: 0.65
svg_drawing_notes: 背影站立轮廓，仰头望远方，长裙下摆，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.5
- iso: 200
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -8
- contrast: +12
- saturation: -5
- temperature: -12
- tint: 0
- highlights: -15
- shadows: -5
- clarity: 0
- vibrance: 0

**滤镜与质感**：
- lut: cool_film
- smoothStrength: 8
- sharpen: 10
- vignette: 15
- grain: 8

**光影场景**：
- lightDirection: 逆光
- lightDirectionAngle: 180
- shootingDistance: 2-3m
- background: 天空/大海/夕阳余晖/山顶
- props: 无
- bestTime: 黄昏 17:00-19:00
- bestTimeFrom: '17:00'
- bestTimeTo: '19:00'
- tips: ['黄昏逆光剪影感', '天空大海占画面 2/3', '人物深色突出轮廓']

**封面图 prompt**：
```
[风格类型] 复古暗夜蓝人像照片
[主体] 女性，穿深色长裙，长发
[动作] 背影站立望海，仰头，双手自然下垂
[场景] 黄昏海边，天空大海占主体，逆光
[构图] 3:4竖图，人像位于三分线左侧，七分身，天空大海留白
[光影] 逆光180度，黄昏余晖，剪影感
[色调] 冷青深色，对比偏高，冷峻浪漫
[质感] 轻度颗粒，轻度锐化，暗角氛围
[参考] 小红书爱乐之城深色滤镜，逆光剪影
[画幅] 3:4
[禁忌] 不要暖调，不要高亮，不要高饱和
```

**模板描述**：黄昏逆光暗夜蓝冷峻浪漫，天空大海的背影剪影诗。

**适用场景**：海边黄昏、山顶、天台逆光。

**避坑指南**：
- 冷调叠加：temperature-12 + WB 5200(微冷) + LUT cool_film = 3 处，调整 WB 为 daylight(5500 中性)，保留 temperature-12 和 LUT，共 2 处，合规。**修正后 WB: daylight, whiteBalanceK: 5500**
- 逆光剪影靠 EV-0.5 和 highlights-15，不要再加 brightness 负值过多

**校准检查**：
- C4 冷调叠加：temperature-12 + LUT cool_film = 2 处，合规（WB 已中性化）
- C4 对比度提升：contrast+12 + clarity+5 + sharpen 10 = 3 处，调整 clarity 为 0，合规。**修正后 clarity: 0**
- C5 色温方向：WB daylight(中性) + temperature-12(冷)，不冲突，合规

---

### 模板 14：温柔日暮紫

| 字段 | 值 |
|---|---|
| ID | `purple_dusk_portrait` |
| 优先级 | P3 |
| 分类 | portrait / purple_dusk / half_body |
| 画幅 | 3:4 |
| 价格 | 3（付费） |

**风格定位**：夕阳克莱因蓝，HSL 蓝饱和提升，梦幻紫色日暮。夕阳差异化场景，梦幻氛围。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.65 }
- 人像位置: 三分线右侧，半身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: purple_dusk_pose
pose_name: 侧脸望夕阳
body_orientation: 侧身
body_posture: 站立
head_angle: 侧脸仰头
gaze_direction: 望夕阳
hand_action: 一手轻拂发丝
leg_posture: 并拢站立
expression: 陶醉微笑
clothing_type: 白色/浅色裙装
props: 无
composition_hint: 三分位右
scale_hint: 0.75
svg_drawing_notes: 侧身站立轮廓，侧脸仰头望远方，一手拂发，裙摆轻动，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: -0.3
- iso: 200
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: -5
- contrast: +8
- saturation: +5
- temperature: +5
- tint: +15
- highlights: -10
- shadows: +5
- clarity: 0
- vibrance: +5

**滤镜与质感**：
- lut: cinematic
- smoothStrength: 10
- sharpen: 8
- vignette: 10
- grain: 5

**光影场景**：
- lightDirection: 侧逆光（夕阳）
- lightDirectionAngle: 150
- shootingDistance: 1.5-2m
- background: 夕阳天空/紫色晚霞/海边
- props: 无
- bestTime: 黄昏 17:30-19:00
- bestTimeFrom: '17:30'
- bestTimeTo: '19:00'
- tips: ['选择紫色晚霞的黄昏', '侧逆光勾勒轮廓', 'tint+15 是紫色关键']

**封面图 prompt**：
```
[风格类型] 温柔日暮紫人像照片
[主体] 20-28岁女性，淡妆，穿白色连衣裙，长发
[动作] 侧身站立，侧脸仰头望夕阳，一手轻拂发丝，陶醉微笑
[场景] 黄昏海边，紫色晚霞天空
[构图] 3:4竖图，人像位于三分线右侧，半身取景
[光影] 夕阳侧逆光150度，轮廓光，紫色氛围
[色调] 紫色日暮调，色温微暖，色调偏品红，梦幻
[质感] 轻度磨皮，轻度锐化，微颗粒
[参考] 小红书克莱因蓝滤镜教程，夕阳紫色梦幻
[画幅] 3:4
[禁忌] 不要冷调，不要高对比，不要过度磨皮
```

**模板描述**：夕阳克莱因蓝梦幻紫，HSL 蓝饱和提升的日暮浪漫。

**适用场景**：黄昏海边、天台、山顶夕阳。

**避坑指南**：
- tint+15 是紫色关键，勿超 +15 否则色偏
- temperature+5 微暖配 tint+15 品红，营造紫色，勿让 temperature 过高
- LUT cinematic 与 tint 方向需协调，cinematic 偏青橙，tint 偏品红，注意平衡

**校准检查**：
- C4 暖调叠加：temperature+5 + tint+15 = 1 处暖 + 1 处品红，方向不同，合规
- C4 对比度提升：contrast+8 + sharpen 8 = 2 处，合规
- C5 色温方向：WB daylight(中性) + temperature+5(微暖)，不冲突，合规

---

### 模板 15：探店美食人像

| 字段 | 值 |
|---|---|
| ID | `foodie_portrait` |
| 优先级 | P3 |
| 分类 | portrait / foodie_portrait / half_body |
| 画幅 | 1:1 |
| 价格 | 0（免费） |

**风格定位**：美食+人物，对角线构图，暖调下午茶。探店/下午茶细分场景，Foodie 滤镜风格。

**构图**：
- overlayType: `diagonal`
- subjectFrame: { x: 0.2, y: 0.2, w: 0.6, h: 0.6 }
- 人像位置: 对角线构图，人物与美食呈对角
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: foodie_pose
pose_name: 举杯托腮看食物
body_orientation: 侧身
body_posture: 坐姿
head_angle: 低头看食物
gaze_direction: 看食物
hand_action: 一手举杯/餐具，一手托腮
leg_posture: 坐姿
expression: 微笑
clothing_type: 休闲日常
props: 咖啡杯/蛋糕/餐具
composition_hint: 对角线
scale_hint: 0.75
svg_drawing_notes: 侧身坐姿轮廓，一手举杯一手托腮，低头看桌面食物，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 200
- shutterSpeed: '1/100'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +10
- contrast: -5
- saturation: +10
- temperature: +10
- tint: 0
- highlights: 0
- shadows: +8
- clarity: 0
- vibrance: +5

**滤镜与质感**：
- lut: warm_film
- smoothStrength: 12
- sharpen: 10
- vignette: 5
- grain: 0

**光影场景**：
- lightDirection: 顺光/侧光（室内灯）
- lightDirectionAngle: 45
- shootingDistance: 0.8-1.2m
- background: 咖啡馆桌面/餐厅/美食
- props: 咖啡杯/蛋糕/餐具
- bestTime: 全天（室内）
- tips: ['美食与人物呈对角线构图', '俯拍 45 度角', '暖调让食物更诱人']

**封面图 prompt**：
```
[风格类型] 探店美食人像照片
[主体] 22-28岁女性，淡妆，穿浅色针织衫，中长发
[动作] 侧身坐姿，一手举咖啡杯，一手托腮，低头看桌面蛋糕，微笑
[场景] 咖啡馆桌面，蛋糕咖啡道具，暖调室内
[构图] 1:1方图，人像与美食呈对角线构图
[光影] 侧光45度，暖调室内灯，明亮
[色调] 暖调，饱和微提，食物诱人
[质感] 轻度磨皮，轻度锐化，无颗粒
[参考] 小红书探店下午茶拍照，Foodie滤镜
[画幅] 1:1
[禁忌] 不要冷调，不要暗调，不要颗粒
```

**模板描述**：美食+人物对角线暖调，下午茶探店的诱人时光。

**适用场景**：咖啡馆、餐厅、下午茶、甜品店。

**避坑指南**：
- 暖调叠加：temperature+10 + LUT warm_film = 2 处，合规
- 饱和+10 让食物诱人，勿超 +15
- 1:1 方图适合社交媒体

**校准检查**：
- C4 暖调叠加：temperature+10 + LUT warm_film = 2 处，合规
- C4 亮度提升：EV+0.3 + brightness+10 + shadows+8 = 3 处，调整 EV 为 0，合规。**修正后 exposureCompensation: 0**
- C5 色温方向：WB daylight(中性) + temperature+10(暖)，不冲突，合规

---

### 模板 16：甜妹元气少女

| 字段 | 值 |
|---|---|
| ID | `sweet_girl_portrait` |
| 优先级 | P3 |
| 分类 | portrait / sweet_girl / half_body |
| 画幅 | 3:4 |
| 价格 | 0（免费） |

**风格定位**：高亮暖粉，比心托腮，九宫格甜美。年轻女性细分，甜妹元气少女风。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 }
- 人像位置: 三分线右侧，半身取景
- opacity: 0.2

**pose 结构化描述**：
```yaml
pose_id: sweet_girl_pose
pose_name: 比心托腮俏皮
body_orientation: 正面
body_posture: 站立微倾
head_angle: 微歪
gaze_direction: 看镜头
hand_action: 单手比心/双手比心
leg_posture: 并拢微内八
expression: 俏皮大笑
clothing_type: 粉色/亮色可爱装
props: 发夹/泡泡
composition_hint: 三分位右
scale_hint: 0.8
svg_drawing_notes: 正面站立微倾轮廓，单手比心至脸侧，头部微歪，俏皮线条，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +12
- contrast: -5
- saturation: +8
- temperature: +8
- tint: 0
- highlights: +5
- shadows: +10
- clarity: -5
- vibrance: +5

**滤镜与质感**：
- lut: pastel
- smoothStrength: 15
- sharpen: 5
- vignette: 0
- grain: 0

**光影场景**：
- lightDirection: 顺光
- lightDirectionAngle: 30
- shootingDistance: 1-1.5m
- background: 纯色粉墙/游乐场/花墙
- props: 发夹/泡泡/气球
- bestTime: 上午 9:00-11:00
- bestTimeFrom: '09:00'
- bestTimeTo: '11:00'
- tips: ['顺光明亮均匀', '服装粉色亮色系', '表情要甜要活泼']

**封面图 prompt**：
```
[风格类型] 甜妹元气少女风人像照片
[主体] 18-22岁女性，可爱妆容，穿粉色连衣裙，双马尾或长发
[动作] 正面站立微倾，单手比心至脸侧，头部微歪，俏皮大笑看镜头
[场景] 纯色粉墙背景，花墙或游乐场
[构图] 3:4竖图，人像位于三分线右侧，半身取景
[光影] 顺光30度，明亮均匀，粉嫩
[色调] 高亮暖粉调，饱和微提，甜美元气
[质感] 轻度磨皮，不锐化，无颗粒
[参考] 小红书甜妹拍照教程，元气少女风
[画幅] 3:4
[禁忌] 不要暗调，不要高对比，不要冷调，不要颗粒
```

**模板描述**：高亮暖粉比心托腮，九宫格甜美元气少女，青春的粉色记忆。

**适用场景**：花墙、游乐场、纯色墙、校园。

**避坑指南**：
- 暖粉调：temperature+8 + tint+5 + LUT pastel(柔粉) = 3 处，调整 tint 为 0，保留 temperature+8 和 LUT，共 2 处，合规。**修正后 tint: 0**
- brightness+12 + shadows+10 + EV+0.3 三处提亮，调整 EV 为 0，合规。**修正后 exposureCompensation: 0**

**校准检查**：
- C4 暖调叠加：temperature+8 + LUT pastel = 2 处，合规（tint 已归零）
- C4 亮度提升：brightness+12 + shadows+10 = 2 处，合规（EV 已归零）
- C5 色温方向：WB daylight(中性) + temperature+8(暖)，不冲突，合规

---

### 模板 17：知性优雅轻熟女

| 字段 | 值 |
|---|---|
| ID | `elegant_lady_portrait` |
| 优先级 | P3 |
| 分类 | portrait / elegant_lady / seven_body |
| 画幅 | 4:5 |
| 价格 | 3（付费） |

**风格定位**：莫兰迪淡雅，三分法，成熟大气。成熟女性细分，知性优雅轻熟女风。

**构图**：
- overlayType: `rule_of_thirds`
- subjectFrame: { x: 0.25, y: 0.1, w: 0.5, h: 0.8 }
- 人像位置: 三分线左侧，七分身取景
- opacity: 0.25

**pose 结构化描述**：
```yaml
pose_id: elegant_lady_pose
pose_name: 侧身行走优雅
body_orientation: 侧身
body_posture: 行走
head_angle: 侧脸
gaze_direction: 看远方
hand_action: 一手持包，一手自然摆动
leg_posture: 优雅迈步
expression: 自信微笑
clothing_type: 莫兰迪色系西装/风衣/连衣裙
props: 手提包
composition_hint: 三分位左
scale_hint: 0.7
svg_drawing_notes: 侧身行走轮廓，优雅迈步，一手持包，裙摆/风衣微动，viewBox 0 0 100 200
```

**相机参数**：
- exposureCompensation: 0
- iso: 100
- shutterSpeed: '1/160'
- whiteBalance: daylight
- whiteBalanceK: 5500
- flashMode: off
- focusMode: auto
- lensType: '1x'

**后期参数**：
- brightness: +5
- contrast: +5
- saturation: -12
- temperature: -5
- tint: 0
- highlights: 0
- shadows: +5
- clarity: 0
- vibrance: -5

**滤镜与质感**：
- lut: cinematic
- smoothStrength: 12
- sharpen: 10
- vignette: 8
- grain: 5

**光影场景**：
- lightDirection: 侧光/漫射光
- lightDirectionAngle: 60
- shootingDistance: 2-3m
- background: 城市街拍/办公室/简约室内
- props: 手提包
- bestTime: 上午 9:00-11:00 或下午 15:00-17:00
- bestTimeFrom: '09:00'
- bestTimeTo: '11:00'
- tips: ['莫兰迪色系服装', '侧身行走抓拍动态', '三分法构图留白']

**封面图 prompt**：
```
[风格类型] 知性优雅轻熟女人像照片
[主体] 30-35岁女性，精致妆容，穿灰蓝色西装风衣，短发利落
[动作] 侧身优雅行走，侧脸看远方，一手持手提包，自信微笑
[场景] 城市街道简约背景，办公商务区
[构图] 4:5竖图，人像位于三分线左侧，七分身取景
[光影] 侧光60度，柔和，莫兰迪淡雅
[色调] 低饱和莫兰迪，色温微冷，知性成熟
[质感] 轻度磨皮，轻度锐化，微颗粒
[参考] 小红书轻熟女穿搭拍照，莫兰迪淡雅
[画幅] 4:5
[禁忌] 不要高饱和，不要暖调，不要过度磨皮
```

**模板描述**：莫兰迪淡雅三分法，知性优雅轻熟女，成熟大气的品质感。

**适用场景**：城市街拍、办公室、商务区、简约室内。

**避坑指南**：
- 饱和度-12 莫兰迪，勿超 -20
- 与莫兰迪高级冷淡（模板 7）区分：本款七分身+行走+街拍，模板 7 半身+端坐+纯色背景
- LUT cinematic 配合 saturation-12，营造电影感莫兰迪

**校准检查**：
- C4 饱和度降低：saturation-12 + vibrance-5 = 2 处，合规
- C4 对比度提升：contrast+5 + clarity+5 + sharpen 10 = 3 处，调整 clarity 为 0，合规。**修正后 clarity: 0**
- C5 色温方向：WB daylight(中性) + temperature-5(微冷)，不冲突，合规

---

## 7. 避坑指南与自检清单

### 7.1 全局避坑指南

基于当前模板 11 类问题，总结以下避坑原则：

1. **不要三重叠加同方向强化**：对比度/暖调/亮度/饱和度的同方向强化最多 2 处（C4 约束）
2. **磨皮不是越强越好**：超 30 毁细节变塑料，人像默认 15，特写最多 20（C1 约束）
3. **锐化控制白边**：超 25 产生光晕，默认 10，质感风最多 20（C2 约束）
4. **颗粒用随机种子**：固定种子每张相同不自然，强度超 25 掩盖主体（C3 约束）
5. **WB 与 temperature 同向**：反向叠加会产生不可预期色偏（C5 约束）
6. **ISO 亮度修正需谨慎**：ISO>200 的亮度修正会破坏夜景氛围，夜景模板应关闭此逻辑
7. **LUT 不是万能**：LUT 已含对比/饱和/色温调整，叠加时需检查冲突
8. **清新风不需要质感修饰**：颗粒/暗角/锐化在日系清新风中应归零
9. **暗调风不要强行提亮**：夜景/暗调的亮度应为负，shadows 不应过度提升
10. **pose 要与构图匹配**：全身有动线（行走/站立），半身有手部安排（托腮/叉腰），特写有表情

### 7.2 模板设计自检清单

每个新模板设计完成后，必须通过以下自检：

- [ ] **C1 检查**：smoothStrength ≤ 30，默认 ≤ 20？
- [ ] **C2 检查**：sharpen ≤ 25？
- [ ] **C3 检查**：grain ≤ 25，随机种子每张变化？
- [ ] **C4 检查**：同方向强化手段（对比/暖调/冷调/饱和/亮度）各不超过 2 处？
- [ ] **C5 检查**：WB 与 temperature 同向，或反差 ≤ 15？
- [ ] **三段式检查**：主效果是否只选一个承担者（LUT 或 temperature）？
- [ ] **场景匹配检查**：参数与场景光线匹配（夜景不强行提亮、逆光不强行压暗）？
- [ ] **pose 匹配检查**：pose 与构图方式匹配（全身有动线、半身有手部）？
- [ ] **AI 输入检查**：封面图 prompt 和 pose 结构化描述是否完整？
- [ ] **避坑指南检查**：是否提供了该模板特有的避坑提示？

### 7.3 参数冲突速查表

| 冲突类型 | 检查方法 | 解决方案 |
|---|---|---|
| 对比度三重叠加 | contrast + LUT内置对比 + sharpen + clarity 同为正 | 保留 2 处，其余归零 |
| 暖调三重叠加 | temperature+ + WB暖 + LUT暖 + tint+ 同向 | WB 改中性，保留 temperature + LUT |
| 冷调三重叠加 | temperature- + WB冷 + LUT冷 同向 | WB 改中性，保留 temperature + LUT |
| 亮度三重叠加 | EV+ + brightness+ + shadows+ + ISO修正 同向 | EV 归零，保留 brightness + shadows |
| 饱和度三重叠加 | saturation+ + vibrance+ + LUT饱和 同向 | 保留 2 处，第 3 处归零 |
| 磨皮毁细节 | smoothStrength > 30 | 降至 ≤ 20 |
| 锐化白边 | sharpen > 25 | 降至 ≤ 20 |
| 颗粒掩盖主体 | grain > 25 | 降至 ≤ 20 |
| WB 与 temperature 反向 | WB 冷 + temperature 暖（或反之）且幅度 > 15 | 统一方向，或减小反差 |

---

## 8. 附录：调研依据

### 8.1 调研平台

- 小红书：plog/vlog 博主"精致感+质感"调色套路
- 抖音：网红拍照姿势+滤镜推荐教程
- 微信公众号/视频号：系统化手机人像摄影教学
- 快手：短视频美颜滤镜+曝光画质调整
- 专业摄影社区：图虫/LOFTER/POCO/蜂鸟网风格套图
- 摄影类 App：轻颜/醒图/美图秀秀/Foodie/无他/一甜/ProCCD 热门滤镜

### 8.2 2025-2026 流行趋势 TOP10

1. CCD 复古胶片风（持续上升）
2. 港风复古夜景（上升）
3. AI 复古人像（新兴爆发）
4. 新中式/汉服古风（稳定热门）
5. 日系小清新（长青）
6. Y2K/千禧风（上升）
7. 奶油治愈风（稳定）
8. 莫兰迪高级冷淡（稳定）
9. 富士胶片模拟（新兴）
10. 夜景霓虹氛围感（上升）

### 8.3 用户痛点总结

1. 滤镜失真严重（磨皮过度、五官不清）
2. "滤镜景点"落差（过度美化失去信任）
3. 美颜切换生硬（焦段/质感切换粗糙）
4. 真 CCD 门槛高（贵且难买，需修图）
5. 调色门槛高（"咔嚓千万张卡在修图"）
6. 滤镜非万能（同参数不适配所有场景）
7. 构图不知所措（不知模特放哪）

### 8.4 主要参考来源

- 2025 年人像摄影新趋势（搜狐）
- 醒图/美图秀秀滤镜参数教程（网易/51nacs/php.cn）
- vivo X200 Ultra 人像 CCD 模式（vivo 社区）
- 富士免费开放胶片滤镜（头条）
- AI 生成 CCD 感照片（搜狐）
- 滤镜景点事件小红书致歉（头条）
- 手机拍照失真问题（ZOL）
- 人像构图技巧（头条）
- 图虫/蜂鸟网人像风格套图

---

## 文档结束

本规范定义了 17 款人像拍照模板的完整设计，包括：
- 设计哲学与 5 条硬约束（C1-C5）
- 三层分类体系与 17 款模板总览
- 三段式参数校准规则与冲突检查矩阵
- AI 生成输入规范（封面图 prompt + 剪影 pose 结构化描述）
- 17 款模板的完整定义（构图/pose/参数/滤镜/光影/封面图/避坑）
- 全局避坑指南与自检清单

**下一步**：本规范经用户评审通过后，调用 writing-plans 技能创建分阶段实现计划，涵盖：
1. 剪影 SVG 迁移与解析器扩展（支持贝塞尔曲线）
2. 17 款模板数据文件编写（Flutter + uni-app 双端）
3. 参数校准规则的代码化（C1-C5 约束校验）
4. AI 生成脚本对接（封面图 + 剪影）
5. 底层算法重构（LUT 3D/磨皮分区/sharpen USM/色彩空间统一）
