# 自定义模板图片「RDB 存路径 + 图片落文件」实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让自定义模板图片改存「应用文档目录文件 + RDB 只存绝对路径」，彻底绕开 OHOS RDB 单条记录 2MB 硬上限，本地画质放宽到 2048px/~1MB，导出/分享时按路径读文件转 base64。

**Architecture:** 新增 `TemplateImageStore` 服务负责图片落盘/读回/删除。保存时把表单内所有 `data:image/...;base64,` 解码写文件并替换为绝对路径入 RDB；展示链路的 `LumiraImage`/`adaptive_cover_image` 已支持本地路径无需改，只需修 `pose_silhouette` 与编辑器缩略图/预览的路径识别；导出链路新增 `TemplateExporter.resolveLocalImages` 在导出前把路径转回 base64 data URL，保证 .pptpl 可迁移。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6、sqflite（DAO 层零改动）、path_provider（复用 `safe_temp_dir` 的异常兜底）、package:image（解码/尺寸判断）。

## Global Constraints

- **不改 `TemplateRecord` / `templates_dao.dart` 表结构**：路径是字符串，直接复用现有 TEXT 列，无 DB 迁移、不 bump `_kDbVersion`。
- **向后兼容**：旧 base64 记录照常显示/导出；新记录走路径。所有解析器对非本地路径原样放行。
- **图片命名**：`<documents>/lumira/templates/<templateId>/` 下 `cover.<ext>` / `img_<i>.<ext>` / `silhouette_<i>.<ext>`；扩展名按 mime（PNG 保留 alpha，用 `.png`）。
- **`isLocalImageRef` 语义**：排除 `data:` / `http://` / `https://` / `assets/` / 空串 / `'none'` / 纯 key 后视为本地路径。
- **导出入口统一 resolve**：`exportToTempFile` / `saveToFile` / `shareTemplate` / `_buildPayload`（share service）在导出前先 `resolveLocalImages`。
- **展示改动最小**：`LumiraImage` 与 `adaptive_cover_image.dart` 已支持本地路径（FileImage 兜底），**不得改动**这两个文件。
- **平台**：Flutter 主项目 `lumira_app_flutter/`。本任务只改 Flutter，不涉及后端/admin，无需 push。
- 技术栈版本：Dart 2.19.6，**不得使用 Dart 3 records 语法**。

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `lib/features/templates/services/template_image_store.dart` | 图片落盘/读回/转 base64/删除/路径判定 | 新增 |
| `lib/features/templates/services/template_exporter.dart` | `resolveLocalImages` + 导出入口 resolve + `embedCoverData` 加路径分支 | 修改 |
| `lib/features/templates/services/template_share_service.dart` | `_buildPayload` 前 resolve | 修改 |
| `lib/features/templates/pages/templates_editor_page.dart` | 保存时落盘、删压缩、放宽选图压缩、缩略图/预览支持路径 | 修改 |
| `lib/features/templates/widgets/pose_silhouette.dart` | image 类型 isPath 判断改为「非 data: 即路径」 | 修改 |
| `lib/features/profile/pages/profile_my_templates_page.dart` | 删除模板后清理图片目录 | 修改 |
| `lib/features/templates/pages/templates_detail_page.dart` | 导出详情页 pptpl shareLink 先 resolve | 修改 |
| `test/features/templates/template_image_store_test.dart` | TemplateImageStore 单测 | 新增 |
| `test/features/templates/custom_template_save_roundtrip_test.dart` | 端到端：路径入 RDB → 读回 → resolve 导出 | 更新 |
| `test/template_exporter_test.dart` | resolveLocalImages 单测 | 更新 |

---

## Task 1: 新增 TemplateImageStore 服务

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/services/template_image_store.dart`
- Test: `lumira_app_flutter/test/features/templates/template_image_store_test.dart`

**Interfaces:**
- Consumes: `getSafeDocumentsDirectory()`（`core/utils/safe_temp_dir.dart`）、`dart:convert`、`dart:io`。
- Produces: 静态方法供 Task 2/3/4/5 使用。

**Details:**

```dart
class TemplateImageStore {
  TemplateImageStore._();

