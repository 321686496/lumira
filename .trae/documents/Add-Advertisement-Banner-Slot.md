# 新增「活动/广告」Banner 槽位

## Context（背景与目标）

首页 Banner（`buildBanners`）当前固定 4 槽位：slot0 运营位（条件触达）、slot1 继续创作、slot2 场景留存、slot3 探索新鲜感，最终 `take(4)` 截断。

运营需要一条**可承接外部流量的广告通道**：在现有「后台 banners」里配置广告条目，可指定它显示在第几个槽位（绝对槽位号，默认放最后），点击后用系统浏览器打开外部 URL（不跳 App 内路由）。

方案 A（绝对槽位号）已与用户确认；「模板认知教育位」已确认不加。广告完全复用 `operation_banners` 链路，**不新增后台**，因此改动 = 表加 3 列 + 后端 DTO/service + admin 表单/类型 + Flutter 模型/解析/推荐服务/UI 跳转。

## 字段设计（在 operation_banners 上扩展，3 个新列）

| 字段 | DB 列 | 语义 | 默认 |
|------|-------|------|------|
| `kind` | `kind varchar(16)` | `operation`(现有运营位) / `ad`(广告) | `operation` |
| `position` | `position int` | 广告在轮播中的绝对槽位下标（`null` = 放最后） | null |
| `externalUrl` | `external_url varchar(512)` | 广告点击跳转的外部 URL（kind=ad 时必填） | null |

- 现有 `route`（NOT NULL）对广告不可用（跳外部），运营侧按 `kind=ad` 可留空或任意值；App 解析时 kind=ad 以 `externalUrl` 为准，跳过 route 白名单。
- `condition` 对广告不参与 slot0 条件匹配；广告是否展示仅由 `is_active`（活动开关）驱动。离线/远端拉取失败时无广告（可接受，广告靠远端下发）。

## 后端改动（lumira-server）

### 1. 迁移 `packages/backend/src/database/migrations/036_banner_ad_slot.sql`（新建）
```sql
ALTER TABLE operation_banners
  ADD COLUMN kind varchar(16) NOT NULL DEFAULT 'operation' AFTER condition,
  ADD COLUMN position int DEFAULT NULL AFTER sort_order,
  ADD COLUMN external_url varchar(512) DEFAULT NULL AFTER position;
```

### 2. `packages/backend/src/database/schema.ts`
在 `operationBanners` 表定义（L320-335）追加三列：`kind`、`position`、`externalUrl`。

### 3. DTO `dto/create-banner.dto.ts` 与 `dto/update-banner.dto.ts`
- 新增 `kind?: string`（`@IsIn(['operation','ad'])`，默认 `operation`）。
- 新增 `position?: number`（`@IsOptional() @IsInt()`）。
- 新增 `externalUrl?: string`（`@IsOptional() @IsString() @MaxLength(512)@IsUrl()` 或简单 `@IsString`，与现有风格一致用 `@IsString`）。
- 放宽 `route`：`@ValidateIf((o) => o.kind !== 'ad')` + 现有 `@IsIn(OPERATION_BANNER_ROUTES)`；`externalUrl` 在 `kind==='ad'` 时必填。

### 4. `modules/banners/banners.service.ts`
- `listForApp`（L56-70）：返回映射追加 `kind`、`position`、`externalUrl`。
- `create`（L95-111）/ `update`（L119-132）：写入/更新 `kind ?? 'operation'`、`position ?? null`、`externalUrl ?? null`（error: update 用 `'externalUrl' in dto` 语义，与 `templateId` 一致）。

## 后台改动（packages/admin）

- `types/admin.ts`：`BannerAdminItem` 与 `BannerPayload` 追加 `kind`、`position`、`externalUrl`。
- `components/banner-manager.tsx`：
  - `FormState`（L55-69）/ `EMPTY_FORM`（L71-85）/ `openEdit`（L137-157）加 `kind`(默认 `operation`)、`position`、`externalUrl`。
  - payload 构造（L219-234）加上三项。
  - 表单渲染加：种类下拉（运营位/广告）、外部 URL 输入（kind=ad 时显示/必填）、槽位号数字输入（位置，留空=放最后）。
  - kind=ad 时提示「点击将用浏览器打开外部 URL」。

## Flutter 客户端改动（lumira_app_flutter）

### 1. `lib/features/home/data/operation_banners.dart`
- 定义 `enum OperationBannerKind { operation, ad }`。
- `OperationBanner` 加 `kind`（默认 `operation`）、`position`（`int?`）、`externalUrl`（`String?`）。
- `operationBannerFromJson`（L143-186）：
  - 解析 `kind`（`ad`→ad，否则 operation）、`position`（`num`→int）、`externalUrl`。
  - kind=operation：维持现有 route 白名单 + condition 校验。
  - kind=ad：跳过 route 白名单，改为 `externalUrl` 非空才通过。
- `operationBannerToItem`（L207-227）：把 `externalUrl` 透传给 `HomeBannerItem`。

### 2. `lib/features/home/data/home_mock_data.dart`
`HomeBannerItem`（L104-155）追加 `this.externalUrl`（`String?`，默认 null），不破坏既有 const 构造。

### 3. `lib/features/home/services/recommendation_service.dart`
- `buildBanners`（L99-324）：
  - 开篇把 `operationBanners` 拆成 `ads` 与 `ops` 两份；`matchOperationBanner(banners: ops, ...)`（slot0 只认运营，不算广告）。
  - `// === 老用户补位` 之后、`return` 之前，追加广告插入：
    ```
    for (final ad in ads) {
      final insertAt = (ad.position != null && ad.position! >= 0 && ad.position! < banners.length)
          ? ad.position! : banners.length; // 越界/空 = 放最后
      banners.insert(insertAt, operationBannerToItem(ad));
    }
    ```
  - 删除 `return banners.take(4).toList()`，改为 `return banners;`（广告按 position 归位后自然为末尾/指定位）。
  - 更新 L94 方法注释（4 槽 → 运营位 + 广告位 + 个性化）。

### 4. `lib/features/home/widgets/home_banner.dart`
`onTap`（L245-251）：点击埋点保留；`externalUrl` 非空 → `url_launcher` 打开，否则 `GoRouter.push(banner.route)`。

## 验证（Verification）

1. **后端**：`pnpm --filter @lumira/backend` 相关 typecheck/build（沿用仓库既有脚本，如 `pnpm build` / `tsc`），确认新列/DTO/service 无类型错误。
2. **后台**：`pnpm --filter @lumira/admin build` 或 dev 起本地，确认表单新字段可渲染、payload 含新字段。
3. **Flutter**：`dart analyze lib/features/home` 无新问题；运行既有 banner 单测（如 `banner_recommendation*`），新增/确认广告槽位用例（kind=ad 跳外部、position 越界落最后、广告不入 slot0）。
4. **端到端**：后台建一条 `kind=ad` + `position` 留空 + `externalUrl` 的广告 → App 拉 `/banners` → 首页轮播末位出现广告卡 → 点击用浏览器打开外部 URL；`condition` 广告不参与 slot0 运营匹配。

## 收尾（按 AGENTS.md 强制）

后端 + 后台有改动，完成并自测后**必须 git commit 并同时 push 两个远程**：
- `git push origin master`（gitee）
- `git push github master`（github）