# 模板导入导出功能完善设计规范

| 字段 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 创建日期 | 2026-08-04 |
| 状态 | 待评审 |
| 适用工程 | lumira_app_flutter（主开发） |
| 涵盖范围 | 模板导入导出的 Bug 修复 + AGENT.md §5 规范缺口补齐 |
| 后续依赖 | 无（本规范自包含，不依赖其他未完成工作） |

---

## 目录

1. [背景与问题诊断](#1-背景与问题诊断)
2. [架构概览](#2-架构概览)
3. [数据层修复](#3-数据层修复)
4. [封面图嵌入 .pptpl](#4-封面图嵌入-pptpl)
5. [版本兼容性检查](#5-版本兼容性检查)
6. [链接/二维码导入持久化 + 文件名冲突](#6-链接二维码导入持久化--文件名冲突)
7. [测试方案](#7-测试方案)
8. [自检清单](#8-自检清单)

---

## 1. 背景与问题诊断

### 1.1 现状

如画 Lumira（Flutter 主开发工程）已实现模板导入导出基础功能，包含 `.pptpl` 完整格式与 `.lumira` 简化格式、文件选择导入、系统分享导出、链接/二维码导入入口。但代码审计发现 6 类问题，分两层：

### 1.2 Bug 层

| 编号 | 描述 | 影响 |
|---|---|---|
| B-1 | `_degradeSilhouetteIfNeeded` 使用 5-key mock 白名单（`TemplatesEditorMockData.builtinSilhouetteKeys`），实际有 12 个内置剪影 key | 导入含 `neon-pose`/`vintage-portrait`/`peace-sign-girl` 等合法 key 的模板时被错误降级为 `none` |
| B-2 | 链接导入与二维码导入仅写入内存 `ImportedTemplatesNotifier`，未持久化到 DAO | App 重启后导入的模板丢失 |
| B-3 | `TemplateExporter.shareTemplate` / `saveToFile` 用模板名做文件名，无唯一性保证 | 同名模板导出文件冲突 |
| B-4 | 12 款原始模板的 `cover` 字段使用 `https://picsum.photos/...` URL，但 App 为零网络权限离线应用 | 12 款模板封面在生产环境无法显示；导出时封面无法嵌入 |

### 1.3 规范缺口层（AGENT.md §5）

| 编号 | 描述 | 规范原文 |
|---|---|---|
| S-1 | `.pptpl` 未嵌入封面图二进制数据，仅存 URL/路径字符串 | "`.pptpl` 为完全自包含的 JSON 文件，不依赖任何外部资源文件" |
| S-2 | 导入时未做格式版本兼容性检查 | "离线版导入时做版本兼容性检查" |

### 1.4 范围说明

本规范聚焦 **Bug 修复 + 规范缺口补齐**。以下不在本规范范围内：
- 真实二维码扫描库接入（属于"全功能对等"范围）
- Flutter 剪影 SVG 渲染实现（属于 Task 2.9，本规范仅迁移 key 列表与 SVG 字符串数据）
- Vue/uni-app 工程同步修改（参考实现，按 AGENT.md §1 不主动修改）
- `.lumira` 简化格式导入校验增强

---

## 2. 架构概览

所有改动限于 `lumira_app_flutter/`，触及 4 层：

| 层 | 文件 | 改动 |
|---|---|---|
| **Data** | 12 款原始模板 `.dart` 文件；新建 `builtin_silhouettes.dart`；`templates_editor_mock_data.dart` | 替换 picsum URL 为本地 asset 路径；新建剪影 key + SVG 数据源；移除 mock 剪影数据 |
| **Domain** | `photo_template.dart` | `TemplateMeta` 增加可空 `coverData` 字段；同步 `toJson`/`fromJson`/`copyWith`/`==`/`hashCode` |
| **Services** | `template_exporter.dart`；`template_mapper.dart`；新建 `pptpl_format.dart` | 导出时嵌入封面 base64；导入时校验格式版本；剪影降级白名单改用真实 key 源 |
| **Widgets/Pages** | `template_import_sheet.dart`；`profile_my_templates_page.dart`；`templates_all_page.dart`；删除 `imported_templates_provider.dart` | 链接/二维码导入改走 DAO；文件名加模板 ID 后缀；移除内存 provider 依赖 |

**核心原则：** `.pptpl` 格式规范（AGENT.md §5）要求"完全自包含的 JSON 文件，不依赖任何外部资源文件"。当前 `meta.cover` 存储 URL/路径字符串违反此要求。修复方案：导出时增加 `meta.coverData`（base64 data URL），导入时优先使用 `coverData`；保留 `meta.cover` 作为人类可读引用。

**不引入新依赖。** 封面 asset 加载用 Flutter 内置 `rootBundle`；base64 用 `dart:convert`；均为已有可用能力。

---

## 3. 数据层修复

### 3.1 剪影白名单数据源迁移

**问题：** `template_mapper.dart`（约 553-555 行）的 `_degradeSilhouetteIfNeeded` 从 `TemplatesEditorMockData.builtinSilhouetteKeys` 取白名单——仅 5 个 key（`none`、`standing-profile`、`sitting-cafe`、`walking-street`、`soft-portrait`）。合法 key 如 `neon-pose`、`vintage-portrait`、`peace-sign-girl`、`food-overhead`、`cityscape-tripod`、`landscape-wide`、`macro-flower`、`still-life-table` 被错误降级为 `none`。

**修复：** 新建 `lib/features/templates/data/builtin_silhouettes.dart` 作为剪影数据的唯一真实源：
- 导出 `kBuiltinSilhouetteKeys`——完整 12 key 列表（从 `lumira-app/src/data/silhouettes/index.ts` 迁移，不含 `'none'` 占位符）
- 导出 `kBuiltinSilhouettes`——`Map<String, String>`，key → SVG 字符串（从 Vue 迁移真实 SVG 路径数据）
- 12 个 SVG 均使用 `viewBox="0 0 100 200"`（1:2 竖向比例）、`fill="currentColor"`

**更新 `template_mapper.dart`：** `_degradeSilhouetteIfNeeded` 的白名单来源从 `TemplatesEditorMockData.builtinSilhouetteKeys` 改为 `kBuiltinSilhouetteKeys`。删除 553-555 行的 TODO 注释。

**更新 `templates_editor_mock_data.dart`：** 删除 mock 的 `builtinSilhouetteKeys`（389-410 行）和 `builtinSilhouettes` 及其 TODO 注释。剪影编辑器的 picker 改为从 `builtin_silhouettes.dart` 导入。

**范围边界：** `PoseSilhouette` 组件实际渲染 SVG 的实现不在本规范范围内（属于 Task 2.9）。本修复仅保证：导入不错误降级合法 key；编辑器 picker 显示全部 12 个选项。

### 3.2 封面 asset 路径修复（12 款原始模板）

**问题：** 12 款原始模板文件使用 `cover: 'https://picsum.photos/seed/template-{id}/400/600'`。App 为零网络权限离线应用，这些封面无法加载。本地 `assets/images/templates/` 下已存在对应的 12 个 `.jpg` 文件。

**修复：** 更新 12 款模板文件的 `cover` 字段为本地 asset 路径：

| 模板文件 | 旧值 | 新值 |
|---|---|---|
| `cafe_portrait.dart` | `https://picsum.photos/seed/template-cafe-portrait/400/600` | `assets/images/templates/cafe_portrait.jpg` |
| `film_vintage.dart` | 同类 picsum URL | `assets/images/templates/film_vintage.jpg` |
| `food_flat_lay.dart` | 同上 | `assets/images/templates/food_flat_lay.jpg` |
| `golden_landscape.dart` | 同上 | `assets/images/templates/golden_landscape.jpg` |
| `indoor_still_life.dart` | 同上 | `assets/images/templates/indoor_still_life.jpg` |
| `macro_flower.dart` | 同上 | `assets/images/templates/macro_flower.jpg` |
| `neon_portrait.dart` | 同上 | `assets/images/templates/neon_portrait.jpg` |
| `night_cityscape.dart` | 同上 | `assets/images/templates/night_cityscape.jpg` |
| `soft_portrait.dart` | 同上 | `assets/images/templates/soft_portrait.jpg` |
| `street_bw.dart` | 同上 | `assets/images/templates/street_bw.jpg` |
| `sunset_silhouette.dart` | 同上 | `assets/images/templates/sunset_silhouette.jpg` |
| `urban_architecture.dart` | 同上 | `assets/images/templates/urban_architecture.jpg` |

**数据库迁移：** 已 seed 到 SQLite 的内置模板仍存旧 picsum URL。采用 seeder 重 upsert 方案：在 `builtin_data_seeder.dart` 中提升 seed 版本号常量（如 `kSeedVersion` 从当前值 +1），`database_provider.dart` 的 `onUpgrade` 检测到版本提升时调用 `seeder.reseedBuiltinCovers(db)`，该方法对 12 条内置模板执行 `UPDATE custom_templates SET cover = ? WHERE id = ? AND is_builtin = 1`。seeder 已用 `upsert` + `is_builtin=1`，覆盖安全。此方案比全表 reseed 轻量，仅更新 cover 字段。

---

## 4. 封面图嵌入 .pptpl

### 4.1 Domain 模型变更

`TemplateMeta`（`photo_template.dart`）增加可空字段：

```dart
class TemplateMeta {
  final String id, name, author, version, category, cover, description, referenceSource;
  final List<String> tags, tagIds;
  final int price;
  final TemplateClassification classification;
  final String? coverData; // 新增：base64 data URL，用于自包含导出
  // ...
}
```

- `coverData` 为可空——App 内模板为 `null`（封面从 asset 加载）；仅在导出/导入 `.pptpl` 时赋值
- 同步更新 `toJson`/`fromJson`/`copyWith`/`==`/`hashCode`
- `TemplateRecord`（DAO 行模型）增加 `coverData` TEXT 列（可空），用于持久化导入的模板

### 4.2 导出流程（`template_exporter.dart`）

`exportToPptpl` 增加封面嵌入步骤：

1. 读取 `record.meta.cover` 字符串
2. 若以 `data:` 开头 → 已是 data URL，直接复制到 `coverData`
3. 若以 `assets/` 开头 → 通过 `rootBundle` 加载字节，base64 编码，加 MIME 前缀 → `coverData`
4. 若以 `http`/`https` 开头 → 离线 App 无法 fetch；记录 warning，`coverData` 留空（`cover` 字段保留原 URL 供参考）
5. 若为空 → 跳过
6. 将 `cover`（引用）和 `coverData`（嵌入）同时写入 `.pptpl` JSON

**大小守卫：** 若编码后 `coverData` 超过 500KB，跳过嵌入并记录 warning（避免封面图过度膨胀 `.pptpl` 文件）。

### 4.3 导入流程（`template_mapper.dart`）

`recordFromImportedJson` 增加封面解析：

1. 若 JSON 含 `meta.coverData`（非空） → 直接作为存储的 `coverData`
2. 否则若 JSON 含 `meta.cover` 且以 `data:` 开头 → 迁移到 `coverData`
3. 否则 → 保留 `cover` 字符串，`coverData` 留空

**显示优先级（UI 消费方）：** `coverData`（若存在） > `cover`（asset 路径或 URL）。新增 `resolveCoverUrl(record)` 工具函数供封面渲染处调用。

### 4.4 .lumira 格式

简化 `.lumira` 格式不嵌入封面（轻量分享格式）。`exportToLumira` 已省略 `coverData`，无需改动。

---

## 5. 版本兼容性检查

**规范要求**（AGENT.md §5 第 434 行）："离线版导入时做版本兼容性检查"

### 5.1 格式版本常量

新建 `lib/features/templates/services/pptpl_format.dart`：

```dart
class PptplFormat {
  static const String currentVersion = '1.0';
  static const Set<String> supportedVersions = {'1.0'};
}
```

### 5.2 导入校验（`template_mapper.dart`）

`recordFromImportedJson` 顶部增加格式版本检查：

1. 读取 `json['format']` 和 `json['version']`（格式版本，区别于 `meta.version`）
2. 若 `version` 缺失 → 视为 legacy 格式（无 `format` 字段）→ 用默认值解析，返回 `TemplateImportWarning.legacyFormat`
3. 若 `version` 在 `supportedVersions` 中 → 正常解析
4. 若 `version` 已知但更新 → 返回 `TemplateImportWarning.unsupportedVersion`（含版本号）；尝试 best-effort 解析（不硬失败——前向兼容）
5. 若 `version` 无法识别 → 同 #4

### 5.3 UI 告警呈现（`template_import_sheet.dart`）

当前 `_handleFileImport` 仅二分：成功（toast "导入成功"）或失败（toast "导入失败"）。增加第三种结果——**带警告的成功**：

- 定义 `TemplateImportResult`：`{ success: bool, record: TemplateRecord?, warnings: List<TemplateImportWarning> }`
- `_parseTemplateJson` 返回 `TemplateImportResult` 而非抛异常/返回 null
- 导入成功后若 `warnings` 非空 → 弹窗列出警告（如"该模板来自更新版本的格式 (v2.0)，部分参数可能不兼容"），含"继续"按钮
- 警告为非阻塞——模板已保存；弹窗仅为告知

### 5.4 模板版本 vs 格式版本

`meta.version`（如 "1.0.0"）是**模板作者版本**。格式版本（顶层 `version: '1.0'`）是 **.pptpl 规范版本**。本规范仅校验格式版本。模板版本原样保留供用户参考。

---

## 6. 链接/二维码导入持久化 + 文件名冲突

### 6.1 链接/二维码导入持久化

**问题：** `template_import_sheet.dart` 的 `_handleLinkImport` 和 `_handleQrImport` 通过 `importedTemplatesProvider.notifier.addTemplate` 创建 `ImportedTemplate` 对象——一个内存 `StateNotifier`。重启后数据丢失。且这些导入仅携带轻量元数据（name/category/tags/coverSeed），不含完整模板参数（camera/composition/postProcess）。

**修复：** 链接/二维码导入改走与文件导入相同的 DAO 持久化路径。

**链接导入（`_handleLinkImport`）：**
- 解析 `lumira://tpl/{base64(json)}` URL——base64 载荷应为完整模板 JSON（与 `.pptpl` 内容同结构）
- 解码 base64 → JSON 字符串 → 调用与文件导入相同的 `_parseTemplateJson` → `TemplateMapper.recordFromImportedJson` → 处理 ID 冲突 → `dao.upsert(record)`
- 移除对 `importedTemplatesProvider` 的依赖
- 若链接 URL 是轻量形式 `https://lumira.app/tpl?name=xxx&category=xxx`（无完整 JSON）→ 报错"该分享链接不包含完整模板参数，请使用文件导入"

**二维码导入（`_handleQrImport`）：**
- 当前 "LUMIRA-分类-名称" 分享码为手动文本输入，非真实 QR 扫描
- 保留手动输入 UI，但将其解析为紧凑分享码后持久化到 DAO。分享码格式 `LUMIRA-{category}-{name}` 解析规则：
  - `category` 必须为 AGENT.md §5 定义的 7 类之一（`portrait`/`landscape`/`food`/`street`/`night`/`macro`/`still-life`），否则报错"无法识别的分类"
  - `name` URL-decode 后作为模板名
  - 生成 `TemplateRecord`：id = `qr_{category}_{name}_{timestamp}`，cover 留空，composition/camera/postProcess 用对应 category 的默认值（从内置模板取该 category 首个模板的参数拷贝）
  - `dao.upsert(record)` 持久化
- **范围边界：** 接入真实 QR 扫描库不在本规范范围内（属于"全功能对等"）

**删除 `imported_templates_provider.dart`：** 链接与二维码均改走 DAO 后，内存 `ImportedTemplatesNotifier` 成为死代码。删除该文件，并更新 `templates_all_page.dart` 和 `profile_my_templates_page.dart` 改为仅从 DAO 读取。

### 6.2 导出文件名冲突

**问题：** `TemplateExporter.shareTemplate` 和 `saveToFile` 用 sanitize 后的模板名做文件名。两个名为"咖啡馆人像"的模板冲突。

**修复：** 文件名追加模板 ID（或短哈希）：
- 模式：`{sanitized_name}_{template_id}.pptpl`（如 `咖啡馆人像_cafe_portrait.pptpl`）
- 自定义模板：`{sanitized_name}_{template_id}.pptpl`，其中 `template_id` 已唯一
- 名称 sanitize：移除 `/`、`\`、`:`、`*`、`?`、`"`、`<`、`>`、`|` 字符；截断至 30 字符
- 因 `template_id` 在 DAO 中始终唯一，文件名保证唯一

---

## 7. 测试方案

### 7.1 更新现有测试

- **`test/template_import_test.dart`** — 新增用例：
  - 导入含合法 builtin key `neon-pose` 的模板 → 不应被降级为 `none`
  - 导入含未知 builtin key `nonexistent-key` 的模板 → 应被降级为 `none`
  - 导入含 `coverData` 字段的模板 → `record.meta.coverData` 被填充
  - 导入含 `cover` 为 data URL 的模板 → 迁移到 `coverData`
  - 导入格式版本 `2.0` 的模板 → 返回 `unsupportedVersion` 警告，仍能解析
  - 导入无格式版本的模板 → 返回 `legacyFormat` 警告，仍能解析
- **`test/template_exporter_test.dart`** — 新增用例：
  - `exportToPptpl` 在 cover 为 asset 路径时包含 `meta.coverData`（mock `rootBundle`）
  - `exportToPptpl` 在 cover 为 http URL 时 `coverData` 留空
  - `exportToPptpl` 文件名模式含模板 ID
- **`test/template_mapper_test.dart`** — 更新剪影降级测试，使用新 `kBuiltinSilhouetteKeys` 源

### 7.2 新增测试文件

- **`test/features/templates/builtin_silhouettes_test.dart`** — 验证 12 个 key 均为非空 SVG、均有 `viewBox="0 0 100 200"`、均使用 `fill="currentColor"`
- **`test/features/templates/cover_embedding_test.dart`** — 集成测试：导出内置模板 → 导入结果 JSON → 验证 `coverData` 正确 round-trip

### 7.3 手动验证清单

- 导出内置模板 → 检查 `.pptpl` JSON → 确认 `coverData` 存在且可解码为有效 JPEG/PNG
- 在全新安装上导入该 `.pptpl` → 封面无网络环境下正常显示
- 导入含合法 `neon-pose` 剪影的 `.pptpl` → 剪影 key 被保留（未降级）
- 使用链接导入 → 重启 App → 模板仍在"我的模板"列表中
- 导出两个同名模板 → 文件名不同

---

## 8. 自检清单

### 8.1 Bug 修复自检

- [ ] B-1: `_degradeSilhouetteIfNeeded` 白名单来源改为 `kBuiltinSilhouetteKeys`，含全部 12 key
- [ ] B-2: 链接/二维码导入写入 DAO，重启后不丢失
- [ ] B-3: 导出文件名含模板 ID，同名模板不冲突
- [ ] B-4: 12 款原始模板 cover 改为本地 asset 路径，离线可显示

### 8.2 规范缺口自检

- [ ] S-1: `.pptpl` 导出含 `meta.coverData`（base64），导入优先使用 `coverData`
- [ ] S-2: 导入时校验格式版本，未知/更新版本返回警告而非硬失败

### 8.3 范围边界自检

- [ ] 未引入新三方依赖
- [ ] 未修改 Vue/uni-app 工程
- [ ] 未实现真实 QR 扫描（留待全功能对等）
- [ ] 未实现 Flutter 剪影 SVG 渲染（留待 Task 2.9）
- [ ] `imported_templates_provider.dart` 已删除，无残留引用
