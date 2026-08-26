# 模板收藏功能设计（2026-08-26）

> 功能设计文档，存放于 `docs/specs/`。登记「后续优化」内容见 `docs/future-optimizations.md`。

## 1. 目标

为模板（内置 / 自定义 / 远程等**所有来源**）增加**收藏**能力：用户可对任意模板收藏 / 取消收藏，并在「全部模板」页只查看已收藏的模板。收藏状态**本地持久化**、按**模板 + 用户**维度隔离，不上报后端。

## 2. 已确认决策

1. **独立收藏表**，不在 `custom_templates` 原表上新增布尔字段 `is_favorite`。收藏状态体现为「该模板是否存在于收藏集合」。
2. **覆盖线上（remote）模板**：remote 模板同步后本地也有唯一 id，收藏的是同步后的本地 id，天然支持全来源。
3. **每个用户收藏不同**：收藏表按 `template_id` 主键独立存储，具备未来扩展 `user_id` / `device_id` 维度的空间（当前 App 无多账号体系，暂不引入用户列）。
4. **存储仅本地 SQLite**，不改后端 `lumira-server`（与照片收藏、通知读状态一致的「离线优先」风格）。
5. **收藏入口**：模板详情页右上角红心按钮 + 「全部模板」页 `_FilterSection` 新增「收藏」过滤 toggle。
6. **存量模板默认未收藏**（收藏集合中不存在即未收藏）。
7. **改后端 / 后台需 commit 并双远端 push 的规则不适用**（本次无后端改动）。

## 3. 整体架构与数据流

```
Flutter(本地);
  模板详情页 / 全部模板页
        │  调用 TemplatesFavoriteDao
        ▼
   sqflite ─ template_favorites 表（template_id → 收藏时间）
        │  写库后 invalidate 收藏 provider → rebuild 刷新红心态 / 收藏列表计数
        ▼
   模板来源（builtin / custom / remote）共用 custom_templates 的 id 作为收藏外键
```

- 收藏与取消：写 `template_favorites`（INSERT / DELETE），随后刷新 provider 驱动 UI。
- 展示：详情页红心状态、全部模板页「收藏」toggle 均从收藏表读取。

## 4. 数据库设计

### 4.1 新增表 `template_favorites`（migration v42）

| 列 | 类型 | 说明 |
|---|---|---|
| `template_id` | TEXT PK | 收藏的模板 id（参照 `custom_templates.id`，覆盖全来源） |
| `created_at` | INTEGER | 收藏时间（毫秒时间戳，收藏列表按此倒序） |

- 不创建 ON DELETE CASCADE（模板可能被重建，收藏状态保留无副作用；由 UI 层决定是否已有模板）。
- 索引：`template_id` 即主键，无需额外索引。

相关常量添加位置：
- `core/db/tables.dart`：新增表名 `templateFavorites` 与列名 `colTemplateFavoriteTemplateId` / `colTemplateFavoriteCreatedAt`（或复用 `colCreatedAt` 常量）。

### 4.2 DAO（`core/db/dao/templates_favorite_dao.dart` 新增）

独立 DAO，避免混入 `TemplatesDao` 负担：

- `Future<bool> isFavorite(String templateId)`
- `Future<void> addFavorite(String templateId)`（INSERT OR REPLACE）
- `Future<void> removeFavorite(String templateId)`
- `Future<bool> toggleFavorite(String templateId)`（返回切换后的收藏态）
- `Future<List<String>> getFavoriteIds()`（按 created_at DESC）
- `Future<int> countFavorites()`

`database_provider.dart` 新增 `templatesFavoriteDaoProvider`，供 `templatesDaoProvider` 同层注册。

### 4.3 Provider

`features/templates/data/templates_providers.dart` 新增：

- `favoriteTemplateIdsProvider`（`FutureProvider<Set<String>>`：已收藏 id 集合，写库后 invalidate）
- `favoriteCountProvider`（可选用：收藏计数）