  /// 基础目录（正常路径），测试可用 @visibleForTesting 覆盖。
  @visibleForTesting
  static String? overrideBaseDir;

  /// 图片根目录：<documents>/lumira/templates
  static Future<Directory> _templatesRoot() async {
    if (overrideBaseDir != null) return Directory('$overrideBaseDir/lumira/templates');
    final docs = await getSafeDocumentsDirectory();
    return Directory('${docs.path}/lumira/templates');
  }

  /// 解码 data URL 写文件，返回绝对路径。
  /// 非 `data:image/...;base64,` 输入（内置 key / SVG / http / assets / 空）原样返回。
  static Future<String> saveDataUrl(String templateId, String kind, int index, String dataUrl);

  /// 读文件字节，路径不存在返回 null。
  static Future<Uint8List?> readBytes(String path);

  /// 本地路径 → base64 data URL；非本地引用原样返回。
  static Future<String> toDataUrl(String ref);

  /// 判定是否为「本地文件路径」引用。
  static bool isLocalImageRef(String s);

  /// 删除模板整个图片目录（删除模板时调用），不存在的目录静默通过。
  static Future<void> deleteAll(String templateId);
}
```

**Steps:**

- [ ] 1.1 写失败测试 `template_image_store_test.dart`：
  - `saveDataUrl`：小 PNG data URL → 返回绝对路径，`File(path).readAsBytes()` 与 base64 解码一致；目录为 `<base>/lumira/templates/<templateId>/<kind>_<index>.<ext>`。
  - 透明 PNG 剪影落盘后仍是 PNG（扩展名 `.png`），`img.decodeImage` 保留 4 通道。
  - 非图片输入（`standing-profile` / `data:application/...` / http URL / 空串 / `'none'` / assets 路径）原样返回，不写文件。
  - `isLocalImageRef`：`data:`/`http`/`https`/`assets/`/空/`'none'`/纯 key → false；`/data/user/0/xxx/lumira/templates/u1/cover.png` → true。
  - `toDataUrl`：路径 → `data:image/png;base64,...` 且解码字节与文件一致；data URL 原样返回。
  - `deleteAll`：写多个文件后删除，目录不存在。
  - 测试用 `TemplateImageStore.overrideBaseDir = (await Directory.systemTemp.createTemp('tpl_img_')).path;`，tearDown 删除。
- [ ] 1.2 运行 `flutter test test/features/templates/template_image_store_test.dart`，确认失败（缺文件）。
- [ ] 1.3 实现 `template_image_store.dart`。
  - mime → ext：`image/png→.png`、`image/jpeg→.jpg`、`image/webp→.webp`、其余→`.png`。
  - `saveDataUrl` 用 `RegExp(r'^data:image/[A-Za-z0-9.+\-]+;base64,(.+)$', dotAll: true)` 匹配；`base64Decode` 失败 fail-open 原样返回。
  - 文件名：`kind == 'cover' ? 'cover$ext' : '${kind}_$index$ext'`（kind 传 `'img'` / `'silhouette'` / `'cover'`）。
  - `_templatesRoot` 创建目录 `Directory(..., recursive: true)`。
  - `toDataUrl`：`isLocalImageRef` 为真 → `readBytes` → 非 null → 按扩展名推 mime → `data:$mime;base64,...`；文件缺失返回原 ref。
- [ ] 1.4 运行测试，全绿。
- [ ] 1.5 `flutter analyze lib/features/templates/services/template_image_store.dart` 无新增错误。
- [ ] 1.6 Commit（`git add` 具体文件 → `git commit`，消息如 `feat(templates): add TemplateImageStore for path-based image storage`）。

---

## Task 2: 编辑器保存流程改为落盘

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`（`_encodeImageDataUrl` ~L450、`_compressFormImagesForSave` ~L740、`_onSave` ~L758、`_ImageTile` ~L2512、封面预览 ~L1763-1788）
- Test: 更新 `test/features/templates/custom_template_save_roundtrip_test.dart`（见 Task 6，先在本任务加一个「路径入 RDB」用例）

