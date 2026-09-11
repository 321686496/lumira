# 运营 Banner 支持跳转到「指定模板详情页」+ 后台可视化选择模板

## Context（背景）

当前「上新」等运营 Banner 的 `route` 被双端白名单锁定为三个固定值（`/invite`、`/points/wallet`、`/templates/unlock`），只能跳到统一的「模板解锁列表页」，无法指定跳到某个具体模板的详情页。

需求：让运营 Banner 能配一个「目标模板」，点击后跳到 `/templates/detail?templateId=xxx`；后台提供**可视化界面**（封面缩略图网格 + 名称/分类）来选择模板。

## 方案总览

采用「route 固定为 `/templates/detail` + 独立 `templateId` 字段」的方式（不清放行带 query 的 route 字符串，保持双端 fail-safe 精确白名单设计）：

- 后端 `operation_banners` 表新增 `template_id` 列；白名单 `OPERATION_BANNER_ROUTES` 增加 `/templates/detail`；下发 App 时附带 `templateId`。
- App `OperationBanner` 新增可选 `templateId`；白名单加 `/templates/detail`；点击前把 `route` 拼成 `/templates/detail?templateId=xxx`。
- 后台表单：route 选 `/templates/detail` 时展示模板可视化选择器（复用 admin 已有的 `api.listTemplates()`），选中后可自动把模板封面填为 Banner 配图。

---

## 一、后端（lumira-server/packages/backend）

1. **迁移** `src/database/migrations/034_banner_template_id.sql`
   ```sql
   ALTER TABLE `operation_banners`
     ADD COLUMN `template_id` VARCHAR(64) NULL DEFAULT NULL AFTER `route`;
   ```

2. **Schema** `src/database/schema.ts`（`operationBanners` 表，约 L318）
   - 在 `route` 后加：`templateId: varchar('template_id', { length: 64 }),`

3. **白名单** `src/modules/banners/operation-banner.rules.ts`
   - `OPERATION_BANNER_ROUTES` 增加 `'/templates/detail'`。

4. **DTO**
   - `dto/create-banner.dto.ts`：新增可选字段
     ```ts
     @IsOptional() @IsString() @MaxLength(64) templateId?: string;
     ```
   - `dto/update-banner.dto.ts`：同样新增可选 `templateId?: string`（null 不清除也要支持清除：更新时 `unset` 传空串/移除）。

5. **Service** `src/modules/banners/banners.service.ts`
   - `listForApp()`：result 的每个 item 增加 `templateId: r.templateId`。
   - `create()`：`values` 增加 `templateId: dto.templateId ?? null`。
   - `update()`：patch 增加 `if ('templateId' in dto) patch.templateId = dto.templateId || null;`。
   - `listAdmin()` / `getById()`：`...r` 展开已自动带上 `template_id`（列名），无需改。

---

## 二、后台（lumira-server/packages/admin）

1. **类型** `src/types/admin.ts`
   - `BannerAdminItem` 增加 `templateId?: string;`
   - `BannerPayload` 增加 `templateId?: string;`

2. **路由选项** `src/components/banner-manager.tsx`
   - `ROUTE_OPTIONS` 增加 `{ value: '/templates/detail', label: '模板详情（/templates/detail）' }`。
   - `FormState` / `EMPTY_FORM` / `openEdit()` 增加 `templateId`。
   - `handleSubmit()` 的 `payload` 增加 `templateId: form.templateId`；校验：route 为 `/templates/detail` 时必须选中模板。

3. **可视化模板选择器**（banner-manager.tsx 内）
   - `BannerManager` 增加 prop `templates: AdminTemplateListItem[]`。
   - route == `/templates/detail` 时，在表单中渲染「选择目标模板」控件：从 `templates`（带 `coverUrl`/`name`/`categoryName`）渲染缩略图网格/卡片，点击选中高亮；选中后显示所选模板名 + 封面。
   - 选中模板时**自动把其 `coverUrl` 填入 `imageUrl`**（作为 Banner 配图，运营位右侧 contain 展示模板封面，视觉统一）。
   - 若该模板已停用，仍允许展示但加「停用」角标。

4. **父页面** `src/app/dashboard/banners/page.tsx`
   - 用 `api.listTemplates({ pageSize: 200, isActive: true })` 拉模板列表，`<BannerManager banners={banners} templates={templates} />`。

---

## 三、Flutter App（lumira_app_flutter）

1. **模型** `lib/features/home/data/operation_banners.dart`
   - `OperationBanner` 构造函数/字段增加 `final String? templateId;`
   - 静态目录 3 条不传 `templateId`（保持不变）。
   - `kOperationBannerRoutes` 增加 `'/templates/detail'`。
   - `operationBannerFromJson()`：读取 `json['templateId']`；route == `/templates/detail` 且 templateId 为空 → 返回 null（fail-safe 丢弃）。
   - `operationBannerToItem()`：当 `banner.route == '/templates/detail' && banner.templateId != null` 时，`route: '/templates/detail?templateId=${banner.templateId}'`；其余原样。

2. **离线缓存** `lib/core/db/dao/settings_dao.dart`（约 L502-548 `setOperationBannersCache`）
   - 持久化与读回解析加入 `templateId` 字段，避免离线/重启丢失目标模板。

3. **点击层** `lib/features/home/widgets/home_banner.dart`
   - `onTap` 已 `GoRouter.push(banner.route)`，route 已在前一步拼好，**无需改动**。

---

## 验证

- **后端**：`cd lumira-server && pnpm --filter @lumira/backend build`（typecheck）；必要时跑 `banners.service.spec.ts`。
- **后台**：`cd lumira-server/packages/admin && pnpm build`。
- **App**：`cd lumira_app_flutter && flutter analyze`；补/跑 `test/features/home/operation_banners_test.dart`（新增解析 `templateId` 与 `/templates/detail` 白名单用例，确保旧用例不破）。
- **端到端**：后台新建/编辑一条 route=模板详情 的 Banner（选择模板）→ 保存 → 后端 DB 出现 `template_id` → App 首页拉取运营位点击跳转对应模板详情页，且离线态缓存仍能还原目标模板。