# 模板卡片 + 详情页展示优化设计

> 日期：2026-08-22
> 状态：已确认，待转入实施计划
> 相关前置：2026-08-20-template-ambience-metadata-design.md（ambience 结构化元数据 + shortDesc，本轮把「Flutter 展示」从后续范围纳入本轮）

## 1. 背景与目标

模板卡片目前仅显示封面、名称、分类（+免费/自定义 badge）；模板详情页已按后端调整过字段但**新增的 `shortDesc`、`ambience`、`updatedAt` 未在 Flutter 端展示**。目标：

1. **模板卡片**：封面、名称之外，追加展示 `shortDesc`（短简介）与「本机使用次数」。
2. **模板详情页**：展示 `shortDesc`、`ambience`（季节/天气/时段）、`updatedAt`（时间）；页面底部新增「用此模板拍摄的照片」区，点击进入该模板全部照片页。
3. **新增「模板照片网格页」**：3 列网格展示该模板在本机拍摄的全部照片，点单张复用现有相册详情页。

## 2. 关键数据确认

- **`shortDesc`**：后端 `short_desc`，≤10 字，空串表示未标注；展示时回退用 `description` 截断。
- **`ambience`**：**结构化对象**（非字符串）：

```ts
interface TemplateAmbience {
  seasons: ('spring'|'summer'|'autumn'|'winter')[];  // 空=不限
  weathers:('sunny'|'cloudy'|'overcast'|'rain'|'snow'|'fog')[];
  timeTones:('goldenHour'|'day'|'night'|'warm'|'cool')[];
}
```

- **`updatedAt`**：后端毫秒时间戳（DTO 已解析）。
- **「使用次数」**：本机相册里「用该模板拍摄的照片数」= `gallery_dao.countByTemplate()[templateId]`（一次 SQL `GROUP BY template_id`，感染不到 detail 慢路径）。
- **「模板照片」**：`gallery_dao.getByTemplate(templateId)`。

## 3. 数据模型扩展（数据层）

### 3.1 DTO（remote_template_dto.dart）
`RemoteTemplateMetaDto` / `RemoteTemplateDetailDto` 新增字段与解析：

```dart
final String shortDesc;                    // j['shortDesc'] ?? ''
final RemoteTemplateAmbienceDto ambience;  // 由 j['ambience'] Map 解析，缺省空
```

新增 `RemoteTemplateAmbienceDto { List<String> seasons; List<String> weathers; List<String> timeTones; }` + `fromJson/toJson`（仅展示用）。

### 3.2 领域模型
- `AllTemplateItem`：新增 `String shortDesc`、`RemoteTemplateAmbienceDto ambience`（卡片用）。
- `TemplateDetail`：新增 `String shortDesc`、`RemoteTemplateAmbienceDto ambience`、`int updatedAt`（详情页用）。
- `AmbienceLabel` 工具（详情页模型或 widget 目录）：`seasons/weathers/timeTones` → 中文标签映射，与分类 `categoryLabel` 风格一致：
  - seasons：春季/夏季/秋季/冬季
  - weathers：晴天/多云/阴天/雨天/雪天/雾天
  - timeTones：黄金时刻/白天/夜晚/暖调/冷调

### 3.3 Mapper（template_mapper.dart）
- `metaDtoToRecord` / `detailDtoToRecord` / 回读路径补充 `shortDesc`、`ambience`。
- `fromPhotoTemplate`（回退路径）与 mock 数据：缺省为空串 / 空对象，避免破坏既有测试。

## 4. 模板卡片 UI（templates_all_page.dart `_TplCard`）

在 `name` 之后、底部分类行之间插入：

1. **短简介**：`Text(shortDesc.isEmpty ? 截断(description) : shortDesc)`，最多 2 行 `ellipsis`，`textSecondary`。
2. **底部行**（原分类 `Wrap` 基础上）：追加「使用次数」——`Icons.camera_alt_outlined` 小图标 + `已拍 N 张`，`N>0` 才显示；同时展示 ambience 标签（季节/时段等，多个用 `·` 连接，超长省略）。
3. 调整 `childAspectRatio` 以容纳新增文本行，避免小屏溢出（沿用现有卡片 `NeuCard` + 平铺面规范）。

