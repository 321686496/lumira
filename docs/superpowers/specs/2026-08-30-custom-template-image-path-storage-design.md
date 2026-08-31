# 自定义模板图片「RDB 存路径 + 图片落文件」设计

> 日期：2026-08-30
> 状态：已批准，待实施
> 目标平台：Flutter 主项目（`lumira_app_flutter/`），重点解决 OHOS RDB 单条记录 2MB 硬上限导致自定义模板「提示保存成功但看不到」的问题

## 1. 背景与问题

OHOS 关系型数据库（RDB）单条记录硬上限 **2MB**，超出后「插入成功但读取失败」，表现为保存提示成功但「我的模板页」不显示模板。当前方案是保存前把模板内所有图片（封面 + 效果图 + 姿势剪影）压缩到总预算 ~1.5MB 以内，牺牲画质。

用户决策：**不再用压缩硬扛 2MB 上限**，改为「RDB 只存图片绝对路径，图片字节落应用文档目录；导出/分享时按路径找到文件转 base64 填充」。

## 2. 用户已确认的决策

1. **画质放宽**：选图时压缩到 `2048px / ~1MB`（此前为 `1024px / ~300KB`），本地模板画质明显更好；导出分享走后端（payload 3MB 上限）时再按需压缩。
2. **路径格式**：RDB 存**绝对路径**（实现最简单，显示/导出直接按路径读文件）。已知风险：iOS App 更新后沙盒容器路径可能变化导致旧模板丢图（OHOS 不受影响）；作为本地-only 功能的可接受权衡。

## 3. 总体架构

```
选图/拍照 → 压到 2048px/~1MB 的 base64 data URL（内存）
   │
保存时 ──► 解码成字节写入 <documents>/lumira/templates/<templateId>/ 下
   │         cover.<ext> / img_<i>.<ext> / silhouette_<i>.<ext>
   ▼
RDB 只存图片的【绝对路径】字符串（不再是 base64）
   │
显示时 ──► 组件识别本地路径 → Image.file / FileImage 直接读文件（无需转 base64）
   │
导出/分享 ──► 遍历路径 → 读文件 → 转 base64 填入 .pptpl（导出时转换）
```

## 4. 新增服务 `TemplateImageStore`

文件：`lumira_app_flutter/lib/features/templates/services/template_image_store.dart`

- 落盘目录：`<documents>/lumira/templates/<templateId>/`（按模板 id 隔离）
- 命名：`cover.<ext>` / `img_<i>.<ext>` / `silhouette_<i>.<ext>`（扩展名按 mime，PNG 保留 alpha）
- 方法：
  - `static Future<String> saveDataUrl(String templateId, String kind, int index, String dataUrl)`：解码 data URL → 写文件 → 返回**绝对路径**。非 `data:image/...;base64,` 输入原样返回（内置剪影 key / SVG / http 等）。
  - `static Future<Uint8List?> readBytes(String path)`：读文件字节（路径不存在返回 null）。
  - `static Future<String> toDataUrl(String ref)`：`isLocalImageRef` 为真则读文件转 base64 data URL，否则原样返回。
  - `static bool isLocalImageRef(String s)`：排除 `data:` / `http://` / `https://` / `assets/` / 空串 / `'none'` / 纯 key 后，视为本地路径。
  - `static Future<void> deleteAll(String templateId)`：删除模板整个图片目录（删除模板时调用）。
- 依赖 `path_provider.getApplicationDocumentsDirectory()`（沿用 `database_provider.dart` 既有用法），必要时复用 `safe_temp_dir` 的异常兜底模式。

## 5. 保存流程（`templates_editor_page.dart`）

- **删除** `_compressFormImagesForSave`（RDB 预算压缩已无必要）。
- **新增** `_persistFormImagesToFiles(String id)`：收集封面 + 效果图 + 各姿势剪影图，凡 `data:image/...;base64,` 的一律 `TemplateImageStore.saveDataUrl` 写入文件并替换为绝对路径；已是本地路径的保留（编辑模式载入后重存不重复落盘）。
- `_encodeImageDataUrl` 压缩放宽：`downscaleBytes(maxDimension: 2048, maxBytes: 1 * 1024 * 1024)`。
- `_onSave` 流程：先确定 `id` → `_persistFormImagesToFiles(id)` → `TemplateMapper.fromEditorForm` → `dao.upsert` → 写后读回校验（此时记录很小基本不会超限，保留作为兜底）。
- 保留刷新 `customTemplatesProvider` / `CaptureState.allTemplatesProvider` 逻辑不变。

