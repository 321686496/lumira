# 秋季首页 Banner 运营位设计

- 日期：2026-10-13
- 状态：已批准（设计口头确认）
- 范围：运营配置为主 + 1 处 admin UI 小修复；App / 后端零代码改动

## 1. 背景与目标

国庆、中秋已过，进入秋季。首页 banner 轮播需要一组秋季主题运营位，营造换季氛围并引导用户使用秋季相关模板/场景。

现有 banner 体系（数据驱动，无需改 App）：

- 后端 `operation_banners` 表 + `GET /api/v1/banners`（`banners.service.ts`），写操作即时失效 Redis 缓存（正常 ≤60s 生效）
- admin 后台管理页（`packages/admin/src/components/banner-manager.tsx`），支持配图上传（选中即传、客户端压缩）
- Flutter 首页轮播（`home_banner.dart`）：运营位配图全幅 cover + 上→下黑渐变（25%→55%）+ 左侧白色文案；`kind=search` 条目按 `position` 绝对槽位插入轮播（`recommendation_service.dart` L384-392）

## 2. 方案概述

1. **3 条 `kind=search` banner**：点击跳全局搜索页并预填关键词「秋」（scope=all）。
2. **前排轮播**：三条依次占 `position` 0 / 1 / 2；个性化 banner 后移但轮播无限循环仍会展示；活动结束后后台一键停用即恢复。
3. **关键词统一「秋」**：后端搜索为模板名称/作者/分类/分类名/描述/标签的子串匹配（`templates.service.ts` L60-68），短词命中池最大（场景库已有「芦苇秋色」）。
4. **admin UI 修复**：`banner-manager.tsx` 槽位输入框当前 `disabled={form.kind !== 'ad'}`，需放开为 `disabled={form.kind === 'operation'}`，label「广告槽位（留空=最后）」→「槽位（留空=最后）」。后端与 App 均已支持 search + position，无需其他改动。
5. **交付方式**：本设计产出 3 张配图 + 文案 + 字段填值清单（图片输出到 `assets/autumn-banner/`）；配置由运营在 admin 后台手动完成。

## 3. 三张 Banner 内容

统一角标 tag「秋日企划」，风格为「秋日生活感」（咖啡馆/毛衣/落叶街道），三张场景与构图互不重复，色调统一（暖橙金 + 低饱和胶片感）。

| # | id | 主标题 | 副标题 | 配图场景 |
|---|----|--------|--------|---------|
| 1 | `banner_autumn_cafe` | 把秋天装进一杯咖啡 | 窗边暖光，拍出慵懒的秋日氛围 | 咖啡馆窗边，手捧热咖啡，窗格光影落在秋叶上 |
| 2 | `banner_autumn_sweater` | 换上毛衣的温柔秋天 | 针织质感与暖茶，记录换季时刻 | 毛衣与热茶的桌面暖调特写 |
| 3 | `banner_autumn_street` | 落叶铺满的午后街道 | 金色光影，随手一拍都是秋天 | 落叶街道的午后暖光漫步 |

文案约束依据：主标题单行显示（fontSize 18，卡片宽约屏宽减 40），副标题建议 ≤18 字。

## 4. 配图规格

- 尺寸 **3072×1280**（约 2.4:1；App 卡片约 2.2:1，BoxFit.cover 裁切可接受），jpg，源图 ≤10MB（admin 上传会客户端压缩）
- 构图：主体偏右侧 2/3，**左侧相对干净**——白色标题叠在左侧，且叠加自上而下黑渐变（25%→55%），需避免过曝高光压过白字
- 三张色调统一：暖橙金、低饱和生活感，避免纯影棚感

## 5. admin 配置清单（每条填写方式）

进入 admin → 首页运营 Banner → 新建，逐条填写：

| 字段 | banner 1 | banner 2 | banner 3 |
|------|----------|----------|----------|
| Banner ID | `banner_autumn_cafe` | `banner_autumn_sweater` | `banner_autumn_street` |
| 角标 tag | 秋日企划 | 秋日企划 | 秋日企划 |
| 主标题 | 把秋天装进一杯咖啡 | 换上毛衣的温柔秋天 | 落叶铺满的午后街道 |
| 副标题 | 窗边暖光，拍出慵懒的秋日氛围 | 针织质感与暖茶，记录换季时刻 | 金色光影，随手一拍都是秋天 |
| 配图 | `autumn_cafe.jpg` | `autumn_sweater.jpg` | `autumn_street.jpg` |
| 类型 | 搜索 | 搜索 | 搜索 |
| 搜索关键字 | 秋 | 秋 | 秋 |
| 搜索范围 | all | all | all |
| 槽位 | 0 | 1 | 2 |
| 状态 | 启用 | 启用 | 启用 |

- 焦点 X/Y/缩放：默认 0.5/0.5/1，上传后可按预览微调
- 路由/条件字段在 kind=search 下不参与跳转，保持默认即可

## 6. 代码改动清单

| 文件 | 改动 |
|------|------|
| `lumira-server/packages/admin/src/components/banner-manager.tsx` | 槽位输入框：`disabled={form.kind !== 'ad'}` → `disabled={form.kind === 'operation'}`；label「广告槽位（留空=最后）」→「槽位（留空=最后）」 |

- 改动完成后 commit 并 push 双远程（origin=gitee、github），admin 由 Vercel 自动部署
- 三张配图输出至 `assets/autumn-banner/`（`autumn_cafe.jpg` / `autumn_sweater.jpg` / `autumn_street.jpg`，文件名与第 5 节清单一一对应）

## 7. 风险与验收

1. **搜索结果非空前置校验**：配置前先在 App 搜索页试搜「秋」，确认有结果；为空则先上架秋季模板/场景，或与运营确认改用其他关键词（如已有模板标签「秋日」）。
2. **生效时间**：写操作即时失效缓存，正常 ≤60s；配置后冷启 App 验收：轮播前三位为秋季 banner、点击跳搜索页并预填「秋」、文案与配图显示正常。
3. **活动结束**：后台将三条一键停用（isActive=0），App 端轮播自动恢复原状，无需发版。
4. **App 端 fail-safe**：远端条目 route/condition 校验、`searchKeyword` 缺失整条丢弃；本方案均为合法配置，不受影响。
