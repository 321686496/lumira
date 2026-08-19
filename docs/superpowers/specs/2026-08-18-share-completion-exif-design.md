# 分享体系完善 + EXIF 海报优化 设计文档

日期：2026-08-18
状态：已获用户批准（范围 / EXIF 布局方向 / 分享积分规则三项决策）

## 背景与目标

当前分享能力"内容分享 → 系统分享面板"链路已较完整，但存在四类缺口，本次一并完善：

1. **模板分享码 / 分享链接只有接收端、没有生成端**（导入侧支持 `lumira://tpl/{base64}` 链接和 `LUMIRA-分类-名称` 码，但分享侧无生成 UI）。
2. **无 URL Scheme 深链接收**：`lumira://` 解析仅存在于模板导入面板的手动粘贴路径，无法通过点击外部链接唤起 App 直达导入。
3. **「分享得积分」闭环未接通**：后端已定义 `share` 积分流水类型，但无任何客户端上报；分享次数成就是 mock 数据。
4. **EXIF 海报过丑**：照片按原比例缩至 600px 高居中，竖图左右留白达 40%+。

## 决策记录

| 决策项 | 结论 |
|---|---|
| 执行范围 | 四项全部实施 |
| EXIF 布局方向 | 照片放大铺满顶部，参数区紧凑两列 |
| 分享积分规则 | 每日首次分享 +2（幂等，复用现有 earnEvent 机制） |
| 深链实现 | 自研统一 DeepLink 通道（Android 用 uni_links，HarmonyOS 用自定义 MethodChannel 插件） |

---

## 一、模板分享码 / 分享链接生成端

### 现状
- 接收端（[template_import_sheet.dart](../../../lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart)）已支持三种导入：文件导入、链接导入（`lumira://tpl/{base64(json)}` / `https://lumira.app/tpl?...`）、分享码导入（`LUMIRA-分类-名称`），均落 DAO 持久化。
- 分享端（[template_exporter.dart](../../../lumira_app_flutter/lib/features/templates/services/template_exporter.dart) 的 `shareTemplate`）仅分享 `.pptpl` / `.lumira` 文件。

### 方案
新增 `TemplateShareCode` 工具（放在 `template_exporter.dart` 同目录或作为其静态方法），提供两个纯函数：

- **分享码**：`buildShareCode(TemplateRecord) → 'LUMIRA-{category}-{name}'`，从 `record.meta` 读取分类与名称。
- **分享链接**：`buildShareLink(TemplateRecord, {usePptpl}) → 'lumira://tpl/{base64url(json)}'`，复用现有 `exportToLumira` / `exportToPptpl` 生成的完整 JSON，`base64UrlEncode(utf8.encode(json))`。接收端 `_parseTemplateLink` 已能解析完整 JSON 并落库（链接中的 `lumira://tpl/` 段解析逻辑已存在，需确认 base64 解码兼容 `base64Url` 编码，必要时接收端补充 `padRight` 处理）。

> 注：分享码 `LUMIRA-分类-名称` 在接收端映射为「该分类内置模板首个的默认参数」（见 `_handleQrImport`），因此分享码适合分享内置模板；自定义模板请用分享链接（携带完整 JSON）。

### 交互（入口）
- **模板详情页导出 Sheet**（[templates_detail_page.dart](../../../lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart) 导出动作）增加第二级操作。
- **导出详情页**（[export_detail_page.dart](../../../lumira_app_flutter/lib/features/templates/pages/export_detail_page.dart)）在「分享文件」旁增加两个动作：
  - **复制分享链接**：`Clipboard.setData(shareLink)` + toast。
  - **复制分享码**：`Clipboard.setData(shareCode)` + toast（仅内置模板可用时展示）。
- 提供「以文本分享」选项：`SafeShare.share('我用如画分享了模板「{name}」，链接：{link} 分享码：{code}')`。

---

## 二、URL 深链接收

### 目标平台
项目无 iOS 目录，目标 = **Android + HarmonyOS**。

### 方案（B1：自研统一 DeepLink 通道）