## 6. 展示链路（旧 base64 记录与新路径记录都须正常显示）

| 消费点 | 现状 | 改动 |
|---|---|---|
| `LumiraImage` | 已支持本地路径（末尾 FileImage 兜底） | 无需改 |
| `adaptive_cover_image.dart` `buildCoverProvider` | 已支持本地路径（FileImage 兜底） | 无需改 |
| `pose_silhouette.dart` image 类型 | `isPath` 仅识别 assets/http(s)，本地路径会被当 base64 处理出错 | `isPath` 判断改为「非 `data:` 前缀即路径」，直接透传给 LumiraImage |
| 编辑器 `_ImageTile`（~L2548） | `Image.memory(_cachedCoverDecode(data))` | 改用 `LumiraImage(data)`（兼容 data URL 与本地路径） |
| 编辑器封面预览 `_showCoverPreviewDialog` / `_getCachedCoverImage`（~L1764） | base64 解码缓存 | 封面解码改为支持本地路径（读文件），缓存键不变 |

## 7. 导出/分享链路（导出时转 base64）

文件：`template_exporter.dart` / `template_share_service.dart`

- `TemplateExporter` 新增 `static Future<TemplateRecord> resolveLocalImages(TemplateRecord record)`：
  - `coverData` / `cover`：`isLocalImageRef` 为真 → 读文件 → base64 data URL。
  - `images[].data`：同上逐个替换。
  - `pose` 剪影：遍历 pose（兼容 List / 单 Map），对 `type == 'image'` 且 data 为本地路径的替换为 base64 data URL。
  - 非本地路径（data URL / http / 内置 key）原样保留。
  - 返回新 record（copyWith），不修改入参。
- `embedCoverData` 增加「本地路径 → 读文件编码 base64」分支（含大小守卫）。
- `exportToPptpl` / `exportToTempFile` / `saveToFile` / `shareTemplate` / `_buildPayload` / `sharePayloadJson` 在导出前统一先 `resolveLocalImages`，确保 .pptpl 内嵌 base64。
- 分享走后端（3MB payload 上限）：`sharePayloadJson` 现有图片压缩逻辑（`_compressEmbeddedImages`）保持不变，导出时按需压小。

## 8. 删除清理 & 兼容性

- 删除模板处（`profile_my_templates_page.dart` ~L281 等）在 `dao.delete` 后调用 `TemplateImageStore.deleteAll(id)` 清理图片文件。
- **向后兼容**：旧 base64 记录照常显示/导出（所有解析器对非本地路径原样放行）；新记录走路径。**无需 DB 迁移、不改表结构**（字段均为 TEXT）。

## 9. 测试

- `template_image_store_test.dart`（新增）：
  - data URL → 写文件 → 路径 → 读回字节与原始 base64 解码一致。
  - 透明剪影 PNG 落盘后保留 alpha。
  - `isLocalImageRef` 各分支（data:/http/assets/空/none/key/路径）。
  - `toDataUrl` 路径与 data URL 双向。
- 端到端回环（`custom_template_save_roundtrip_test.dart` 更新）：保存（路径入 RDB）→ 读回 → `resolveLocalImages` 导出 .pptpl 含正确 base64。
- `template_share_service_test.dart`：既有 `compressDataUrlsToBudget` 等用例保留（该方法仍用于分享压缩）。
- 编辑器保存流程相关测试更新（不再断言 base64 字符量）。

## 10. 不在本次范围

- 不改 `TemplateRecord` / `templates_dao.dart` 表结构与字段（路径是字符串，直接复用现有 TEXT 列）。
- 不做相对路径迁移、不做 iOS 路径失效后的自动修复。
- 不改内置模板 / 远程模板的图片来源（它们用 asset key / http URL，不受影响）。
