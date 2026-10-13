# 秋季首页 Banner 运营位实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付 3 张秋季主题 banner 配图与 admin 填值清单，并修复 admin 槽位输入框对 `kind=search` 的禁用问题，使运营可在后台手动配置 3 条前排（position 0/1/2）搜索型 banner。

**Architecture:** banner 全部数据驱动（`operation_banners` 表 + admin 后台 + `GET /api/v1/banners`），App/后端零改动。唯一代码改动是 admin 组件 `banner-manager.tsx` 放开 search 类型的槽位编辑（后端与 Flutter 均已支持 search+position）。配图为 AI 生成素材，经 admin 上传后由后端存储持久化，本地文件不入 git。

**Tech Stack:** Next.js admin（`pnpm --filter @lumira/admin build` 验证）、GenerateImage 生图（3072×1280）。

**Spec:** `docs/superpowers/specs/2026-10-13-autumn-banner-design.md`

## Global Constraints

- 配图：3072×1280（约 2.4:1），画面内不得出现任何文字；主体偏右 2/3，左侧干净（白色文案叠左侧 + 黑渐变）；三张统一暖橙金低饱和胶片感、场景互不重复
- banner 字段值严格按 spec 第 5 节：id `banner_autumn_cafe` / `banner_autumn_sweater` / `banner_autumn_street`，tag 秋日企划，关键字 `秋`，scope `all`，槽位 0/1/2
- 代码改动仅限 `lumira-server/packages/admin/src/components/banner-manager.tsx`；禁止改后端 / Flutter
- admin 改动属功能增强：commit 后必须 push 双远程（`git push origin master` = gitee、`git push github master` = github），Vercel 自动部署 admin
- 配图输出到 `assets/autumn-banner/`，保持 untracked（不入 git）
- 后端写操作缓存 ≤60s 生效；配置属运营手工步骤，不在本计划内

---

### Task 1: 生成三张秋季 banner 配图

**Files:**
- Create: `assets/autumn-banner/autumn_cafe`（扩展名由生图工具决定，实际路径以工具返回为准）
- Create: `assets/autumn-banner/autumn_sweater`
- Create: `assets/autumn-banner/autumn_street`

**Interfaces:**
- Consumes: spec 第 3/4 节的场景与风格定义
- Produces: 三张本地图片文件（Task 3 素材清单引用其文件名与实际扩展名）

- [ ] **Step 1: 创建输出目录**

Run: `New-Item -ItemType Directory -Force -Path assets/autumn-banner`
Expected: 目录存在（已存在则跳过）

- [ ] **Step 2: 生成第 1 张（咖啡馆窗边）**

调用 GenerateImage，参数 `image_size: "3072x1280"`，`path: assets/autumn-banner/autumn_cafe`，prompt：

```
[PURPOSE]: Wide horizontal banner image for a photo app's autumn campaign, will be displayed full-bleed on a banner card with white text overlaid on the left side.
Cozy autumn lifestyle photography: a woman's hands cradling a warm ceramic mug of coffee by a cafe window, soft window light casting window-grid shadows, golden maple leaves resting on the windowsill, warm amber and honey tones, low saturation film aesthetic, shallow depth of field, main subject positioned in the right two-thirds, left third softly blurred and visually clean for text overlay, photorealistic, no text, no watermark
```

- [ ] **Step 3: 生成第 2 张（毛衣暖茶）**

调用 GenerateImage，参数同上，`path: assets/autumn-banner/autumn_sweater`，prompt：

```
[PURPOSE]: Wide horizontal banner image for a photo app's autumn campaign, will be displayed full-bleed on a banner card with white text overlaid on the left side.
Warm autumn lifestyle still photography: chunky knit beige sweater sleeve resting beside a steaming cup of hot tea on a rustic wooden table, a few dried fallen leaves and a linen napkin nearby, soft golden afternoon light, warm orange low-saturation palette, cozy film-like mood, subject in the right two-thirds, left third calm negative space for text overlay, photorealistic, no text, no watermark
```

- [ ] **Step 4: 生成第 3 张（落叶街道）**

调用 GenerateImage，参数同上，`path: assets/autumn-banner/autumn_street`，prompt：

```
[PURPOSE]: Wide horizontal banner image for a photo app's autumn campaign, will be displayed full-bleed on a banner card with white text overlaid on the left side.
Autumn afternoon street photography: a quiet tree-lined street carpeted with golden fallen leaves, warm sunlight filtering through branches creating gentle backlight haze, a single person walking away in the distance on the right side, warm amber low-saturation film palette, left third of frame calm and clean for text overlay, photorealistic, no text, no watermark
```