#### Android 侧
- [AndroidManifest.xml](../../../lumira_app_flutter/android/app/src/main/AndroidManifest.xml) 的 `MainActivity` 增加 `intent-filter`：
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="lumira" android:host="tpl"/>
  </intent-filter>
  ```
- 引入 `uni_links` 插件（已评估：仅 Android/iOS 注册，OHOS 平台不会注册实现，与 `share_plus` 在鸿蒙缺失时降级的模式一致）。Flutter 侧通过 `getInitialLink()` + `UriLinkStream` 获取链接。

#### HarmonyOS 侧（自定义插件）
- [module.json5](../../../lumira_app_flutter/ohos/entry/src/main/module.json5) 的 `EntryAbility.skills` 增加 `uris` 配置：
  ```json5
  {
    "entities": ["entity.system.viewData"],
    "actions": ["ohos.want.action.viewData"],
    "uris": [{ "scheme": "lumira", "host": "tpl", "pathStartWith": "/" }]
  }
  ```
- 新增 `DeepLinkPlugin.ets`（复用 [PhotoSaverPlugin.ets](../../../lumira_app_flutter/ohos/entry/src/main/ets/plugins/PhotoSaverPlugin.ets) 的插件模式），注册 `MethodChannel('lumira/deep_link')`：
  - `getInitialLink`：返回 Ability 启动时携带的 uri（从 want 参数解析）。
  - `onNewLink`：热启动时由 `EntryAbility.onNewWant(want)` 推送 uri 到 Flutter（通过 plugin 保存回调 + Flutter 侧事件流或轮询/通道回调）。
- [EntryAbility.ets](../../../lumira_app_flutter/ohos/entry/src/main/ets/entryability/EntryAbility.ets)：
  - 重写 `onNewWant` / 在 `onCreate` 记录 want 的 `uri` 字段，交给 `DeepLinkPlugin`。

#### Flutter 侧统一封装
- 新增 `DeepLinkService`（`lib/core/services/deep_link_service.dart`）：
  - `Future<String?> getInitialLink()`：优先 OHOS 通道，回退 uni_links（按平台分发）。
  - `Stream<String> get onLink`：OHOS 用通道事件，Android 用 uni_links 流。
  - `parseTemplateLink(String)`：复用现有 `_parseTemplateLink` 逻辑（提取为公共函数，供导入面板与深链共用）。
- **拉起流程**：App 启动（或 `main.dart` 初始化）时解析 initial link；运行中监听 onLink。命中 `lumira://tpl/` 时：
  - 若含完整 JSON → 直接走 DAO 导入（复用 [TemplateImportSheet 的导入逻辑](../../../lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart)，提取为可复用的 service 方法）。
  - 否则 → 打开模板导入面板让用户手动选择。

> ⚠️ **风险与降级**：HarmonyOS 深链需 native .ets 改动且需真机验证；若 ohos Flutter 引擎对 `onNewWant` / want 传递支持有限制，深链自动拉起降级为「App 内手动粘贴分享链接」（现状能力保留），其余功能不受影响。实现时先保证「粘贴导入」通路，再叠加「深链自动拉起」。

---

## 三、分享得积分（每日首享 +2）

### 后端
- [points.service.ts](../../../lumira-server/packages/backend/src/modules/points/points.service.ts) 的 `earnEvent` 增加 `share` 分支：
  ```ts
  const SHARE_POINTS = 2; // 每日首次分享
  // type === 'share' → points = SHARE_POINTS; eventRefId = getUtc8DateStr();（与 shoot_daily 同模式）
  ```
- [points.controller.ts](../../../lumira-server/packages/backend/src/modules/points/points.controller.ts) earn 接口 type 白名单加入 `'share'`。
- 幂等：复用 `point_earn_events` 的 `UNIQUE(device_id, type, ref_id)`，当日重复分享返回 `{ granted: false }`（200，不抛错）。

### 客户端
- 新增 `ShareReporter`（`lib/core/utils/share_reporter.dart`）：
  ```dart
  class ShareReporter {
    static Future<void> Function()? onShare;
    static void notify() => onShare?.call();
  }
  ```
- `main.dart` 启动时 wire：`ShareReporter.onShare = () => container.read(pointsRepositoryProvider)....earn(type: 'share')`（fire-and-forget，忽略错误）。
- [safe_share.dart](../../../lumira_app_flutter/lib/core/utils/safe_share.dart) 中心化接入：`shareXFiles` / `share` 调起分享后调用 `ShareReporter.notify()`，覆盖全部 7 个分享入口（拍摄预览、相册、模板文件、足迹、精选集、成就海报、碎片海报），无需逐个页面改动。
- 触发时机：调起系统分享面板即计分（无法确认用户是否真正完成分享，与「每日首拍 +2」规则一致）。