## 5. Flutter 设计

### 5.1 模板详情页红心按钮

文件：`features/templates/pages/templates_detail_page.dart`

- 在顶部 `LumiraNav` 的 `actions` 中加入收藏按钮（红心 `Icons.favorite` / `Icons.favorite_border`）。
- 位置策略：重构 `_navActions(tokens, isLocked)`，使收藏按钮**始终为 actions 中的第一个**，再按现状追加原分支按钮：
  - 我的模板（自定义/导入）→ `[❤, 导出?, 编辑]`
  - 付费未解锁 → `[❤, 积分 chip]`
  - 其余（免费 / 已解锁付费）→ `[❤]`
  - （即收藏按钮恒存在，其余分支按钮原样保留）
- 交互：点击 → `toggleFavorite(template.id)` → toast（「已收藏 / 已取消收藏」）→ `ref.invalidate(favoriteTemplateIdsProvider)`。
- 红心实心态按主题风格着色 `tokens.brand`（实心）与 `tokens.textSecondary`（空心），沿用 `LumiraIconButton` 的 `color` 参数与呼吸按压反馈（`breathing_tap.dart`）。

### 5.2 「全部模板」页收藏 toggle

文件：`features/templates/pages/templates_all_page.dart`

- 在 `_FilterSection` 底部、与既有「我的」toggle（`_CustomToggle`，`showCustom`）并排，新增「收藏」toggle（`showFavorites`）。
- 顶层 state 新增 `bool _showFavorites = false`，筛选逻辑取交集：`_showFavorites` 时仅保留 `favoriteTemplateIdsProvider.contains(t.id)` 的模板。
- 选中「收藏」时清空/忽略价格与分类层级筛选的冲突处理与「我的」toggle 一致（可叠加）。
- 空结果显示既有的「暂无模板」占位即可。

## 6. 错误处理与边界

- **database 读写失败**：沿用现有 DAO 静默降级（`try/catch` + `debugPrint`），不对用户弹错误，功能降级为「无收藏态」。
- **模板已删除但仍在收藏表**：收藏 toggle 页虽能标记，但详情不可进入；收藏列表渲染时按 `id` 过滤已存在模板。属边缘情况，登记后续优化可选清理。
- **重复收藏**：`INSERT OR REPLACE` / 先查后插，保证幂等。

## 7. 测试

- `templates_favorite_dao` 单元测试：add/remove/toggle/isFavorite/count/getFavoriteIds 的正确性与幂等性。
- 手工验证：详情页红心切换、收藏列表筛选、内置/自定义/远程三种来源模板均可用，UI 风格随主题切换（红心实心/空心配色、呼吸按压反馈）。

## 8. 改动文件清单

| 文件 | 改动 |
|---|---|
| `core/db/tables.dart` | 新增 `template_favorites` 表名 / 列名常量 |
| `core/db/database_provider.dart` | `_kDbVersion` 41→42；migration 建表；注册 `templatesFavoriteDaoProvider` |
| `core/db/dao/templates_favorite_dao.dart` | 新增 DAO（add/remove/toggle/isFavorite/count/getFavoriteIds） |
| `features/templates/data/templates_providers.dart` | 新增 `favoriteTemplateIdsProvider`（及可选 `favoriteCountProvider`） |
| `features/templates/pages/templates_detail_page.dart` | 详情页顶部红心收藏按钮 |
| `features/templates/pages/templates_all_page.dart` | `_FilterSection` 新增「收藏」toggle + 筛选逻辑 |

## 9. 后续优化（登记 `docs/future-optimizations.md`）

- 收藏列表集中页（独立「我的收藏」Tab/页面）与按收藏时间分组。
- 收藏表引入 `user_id` / `device_id` 维度 + 后端同步（多端一致）。
- 清理「模板已删除的孤立收藏记录」。