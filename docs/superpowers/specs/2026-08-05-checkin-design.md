# 探店打卡功能设计文档

- **日期**：2026-08-05
- **主题**：将灵感页"探店打卡"卡片从静态 mock 实现为真实功能（记录探店足迹）
- **方案**：方案 A（`checkins` + `checkin_photos` 双表，纯本地 sqflite 存储）
- **范围**：Flutter 客户端（仅 `lumira_app_flutter/`，uni-app 已废弃不改）

---

## 1. 决策汇总

| 决策项 | 选择 |
|---|---|
| 记录产生方式 | 组合方案：手动新增为主 + 相册照片详情页「记录探店」入口预填 |
| 页面范围 | 列表页 + 详情页 + 新增/编辑页（三页闭环） |
| 照片关联 | 每条足迹关联 1-9 张照片（仿 `collection_photos` 双表） |
| 数据存储 | 纯本地 sqflite，不同步后端（后续需要再加同步层） |
| 记录字段 | 基础四件套（店名/地点/日期/照片）+ 评分 1-5 星 + 心得 + 分类标签 |
| 编辑删除 | 详情页支持编辑 + 删除（删除需确认弹窗） |
| 卡片接入 | `CheckinCard` 改读真实 provider，条目点击进详情、总数进列表 |
| 分类标签 | 预置 7 类（咖啡/甜品美食/艺术展览/书店/时尚买手/公园自然/其他），延续彩色图标风格 |

---

## 2. 数据模型

### 2.1 表结构（DB 版本 v14 → v15）

**表 1：`checkins`**（足迹主表）

```sql
CREATE TABLE checkins (
  id          TEXT PRIMARY KEY,            -- uuid
  name        TEXT NOT NULL,               -- 店名（必填）
  place       TEXT NOT NULL DEFAULT '',    -- 地点（选填）
  category    TEXT NOT NULL DEFAULT '',    -- 分类 key（预置集合之一，可为空串=未分类）
  rating      INTEGER NOT NULL DEFAULT 0,  -- 评分 1-5，0 = 未评
  note        TEXT NOT NULL DEFAULT '',    -- 心得文字
  visited_at  INTEGER NOT NULL,            -- 打卡日期（毫秒时间戳，默认当天）
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);
```

**表 2：`checkin_photos`**（照片关联表，仿 `collection_photos`：联合主键 + FK 级联删除）

```sql
CREATE TABLE checkin_photos (
  checkin_id TEXT NOT NULL,
  photo_id   TEXT NOT NULL,                -- 关联 gallery_items.id
  position   INTEGER NOT NULL DEFAULT 0,   -- 照片顺序
  PRIMARY KEY (checkin_id, photo_id),
  FOREIGN KEY (checkin_id) REFERENCES checkins(id) ON DELETE CASCADE
);
```

建表常量进 `lib/core/db/tables.dart`（`CheckinTable` / `CheckinPhotoTable`），迁移挂 `lib/core/db/database_provider.dart` 的 `_onCreate`（全量 batch）与 `_onUpgrade`（v15 增量，幂等）。

### 2.2 分类标签（`checkin_categories.dart` 常量）

| key | 标签 | 图标 | 图标色 | 底色 |
|---|---|---|---|---|
| coffee | 咖啡 | `Icons.coffee_outlined` | #B8860B | #FFF5E6 |
| dessert | 甜品美食 | `Icons.cake_outlined` | #C47C7C | #FFF0F0 |
| art | 艺术展览 | `Icons.account_balance_outlined` | #6B5E4E | #EDE8E0 |
| bookstore | 书店 | `Icons.menu_book_outlined` | #7B5EA7 | #F0E6FF |
| fashion | 时尚买手 | `Icons.checkroom_outlined` | #C4783C | #FFF0E0 |
| nature | 公园自然 | `Icons.park_outlined` | #5A7A48 | #E8F5E4 |
| other | 其他 | `Icons.place_outlined` | brand | brandSubtle |

结构仿 `CheckinEntry`（`key/label/icon/iconColor/iconBgColor`），提供 `categoryOf(key)` 查找与兜底 other。

### 2.3 模型类

- `CheckinRecord`：`id / name / place / category / rating / note / visitedAt / createdAt / updatedAt`，`fromRow(Map<String, Object?>)`。
- `CheckinDetail`：`CheckinRecord + List<GalleryItemRecord> photos`（按 position 排序），详情页与卡片封面用。

### 2.4 DAO：`CheckinDao`（`features/checkin/data/checkin_dao.dart`）

构造注入 `Database`，方法：

| 方法 | 说明 |
|---|---|
| `insert(CheckinRecord)` | 插入主表 |
| `update(CheckinRecord)` | 更新主表（含 updated_at） |
| `delete(String id)` | 删主表，级联删照片关联 |
| `getById(String id)` | 单条 |
| `getAll()` | 全部，按 `visited_at` DESC |
| `countAll()` | 总数 |
| `replacePhotos(String checkinId, List<String> photoIds)` | 事务内先删后插，保持 position 顺序 |
| `getPhotoIds(String checkinId)` | 按 position 升序返回 photo_id 列表 |