**Interfaces:**
- Consumes: `TemplateImageStore`（Task 1）、`TemplateMapper.fromEditorForm`。
- Produces: 保存后 RDB 中 `cover/coverData/images[].data`、pose 剪影 data 均为绝对路径。

**Steps:**

- [ ] 2.1 顶部 import 增加 `../../../shared/widgets/images/lumira_image.dart` 与 `../services/template_image_store.dart`。
- [ ] 2.2 `_encodeImageDataUrl` 放宽：`downscaleBytes(bytes, maxDimension: 2048, maxBytes: 1 * 1024 * 1024)`（更新注释：画质放宽，本地不再为 2MB 兜底压缩）。
- [ ] 2.3 删除 `_compressFormImagesForSave` 整个方法及其调用（`_onSave` 中 `await _compressFormImagesForSave();` 一行）。
- [ ] 2.4 新增 `_persistFormImagesToFiles(String id)`：
  ```dart
  Future<void> _persistFormImagesToFiles(String id) async {
    for (var i = 0; i < _form.meta.images.length; i++) {
      final e = _form.meta.images[i];
      if (e.data.isEmpty) continue;
      e.data = await TemplateImageStore.saveDataUrl(
          id, i == 0 ? 'cover' : 'img', i, e.data);
    }
    for (var i = 0; i < _form.poses.length; i++) {
      final p = _form.poses[i];
      if (p.silhouette.type == 'image' && p.silhouette.data.isNotEmpty) {
        p.silhouette.data = await TemplateImageStore.saveDataUrl(
            id, 'silhouette', i, p.silhouette.data);
      }
    }
  }
  ```
- [ ] 2.5 `_onSave` 流程：确定 `id` 后、`TemplateMapper.fromEditorForm` 前插入 `await _persistFormImagesToFiles(id);`。保留写后读回校验与刷新 provider 逻辑。调试日志去掉 base64 字符量断言（改为打印路径或长度，保持可读）。
- [ ] 2.6 `_ImageTile`（~L2548）：把 `Image.memory(_cachedCoverDecode(data), ...)` 替换为 `LumiraImage(data, width: 100, height: 120, fit: BoxFit.cover, errorWidget: _CoverPlaceholder(tokens: tokens))`（保留 errorBuilder 的 debugPrint 语义可省略）。
- [ ] 2.7 封面预览路径支持：`_decodeCoverImage`（~L1777）改为 data URL 走 `_cachedCoverDecode`、本地路径走 `TemplateImageStore.readBytes`（字节为空抛异常触发错误分支）；`_showCoverPreviewDialog` 内 `Image.memory(_cachedCoverDecode(cover))`（~L1814）替换为 `LumiraImage(cover, fit: BoxFit.contain)`。
- [ ] 2.8 `flutter analyze lib/features/templates/pages/templates_editor_page.dart` 无新增错误。
- [ ] 2.9 跑 `flutter test test/features/templates/templates_editor_export_test.dart test/features/templates/widgets/pose_silhouette_test.dart`（确保编辑器改动不破坏既有测试；若模板页测试依赖 path_provider 失败，记录为既有问题，不阻塞）。
- [ ] 2.10 Commit。

---

