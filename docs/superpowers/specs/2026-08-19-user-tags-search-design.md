# 用户自定义标签 & 搜索 设计方案

日期：2026-08-19
状态：已批准

## 1. 背景与目标

模板（后端同步 + 本地 sqflite）与场景（纯本地 sqflite）已各自具备系统级的 `tags` / `tagIds` /
`recommendedTagIds` 元数据（由 admin / 内置数据提供，用户不可编辑）。用户希望：

1. **用户可给任意模板 / 任意场景打自定义标签**，标签名由用户自定义。
2. 后续搜索时，**可通过标签搜索 / 筛选**对应的模板与场景。
3. 开发**场景搜索页**与**模板搜索页**。

### 已确认的关键决策

- **存储**：仅本地 sqflite，按设备存储，不上传后端。
- **模型**：规范化多对多（方案 A）：`user_tags`（标签字典）+ `item_tags`（绑定关系），同名标签跨条目共享去重。
- **作用范围**：标签收纳 + 按标签筛选 + 搜索关键词匹配标签，三者都要。
- **融合**：搜索 / 筛选时把模板自带的系统标签（admin 打的 `tags`）也纳入标签体系。
- **入口**：两个搜索页能力 + 独立的「我的标签」标签夹页，都要。

## 2. 数据模型与迁移

### 2.1 新表

```sql
-- 标签字典（同名去重，跨条目共享）
CREATE TABLE IF NOT EXISTS user_tags (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL UNIQUE,   -- 用户自定义标签名（trim 后唯一）
  created_at  INTEGER NOT NULL
);

-- 标签 ↔ 内容绑定（多对多）
CREATE TABLE IF NOT EXISTS item_tags (
  item_type   TEXT NOT NULL,          -- 'template' | 'scene'
  item_id     TEXT NOT NULL,
  tag_id      INTEGER NOT NULL REFERENCES user_tags(id),
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (item_type, item_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_item_tags_tag_id ON item_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_type, item_id);
```

- `user_tags.name` 唯一索引保证去重。
- `idx_item_tags_tag_id`：查「某标签下所有内容」（标签夹 / 筛选）。
- `idx_item_tags_item`：查「某内容的所有标签」。
- **归属**：本地单机单用户，无需 deviceId 字段。

### 2.2 迁移

- `_kDbVersion`：23 → **24**（`database_provider.dart`）。
- `_onCreate`：新增建表语句（新装用户）。
- `_onUpgrade`：新增 `if (oldVersion < 24)` 建表（老用户升级）。
- 全部用 `CREATE TABLE IF NOT EXISTS`，幂等。

## 3. 数据访问层（TagsDao + Riverpod Providers）

新增 `core/db/dao/tags_dao.dart`，字段常量加入 `core/db/tables.dart`，并新增 `userTagsDaoProvider`，
注册进 `core/db/database_provider.dart`。

### 3.1 TagsDao 方法

| 方法 | 说明 |
|---|---|
| `addTag(itemType, itemId, name)` | 打标签：name 不存在则建、存在则复用，返回绑定记录（幂等） |
| `removeTag(itemType, itemId, tagId)` | 取消标签绑定 |
| `deleteTag(tagId)` | 删除一个标签（级联删除所有绑定） |
| `renameTag(tagId, newName)` | 标签改名（新名 trim 后唯一性校验） |
| `tagsFor(itemType, itemId)` | 查一个模板 / 场景的所有用户标签 |
| `itemIdsByTag(itemType, tagId)` | 某标签下所有 item_id |
| `allTags({itemType})` | 全部用户标签（含各自绑定数量 count，供标签夹 / 筛选栏） |
| `searchByKeyword(query)` | 关键词匹配（名称 / 标签名）回传匹配 id |

`allTags` 通过 join `item_tags` 聚合 count，一次 SQL 完成，本地 sqlite 无性能问题。

### 3.2 Providers