> 注意：`safe_share.dart` 当前为无状态静态工具类，通过可选静态 hook 保持解耦；测试中不 wire 或 mock hook 即可。

---

## 四、EXIF 海报优化

重写 [exif_card_generator.dart](../../../lumira_app_flutter/lib/features/capture/services/exif_card_generator.dart) 的绘制逻辑，保持输出 1080×1620 竖版 PNG：

- **顶部照片**（放大铺满）：`center-crop` 填满 `1080 × 980` 区域。绘制时从原图按目标比例计算裁剪源矩形（`srcW/srcH` 与 `dstW/dstH` 对齐后取居中裁剪），横图/竖图均不再留两侧空白。
- **参数区**：标题（EXIF）下方改为**两列网格**展示 8 项参数（相机 / 焦距 / 光圈 / ISO / 快门 / 时间 / 场景 / 模板），每项「label + value」紧凑排布，行距减小。
- **底部水印**：保留 `Lumira · 摄影学院`。
- 预览流不变：[capture_preview_page.dart](../../../lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart) 继续用 `PosterGenerator.showPoster` + `Image.file` 展示生成结果。

---

## 涉及文件清单

### Flutter（lumira_app_flutter）
| 文件 | 改动 |
|---|---|
| `pubspec.yaml` | 新增 `uni_links` 依赖 |
| `android/app/src/main/AndroidManifest.xml` | 增加 intent-filter（scheme=lumira） |
| `ohos/entry/src/main/module.json5` | EntryAbility skills 增加 uris |
| `ohos/entry/src/main/ets/entryability/EntryAbility.ets` | 处理 want uri，注册 DeepLinkPlugin |
| `ohos/entry/src/main/ets/plugins/DeepLinkPlugin.ets` | 新增：MethodChannel `lumira/deep_link` |
| `lib/core/services/deep_link_service.dart` | 新增：统一 initial link + stream + 解析 |
| `lib/core/utils/share_reporter.dart` | 新增：分享积分上报 hook |
| `lib/core/utils/safe_share.dart` | 接入 ShareReporter |
| `lib/features/templates/services/template_exporter.dart` | 新增 buildShareCode / buildShareLink |
| `lib/features/templates/pages/export_detail_page.dart` | 增加复制分享链接/分享码/文本分享 |
| `lib/features/templates/pages/templates_detail_page.dart` | 导出 Sheet 增加分享链接/码选项 |
| `lib/features/templates/widgets/template_import_sheet.dart` | 提取链接解析为公共函数（供深链复用） |
| `lib/features/capture/services/exif_card_generator.dart` | 布局重写（照片铺顶 + 两列参数） |
| `lib/app/main.dart` | wire ShareReporter + DeepLinkService 初始化 |
| `lib/app/router.dart` | （如需）深链拉起路由处理 |

### 后端（lumira-server/packages/backend）
| 文件 | 改动 |
|---|---|
| `src/modules/points/points.service.ts` | earnEvent 增加 share 分支 |
| `src/modules/points/points.controller.ts` | earn type 白名单加入 share |
| 测试 | earn share 幂等单测（当日重复 → granted:false） |

---

## 验证策略

- 后端：`earn(type='share')` 首次 granted:true、当日重复 granted:false；余额 +2。
- Flutter 单测：
  - `buildShareCode` / `buildShareLink` 生成与接收端 `_parseTemplateCode` / `_parseTemplateLink` 往返一致。
  - `DeepLinkService.parseTemplateLink` 解析 `lumira://tpl/{base64}`。
  - `ShareReporter` hook 在 SafeShare 调起后被调用（mock）。
  - EXIF 生成器输出尺寸 1080×1620 且照片区域填满（widget/像素断言可选）。
- 手测：模板导出页复制链接/码；Android 真机点击 lumira:// 链接唤起；HarmonyOS 真机深链（若受限则验证粘贴导入）；分享一次后钱包积分 +2。

## 非目标（YAGNI）

- 不做微信等国内平台 SDK 直发分享。
- 不做分享成功与否的精确确认（系统分享面板无法回传）。
- 不做分享次数成就（1/3/5/10/20 分享）的真实计数统计（当前仅 mock 数据，不在本次范围）。
- 不新增 iOS 平台（项目无 iOS 目录）。