## Task 3: pose_silhouette 本地路径识别

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/pose_silhouette.dart`（`case 'image'` 的 `isPath` 判断 ~L125-127）
- Test: 更新 `test/features/templates/widgets/pose_silhouette_test.dart` 增加「image 类型本地路径走 LumiraImage/Image.file 分支」用例（可仅断言不抛异常 + 出现 Image 组件）。

**Interfaces:**
- Consumes: `silhouetteData`（data URL / 本地路径 / http / asset）。
- Produces: 本地路径剪影在拍摄取景/详情预览正确显示。

**Steps:**

- [ ] 3.1 改 `isPath`：`final isPath = !silhouetteData.startsWith('data:');`，删除旧的 assets/http 白名单判断；同步更新 `LumiraImage` 上方注释（三种数据源 → 非 data: 一律按路径透传，LumiraImage 内部再分流）。
- [ ] 3.2 在 `pose_silhouette_test.dart` 增加用例：`silhouetteType: 'image', silhouetteData: '/tmp/xxx/silhouette_0.png'` 渲染不抛异常且能找到 `Image` widget（本地路径分支）。
- [ ] 3.3 `flutter test test/features/templates/widgets/pose_silhouette_test.dart` 全绿。
- [ ] 3.4 Commit。

---

## Task 4: 导出链路 resolveLocalImages

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_exporter.dart`
- Modify: `lumira_app_flutter/lib/features/templates/services/template_share_service.dart`（`_buildPayload` ~L99-101）
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`（`_showExportSheet` ~L377 的 pptpl shareLink）
- Test: 更新 `test/template_exporter_test.dart`（resolveLocalImages 单测）+ `test/features/templates/custom_template_save_roundtrip_test.dart`（端到端，见 Task 6）

**Interfaces:**
- Consumes: `TemplateImageStore.toDataUrl` / `isLocalImageRef`（Task 1）、`TemplateRecord`（pose 兼容 List/单 Map）。
- Produces: `static Future<TemplateRecord> resolveLocalImages(TemplateRecord record)`，供导出入口调用。

**Steps:**

- [ ] 4.1 新增 `resolveLocalImages`：
  - `coverData`：`isLocalImageRef` 为真 → `toDataUrl`。
  - `cover`：同上（custom 模板 cover==coverData，双保险）。
  - `images[].data`：逐个同上。
  - `pose` 剪影：`pose is List` → 逐项；`pose is Map` → 单项。对 `silhouette['type'] == 'image'` 且 `silhouette['data']` 为本地路径 → 替换为 `toDataUrl` 结果。构造新 pose（copyWith 无法改嵌套 map，需重建 List/Map）。
  - 非本地路径（data URL / http / 内置 key / assets）原样保留；返回新 record（`copyWith`），不修改入参。
- [ ] 4.2 `embedCoverData` 增加「本地路径」分支：`isLocalImageRef(cover)` → `readBytes` → 非空 → base64 data URL（含 500KB 大小守卫，超限跳过），放在 assets 分支之后、return record 之前。
- [ ] 4.3 `exportToTempFile`：先 `final resolved = await resolveLocalImages(record);` 再 `recordWithCover = usePptpl ? await embedCoverData(resolved) : resolved;`。
- [ ] 4.4 `saveToFile`：`final resolved = await resolveLocalImages(record);` 再 `exportToPptpl(resolved) / exportToLumira(resolved)`。
- [ ] 4.5 `shareTemplate` 经 `exportToTempFile` 自动覆盖，无需改。
- [ ] 4.6 `template_share_service.dart` `_buildPayload`：`final resolved = await TemplateExporter.resolveLocalImages(record); final withCover = await TemplateExporter.embedCoverData(resolved);`。
- [ ] 4.7 `templates_detail_page.dart` `_showExportSheet`（~L365-381）：当 `usePptpl` 时先 `final linkRecord = await TemplateExporter.resolveLocalImages(record);`，`shareLink` 用 `linkRecord` 构建。
- [ ] 4.8 `test/template_exporter_test.dart` 新增 group `resolveLocalImages`：
  - 构造含本地路径 coverData + images[].data + pose image 剪影的 record（测试里用 `TemplateImageStore.overrideBaseDir` 写真实文件）→ resolve → 所有字段变为 data URL 且解码字节与文件一致。
  - data URL / http / 内置 key 原样保留；cover 缺失文件时保持原值。
- [ ] 4.9 `flutter analyze lib/features/templates/services/template_exporter.dart lib/features/templates/services/template_share_service.dart lib/features/templates/pages/templates_detail_page.dart` 无新增错误。
- [ ] 4.10 跑 `flutter test test/template_exporter_test.dart test/features/templates/template_share_service_test.dart` 全绿。
- [ ] 4.11 Commit。

---

## Task 5: 删除模板时清理图片文件

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_my_templates_page.dart`（`_handleActionDelete` ~L281）
- Test: 手动验证 + `flutter analyze`。