- `templatesWithTagsProvider`、`scenesWithTagsProvider`：列表附带标签。
- `tagsFilterProvider`（AsyncNotifier）：当前选中的标签筛选条件，供搜索页 / 标签夹共享。
- 打标签 / 删除后通过 `ref.invalidate(...)` 刷新（与现有 Riverpod 用法一致）。

## 4. 打标签 UI

在**模板详情页**与**场景详情页**各加一个「标签」区块，封装为可复用组件 `TagsSection`：

- **展示**：已打用户标签显示为 Chip（胶囊），点击 × 移除。
- **添加**：输入框 + 快速标签按钮，输入时联想已有标签名（来自 TagsDao），回车 / 选择即打标签。
- **融合展示**：模板详情同时展示系统标签（admin `tags`，只读）+ 用户标签（可增删），视觉区分（系统标签带「系统」角标或浅色）。
- **空状态**：无标签时显示引导文案「添加标签，方便日后查找」。

交互细节：
- 输入名 trim 后去重，空名忽略，超长（如 20 字）拦截。
- 添加 / 删除后 `ref.invalidate` 刷新，即时生效。

## 5. 搜索页 + 标签夹

### 5.1 模板搜索页 `TemplateSearchPage`、场景搜索页 `SceneSearchPage`

两页结构一致，复用基建组件：

- **顶部搜索框**：关键词实时匹配**名称、分类名、标签名**（用户标签 + 模板系统标签）。
- **标签筛选栏**：横向滚动标签 Chip 栏（融合用户标签 + 系统标签 + 场景分类 / 氛围等），点击筛选，可多选；选中标签下列出其下内容。
- **结果**：模板用现有 2 列 grid；场景用现有场景 grid。
- **入口**：模板 Tab 页右上增加搜索入口；场景库页右上搜索图标由占位 toast 改为跳转搜索页。

### 5.2 「我的标签」标签夹页 `MyTagsPage`

以标签为中心：
- 列出全部用户标签 + 关联内容数（count）。
- 顶部 tab 切换「模板 / 场景」，点标签进入结果（复用筛选 / 结果展示组件）。
- 支持删除标签（一次清理所有条目）、标签改名（可选）。

### 5.3 复用与共享状态

搜索页与标签夹复用同一套「标签筛选 + 结果网格」组件。`tagsFilterProvider` 承载筛选状态，页面间共享：
从标签夹点某标签可直接带入搜索页继续筛。

## 6. 路由

在 `core/router/route_names.dart` 新增三个路由：

- `templateSearch`
- `sceneSearch`
- `myTags`

## 7. 范围与验收

### 范围
- 本地 `user_tags` / `item_tags` 表 + 迁移（v24）。
- TagsDao + Providers。
- 模板 / 场景详情页打标签 UI（`TagsSection`）。
- 模板搜索页、场景搜索页。
- 「我的标签」标签夹页。
- 路由接入。

### 非范围（YAGNI）
- 标签上传后端 / 跨设备同步（账号恢复）——首个版本不做；若未来需要，`user_tags` 表结构与 `item_tags` 绑定关系可平滑迁移。
- admin 后台标签管理改动（admin 已有 `tags` 字段）。

### 验收要点
- 给任意模板 / 场景打标签成功持久化，重启可见。
- 同名标签跨条目共享去重，计数正确。
- 模板详情页系统标签 + 用户标签融合展示且系统标签只读。
- 搜索页关键词匹配名称 / 分类 / 标签；标签筛选（多选）正确。
- 标签夹按标签聚合展示、删除 / 改名生效。
- 老用户升级（v23→v24）不丢既有数据。

## 8. 测试策略

- TagsDao 单元 / DAO 层测试：add/remove/delete、同名去重、count 聚合、关键词匹配。
- Widget 测试：标签区块展示 / 增删交互、搜索页筛选。
- 现有 `flutter analyze + test` 全绿，不破坏既有功能。