> ambience 展示：用户已确认「卡片 + 详情页两处都展示」。为避免卡片拥挤，卡片仅展示 **1 个最直观的维度**（优先 timeTones，其次 seasons），详情页展示全部。

## 5. 模板详情页 UI（templates_detail_page.dart）

按现有 `_TitleAndTags` → 各参数卡 → `_UnlockStatus` → `_ReferenceSource` 之上、标题区之下插入：

1. **新增信息卡**（标题下方）：`shortDesc`（首屏简述）+ `ambience` 全量中文标签（季节/天气/时段的 chips）+ `updatedAt`（格式化日期，如「更新于 2026-08-20」）。
2. **底部新增「用此模板的照片」区**（`getByTemplate` 最近 4 张横排缩略图 + 「查看全部」入口）：无照片时隐藏；有照片时点击单品复用现有 `GalleryDetailPage(photoId)`。

## 6. 新增「模板照片网格页」+ 路由

- 新建 `lib/features/gallery/pages/template_photos_page.dart`：
  - 入参 `templateId`，`getByTemplate` 查询全部照片，`GridView` 3 列展示缩略图。
  - 点击单张 → `GalleryDetailPage(photoId)`。
  - 空态：无照片提示。
- 路由：
  - `RouteNames.templatesPhotos = '/templates/photos'`（复用 `paramTemplateId`）。
  - `router.dart` 新增 `GoRoute`，`builder` 解析 `templateId` 进入 `TemplatePhotosPage`。
  - 详情页「查看全部」→ `GoRouter.push(RouteNames.build(templatesPhotos, {paramTemplateId: id}))`。

## 9. 补充：Flutter 本地持久化（实施必要，不改变行为）

Flutter 端模板元数据落库在本地 sqflite `custom_templates` 表（《review 补充》发现：模板卡片走 `TemplateRecord`→`AllTemplateItem`，模板详情页走 `TemplateRecord`→`PhotoTemplate(TemplateMeta)`→`TemplateDetail`，两条路径都**不直接读取后端 DTO**）。因此 `shortDesc`/`ambience` 需贯通本地持久化层：

- **DB 迁移 v35**：`custom_templates` 新增 `short_desc TEXT NOT NULL DEFAULT ''` 与 `ambience_json TEXT NOT NULL DEFAULT '{}'` 两列（`tables.dart` 新增常量 + `database_provider.dart` `_onCreate` 建列 + `_onUpgrade` 的 `if (oldVersion < 35)` 用 `_addColumnIfNotExists` + `_kDbVersion` 35）。
- **`TemplateRecord`**：新增 `shortDesc`、`ambienceJson` 字段与 `toRow`/`fromRow`/`copyWith`。
- **`PhotoTemplate.TemplateMeta`**：新增 `shortDesc`、`ambience`（`RemoteTemplateAmbienceDto`）可选字段 + `copyWith`/`==`/`hashCode`。
- **`TemplateMapper`**：`metaToRecord`/`detailToRecord`（DTO→Record）、`toPhotoTemplate`（Record→Meta）、`fromPhotoTemplate`（Meta→TemplateDetail）全链贯通。
- **DTO**（`RemoteTemplateMetaDto`/`RemoteTemplateDetailDto`）：补 `shortDesc` + `ambience` 解析。
- mock 数据与 `fromPhotoTemplate` 缺省为空，保证既有模板不回归。

## 7. 范围边界

- 本轮仅 Flutter 端展示；后端 / Admin 字段已在 `2026-08-20` spec 落库。若本机相册为空（无该模板照片），卡片不显示次数、详情页照片区隐藏、网格页显示空态。
- 推荐算法接入 `ambience` + `WeatherService` **不在本轮**。

## 8. 回归注意

- mock 数据与 `fromPhotoTemplate` 缺省新字段为空，保证既有模板（29 内置 + 远程）不回归。
- Flutter 端 `ambience` 仅展示，不参与计算；无该字段的旧后端模板显示空标签即可。