**Interfaces:**
- Consumes: `TemplateImageStore.deleteAll`（Task 1）。
- Produces: 删除模板后图片目录被清理。

**Steps:**

- [ ] 5.1 `_handleActionDelete` 在 `await dao.delete(tpl.id);` 后追加 `await TemplateImageStore.deleteAll(tpl.id);`（catch 块内继续；删除文件失败不阻塞已删除提示——包在独立 try/catch 并 debugPrint）。
- [ ] 5.2 检查是否有其它删除模板的入口（如导入覆盖、编辑器删除）需要同样清理；仅在确认存在时补（保持最小改动）。
- [ ] 5.3 `flutter analyze lib/features/profile/pages/profile_my_templates_page.dart` 无新增错误。
- [ ] 5.4 Commit。

---

## Task 6: 端到端回环测试 + 全量验证

**Files:**
- Modify: `lumira_app_flutter/test/features/templates/custom_template_save_roundtrip_test.dart`
- Test: `test/features/templates/template_image_store_test.dart`、`test/features/templates/custom_template_save_roundtrip_test.dart`

**Interfaces:**
- Consumes: `TemplateImageStore`、`TemplateMapper`、`TemplateExporter.resolveLocalImages`、`TemplatesDao`。
- Produces: 证明「保存（路径入 RDB）→ 读回 → resolve 导出 .pptpl 含正确 base64」全链路正确。

**Steps:**

- [ ] 6.1 在 `custom_template_save_roundtrip_test.dart` 增加用例「路径存储回环」：
  1. `TemplateImageStore.overrideBaseDir` 指向临时目录；
  2. 表单带 2 张 data URL 效果图（用 `template_share_service_test.dart` 的 `noiseDataUrl` 同款构造 PNG，或用 1×1 编码 PNG）+ 1 个 image 剪影 data URL；
  3. 模拟 `_persistFormImagesToFiles`：对每张 `saveDataUrl` 得到路径，写入 form；
  4. `TemplateMapper.fromEditorForm` → `dao.upsert` → `getCustomOnly()` 读回；
  5. 断言 `saved.coverData` / `images[].data` / pose 剪影 data 均为绝对路径（`isLocalImageRef == true`）且非 base64；
  6. `TemplateExporter.resolveLocalImages(saved)` → 导出 `exportToPptpl` → 解析 JSON 断言 coverData/images/silhouette 均为 `data:image/...;base64,` 且可解码；
  7. 清理临时目录。
- [ ] 6.2 保留既有 base64 兼容用例（`expect(saved.coverData, 'data:image/png;base64,COVER0')`）不动——验证旧数据不受影响。
- [ ] 6.3 跑 `flutter test test/features/templates/template_image_store_test.dart test/features/templates/custom_template_save_roundtrip_test.dart test/template_exporter_test.dart test/features/templates/template_share_service_test.dart` 全绿。
- [ ] 6.4 `flutter analyze` 整个 lib/ 无新增错误。
- [ ] 6.5 Commit。
- [ ] 6.6 汇总：向用户报告改动文件清单、验证结果、需重新构建/热重启 App 验证项（我的模板页新建→保存→显示；详情导出 .pptpl 内嵌 base64；删除模板清理目录）。

---

## 不在本次范围

- 不改 `TemplateRecord` / `templates_dao.dart` / 表结构；不 bump DB 版本。
- 不做 iOS 沙盒路径失效自动修复、不做相对路径迁移。
- 不改内置模板 / 远程模板图片来源。
- `compressDataUrlsToBudget` 保留（分享走后端 3MB payload 仍用其压缩）。