- [ ] **Step 5: 视觉验收三张图**

用 Read 工具逐张查看生成结果，逐项核对：
1. 画面内无任何文字/水印
2. 主体位于右侧 2/3，左侧 1/3 无杂乱细节
3. 暖橙金低饱和、三张色调统一
4. 场景互不重复（窗边咖啡 / 毛衣热茶 / 落叶街道）

不达标的图：调整 prompt（如补 "clean uncluttered left side"、"darker muted tones"）后重新生成该张，直到 4 项全部通过。

- [ ] **Step 6: 记录实际文件名**

用 Glob 确认 `assets/autumn-banner/` 下三个实际文件路径（含真实扩展名），供 Task 3 清单引用。

---

### Task 2: admin 槽位输入框放开 search 类型

**Files:**
- Modify: `lumira-server/packages/admin/src/components/banner-manager.tsx`（约 L602-L610）

**Interfaces:**
- Consumes: 现有表单 state `form.kind` / `form.position`
- Produces: `kind=search` 时槽位输入框可编辑；payload 逻辑不变（L259 已无条件提交 position）

- [ ] **Step 1: 定位并修改槽位输入框**

Read `banner-manager.tsx` L595-L615 确认现状，然后做两处修改：

```tsx
// 1. label（原「广告槽位（留空=最后）」）
<Label htmlFor="bnr-position">槽位（留空=最后）</Label>

// 2. disabled 条件（原 disabled={form.kind !== 'ad'}）
disabled={form.kind === 'operation'}

// 3. placeholder（原「如：4」）
placeholder="如：0"
```

- [ ] **Step 2: 全文检查无其他 position 门控**

Grep `banner-manager.tsx` 中 `position`：确认提交逻辑（约 L259）与表单回填（约 L167）不区分 kind，无需其他改动；确认无其他 `kind !== 'ad'` 门控残留影响 search。

- [ ] **Step 3: 构建验证**

Run:
```
pnpm --filter @lumira/shared build
pnpm --filter @lumira/admin build
```
Expected: 两步均成功退出（exit 0），无 TypeScript 错误。

- [ ] **Step 4: Commit 并 push 双远程**

```bash
git add lumira-server/packages/admin/src/components/banner-manager.tsx
git commit -m "fix(admin): banner 槽位输入框对 search 类型开放编辑"
git push origin master
git push github master
```

Expected: push 均成功；admin-deploy.yml（Vercel 构建验证）与后台部署随之触发。

---

### Task 3: 交付素材清单

**Files:**
- 无新文件（填值清单已在 spec 第 5 节；本任务产出最终交付消息）

**Interfaces:**
- Consumes: Task 1 实际图片文件名（含扩展名）、spec 第 5 节清单
- Produces: 面向运营的最终交付说明（对话消息，含 admin 操作步骤与验收要点）

- [ ] **Step 1: 汇总交付消息**

输出最终消息，包含：
1. 三张图片的本地路径（Task 1 Step 6 的实际文件名），提示图片未入 git、配置完成后可自行删除或留存
2. spec 第 5 节填值清单全文（三条 banner 的字段对照）
3. admin 操作路径：后台 → 首页运营 Banner → 新建，逐条填写（类型选「搜索」，槽位依次 0/1/2——该输入框本次已放开）
4. 配置前置校验：先在 App 搜索页试搜「秋」确认结果非空
5. 验收要点：保存后 ≤60s 生效；App 冷启核对轮播前三位为秋季 banner、点击跳搜索页并预填「秋」；活动结束后台停用三条即恢复
6. 提醒：admin 改动已 push 双远程，等待 Vercel 部署完成（约 1-3 分钟）后再开始配置

## Self-Review 记录

1. **Spec 覆盖**：spec 第 2 节方案 5 点 → Task 2（UI 修复）+ Task 3（清单/流程）；第 3/4 节图片 → Task 1；第 5 节清单 → Task 3 引用；第 6 节改动与 push → Task 2；第 7 节风险校验 → Task 3 交付消息。无缺口。
2. **占位符扫描**：无 TBD/TODO；所有代码步骤含实际修改内容；图片 prompt 完整。
3. **类型/命名一致性**：id/tag/关键字/槽位值与 spec 第 5 节逐字一致；文件名 `autumn_cafe/sweater/street` 与 spec 第 6 节一致（扩展名以工具实际输出为准，Task 1 Step 6 兜底）。