### 2.5 Provider（`features/checkin/data/checkin_providers.dart`，FutureProvider 范式）

```dart
final checkinDaoProvider = FutureProvider<CheckinDao>(...);           // 注册进 database_provider.dart（与既有 DAO provider 同处）
final checkinsProvider = FutureProvider<List<CheckinRecord>>(...);    // getAll
final checkinTotalCountProvider = FutureProvider<int>(...);           // countAll
final checkinDetailProvider = FutureProvider.family<CheckinDetail?, String>(...); // getById + getPhotoIds + gallery 关联
```

---

## 3. 路由与页面

### 3.1 路由（`route_names.dart` + `router.dart`）

| 路径 | 页面 | 参数 |
|---|---|---|
| `/checkin/list` | 探店足迹列表 | 无 |
| `/checkin/detail` | 足迹详情 | `?checkinId=` |
| `/checkin/edit` | 新增/编辑（复用） | `?checkinId=`（编辑）/ `?photoId=`（相册入口预填） |

注册为 `GoRoute(path, name, builder)`，参数用 `state.queryParams`，与 `?sceneId=` 同款写法。

### 3.2 列表页 `CheckinListPage`

- `LumiraNav(title: '探店足迹')` 默认返回按钮 + 右上角「+」新增 → edit 页
- 顶部统计卡：足迹总数
- 足迹卡片（时间倒序）：封面图（第一张照片，无照片用分类彩色图标占位）+ 店名 + 分类 tag + 评分星 + 地点/日期
- 条目点击 → 详情页；`.when` 三态；空态引导文案 + 新增按钮

### 3.3 详情页 `CheckinDetailPage`

- 照片区：横向滑动 1-9 张（4:3），无照片显示分类图标占位
- 信息区：店名 + 评分星 + 分类 tag + 日期 + 地点 + 心得
- AppBar 右上角：编辑（→ edit 带 checkinId）、删除（确认弹窗 → 删库 → invalidate → 返回列表）

### 3.4 新增/编辑页 `CheckinEditPage`

- 店名输入（必填，空时保存拦截 + 提示）
- 地点输入（选填）
- 日期选择（默认当天，日期选择器）
- 评分：5 星点选（可清零）
- 分类：7 个预置 tag 单选
- 心得：多行输入
- 照片：相册选 1-9 张（预览/移除/排序），`photoId` 参数到达自动预填，超 9 张 Toast
- 保存：`ref.read(checkinDaoProvider.future)` → insert 或 update + replacePhotos → `ref.invalidate(...)` → 返回

### 3.5 相册入口

相册单张照片详情页加「记录探店」操作项 → push `checkinEdit?photoId=xxx`。

### 3.6 卡片接入（`CheckinCard` 改造）

- 改 watch `checkinsProvider` + `checkinTotalCountProvider`，替换 `InspirationMockData` 读取
- 展示最近 3 条；条目点击 → 详情页；「N 个探店足迹」数字 → 列表页
- 空态：引导文案 + 点击进入新增页；loading/error 兜底保持卡片外观

---

## 4. 数据流

所有写操作统一模式（仿挑战确认页）：

```
页面 → ref.read(checkinDaoProvider.future) → 写库（insert/update/delete/replacePhotos）
     → ref.invalidate(checkinsProvider / checkinTotalCountProvider / checkinDetailProvider)
```

读操作全部走 FutureProvider watch，无 StateNotifier；相册入口只负责带参跳转，不直接写库。

---

## 5. 边界处理

| 场景 | 处理 |
|---|---|
| loading / error | `.when` 三态兜底，error 显示重试 |
| 店名为空 | 保存拦截 + 提示 |
| 照片超 9 张 | Toast 提示上限 |
| 删除 | 确认弹窗，删除后 invalidate 并返回列表 |
| 无照片足迹 | 列表/详情用分类彩色图标占位 |
| 相册预填照片重复 | 以编辑页当前集合为准 |

---

## 6. 测试

- `checkin_dao_test.dart`：insert / update / delete（含级联）/ getAll 排序 / countAll / replacePhotos 增删替换
- `inspiration_page_test.dart` 更新：mock 断言改为注入测试 DAO（sqflite 内存库），验证卡片渲染真实数据
- `checkin_list_page_test.dart` / `checkin_detail_page_test.dart`：列表渲染、空态、详情展示、删除流程
- 验收命令：`flutter analyze`（0 error）+ `flutter test`（全量通过）

---

## 7. 不做的事（YAGNI）

- 不做后端同步与 admin 后台（纯本地）
- 不做拍照保存后弹窗入口（仅相册入口）
- 不做 GPS/自动定位（照片链路无地点字段）
- 不做足迹搜索/筛选（分类 tag 仅展示）
