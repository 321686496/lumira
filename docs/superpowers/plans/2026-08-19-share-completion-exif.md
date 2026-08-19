# 分享体系完善 + EXIF 海报优化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐模板分享码/链接生成端、打通 URL 深链接收与「分享得积分」闭环、优化 EXIF 海报布局。

**Architecture:** 三个子系统并行：① 后端 points 模块扩展 `share` 事件型积分（复用 `point_earn_events` 幂等）；② Flutter 端新增 `TemplateShareCode`（生成/解析）、`TemplateImportService`（导入复用）、`ShareReporter`（分享上报 hook）、`DeepLinkService`（统一深链接收，Android 走 uni_links、HarmonyOS 走自研 MethodChannel 插件）；③ 重写 `ExifCardGenerator` 绘制逻辑（照片 center-crop 铺满顶部 + 参数两列网格）。

**Tech Stack:** NestJS + Drizzle ORM + MySQL 8；Flutter 3.7.12 / Dart 2.19.6（不支持 records 语法）；uni_links；flutter_riverpod 2.3.6。

## Global Constraints

- **Dart 2.19.6**：禁止使用 Dart 3 records 语法（`(a, b)`），用 `MapEntry` / 类替代。
- **Flutter 3.7.12**：`pubspec.yaml` 新增依赖必须兼容 Dart 2.19（uni_links 用 `^0.5.1`）。
- **共享代码位置**：模板分享码/链接的生成与解析都放在 `template_share_code.dart`，接收端与深链共用同一解析函数，保证往返一致。
- **分享积分规则**：每日首次分享 +2，幂等（`point_earn_events` 的 `UNIQUE(device_id, type, ref_id)`），当日重复返回 `{ granted: false }`（200）。
- **EXIF 输出**：保持 1080×1620 竖版 PNG；照片 center-crop 铺满顶部 1080×980；参数区两列网格；保留底部水印 `Lumira · 摄影学院`。
- **commit + push**：每个任务结束 commit 后，push 到两个远程：`git push origin master`（gitee）和 `git push github master`（github）。
- **后端 e2e 测试**依赖本机 MySQL（默认 `127.0.0.1:3306` root/root，测试库 `lumira_test`），沿用 `test/redeem.e2e-spec.ts` 的 `resetTestDatabase` 模式。
- **HarmonyOS 深链**为 best-effort：若 flutter_ohos 引擎对 want 传递支持受限，自动拉起降级为「App 内手动粘贴分享链接」（粘贴导入通路在本计划 Task 2/5 中保留），其余功能不受影响。

---

### Task 1: 后端 — 支持分享积分（share 类型）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/points/points.service.ts`（`DAILY_SHOOT_POINTS` 附近 + `earnEvent`）
- Modify: `lumira-server/packages/backend/src/modules/points/points.controller.ts`（earn 接口白名单）
- Create: `lumira-server/packages/backend/test/points.e2e-spec.ts`

**Interfaces:**
- Consumes: 现有 `earnEvent(deviceId, type, refId)`、`getBalance(deviceId)`、`getUtc8DateStr()`（`src/common/utils/date.util.ts`）
- Produces: `POST /api/v1/points/earn` 支持 `type='share'`，首次返回 `{ granted: true, delta: 2, balance }`，当日重复返回 `{ granted: false, delta: 0, balance }`。Task 4 的 `PointsRepository.earn(type: 'share')` 依赖此接口。

- [ ] **Step 1: 写失败测试 `test/points.e2e-spec.ts`**

```ts
// lumira-server/packages/backend/test/points.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

describe('PointsController (e2e)', () => {
  let app: NestFastifyApplication;
  let token: string;

  const deviceId = '44444444-4444-4444-8444-444444444444';

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    await resetTestDatabase();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/points/earn type=share → 首次 granted:true 且余额 +2', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'share' })
      .expect(201);
    expect(res.body.granted).toBe(true);
    expect(res.body.delta).toBe(2);
    expect(res.body.balance).toBe(2);
  });

  it('POST /api/v1/points/earn type=share → 当日重复 granted:false 且余额不变', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'share' })
      .expect(201);
    expect(res.body.granted).toBe(false);
    expect(res.body.delta).toBe(0);
    expect(res.body.balance).toBe(2);
  });

  it('POST /api/v1/points/earn type=unknown → 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'not-a-type' })
      .expect(400);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `lumira-server/packages/backend` 目录）:
```powershell
pnpm exec jest --config ./test/jest-e2e.json --runInBand points
```
Expected: `type=share` 用例 FAIL，报 `BadRequestException: Unsupported earn type: share`（400），说明 share 分支尚未实现。

- [ ] **Step 3: 实现后端 share 分支**

`points.service.ts` 常量区（`CHALLENGE_POINTS` 后新增）:
```ts
const DAILY_SHOOT_POINTS = 2; // 每日首次拍摄
const CHALLENGE_POINTS = 5;   // 每次完成挑战
const SHARE_POINTS = 2;       // 每日首次分享
```

`earnEvent` 的 `if/else if` 链（`challenge` 分支后新增）:
```ts
} else if (type === 'share') {
  points = SHARE_POINTS;
  // 每日首次分享：refId 按 UTC+8 自然日计算（与 shoot_daily 同模式，幂等）
  eventRefId = getUtc8DateStr();
}
```

`points.controller.ts` 的 `earn` 方法（type 断言扩展）:
```ts
    return this.pointsService.earnEvent(
      deviceId,
      type as 'shoot_daily' | 'challenge' | 'share',
      refId,
    );
```

- [ ] **Step 4: 运行测试确认通过**

Run:
```powershell
pnpm exec jest --config ./test/jest-e2e.json --runInBand points
```
Expected: 3 个用例全部 PASS（share 首享 +2、重复幂等、未知类型 400）。

- [ ] **Step 5: 提交并推送双远程**

```powershell
git add lumira-server/packages/backend/src/modules/points/points.service.ts lumira-server/packages/backend/src/modules/points/points.controller.ts lumira-server/packages/backend/test/points.e2e-spec.ts
git commit -m "feat(points): 支持每日首次分享 +2 积分（幂等）"
git push origin master
git push github master
```

---

### Task 2: Flutter — 模板分享码/链接 生成与解析（TemplateShareCode）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/services/template_share_code.dart`
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`（解析逻辑委托给 TemplateShareCode，删除 4 个私有解析方法）
- Test: `lumira_app_flutter/test/template_share_code_test.dart`

**Interfaces:**
- Consumes: `TemplateRecord`（`core/db/dao/templates_dao.dart`）、`TemplateExporter.exportToPptpl/exportToLumira`
- Produces: `TemplateShareCode.buildShareCode(TemplateRecord) → String`、`buildShareLink(TemplateRecord, {bool usePptpl}) → String`、`parseLink(String) → Map<String,dynamic>?`、`parseCode(String) → Map<String,dynamic>?`、`safeBase64Decode(String) → String?`、`normalizeCategory(String) → String`。Task 3 的导出 UI、Task 6 的 DeepLinkService 均依赖本类。

- [ ] **Step 1: 写失败测试 `test/template_share_code_test.dart`**

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '测试模板',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: {},
    tags: ['人像'],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

void main() {
  group('TemplateShareCode.buildShareCode', () {
    test('生成 LUMIRA-分类-名称', () {
      final code = TemplateShareCode.buildShareCode(_makeRecord());
      expect(code, 'LUMIRA-portrait-测试模板');
    });

    test('分类/名称中的 - 被替换为 _（保证可回解析）', () {
      final record = _makeRecord().copyWith(
        category: 'still-life',
        name: '电影-夜景',
      );
      final code = TemplateShareCode.buildShareCode(record);
      expect(code, 'LUMIRA-still_life-电影_夜景');
    });
  });

  group('TemplateShareCode.buildShareLink / parseLink 往返', () {
    test('简化 .lumira 链接可被 parseLink 解析出完整 JSON', () {
      final record = _makeRecord();
      final link = TemplateShareCode.buildShareLink(record, usePptpl: false);
      expect(link, startsWith('lumira://tpl/'));

      final parsed = TemplateShareCode.parseLink(link);
      expect(parsed, isNotNull);
      expect(parsed!['name'], '测试模板');
      expect(parsed['meta'], isA<Map>());
      expect(parsed['format'], 'lumira');
    });

    test('完整 .pptpl 链接可被 parseLink 解析', () {
      final record = _makeRecord();
      final link = TemplateShareCode.buildShareLink(record, usePptpl: true);
      final parsed = TemplateShareCode.parseLink(link);
      expect(parsed, isNotNull);
      expect(parsed!['format'], 'pptpl');
      expect(parsed['pose'], isA<Map>());
    });

    test('parseLink 兼容标准 base64（带 +/= 填充）', () {
      const json = '{"name":"A","meta":{}}';
      final b64 = base64Encode(utf8.encode(json));
      final parsed = TemplateShareCode.parseLink('lumira://tpl/$b64');
      expect(parsed, isNotNull);
      expect(parsed!['name'], 'A');
    });

    test('非模板链接返回 null', () {
      expect(TemplateShareCode.parseLink('https://example.com'), isNull);
      expect(TemplateShareCode.parseLink('lumira://other/xxx'), isNull);
      expect(TemplateShareCode.parseLink('不是链接'), isNull);
    });
  });

  group('TemplateShareCode.parseCode', () {
    test('解析 LUMIRA-分类-名称', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-portrait-测试模板');
      expect(parsed, isNotNull);
      expect(parsed!['name'], '测试模板');
      expect(parsed['category'], 'portrait');
    });

    test('非法分类回退 still-life', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-unknown-模板A');
      expect(parsed!['category'], 'still-life');
    });

    test('非 LUMIRA 前缀返回 null', () {
      expect(TemplateShareCode.parseCode('HELLO-x-y'), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `lumira_app_flutter` 目录）:
```powershell
flutter test test/template_share_code_test.dart
```
Expected: 编译 FAIL（`TemplateShareCode` 未定义）。

- [ ] **Step 3: 创建 `template_share_code.dart`**

```dart
import 'dart:convert';

import '../../../core/db/dao/templates_dao.dart';
import 'template_exporter.dart';

/// 模板分享码 / 分享链接 生成与解析工具。
///
/// - 分享码：`LUMIRA-{category}-{name}`（适合内置模板，接收端映射为分类默认参数）
/// - 分享链接：`lumira://tpl/{base64url(json)}`（携带完整模板 JSON，适合自定义模板）
///
/// 生成（buildShareCode / buildShareLink）与解析（parseCode / parseLink）
/// 必须保持往返一致，测试见 test/template_share_code_test.dart。
class TemplateShareCode {
  TemplateShareCode._();

  /// 构建分享码：`LUMIRA-{category}-{name}`
  static String buildShareCode(TemplateRecord record) {
    final category = _sanitizeSegment(record.category);
    final name = _sanitizeSegment(record.name);
    return 'LUMIRA-$category-$name';
  }

  /// 构建分享链接：`lumira://tpl/{base64url(json)}`
  ///
  /// [usePptpl] 为 true 时携带完整 .pptpl JSON（含全部 6 区段），否则为简化 .lumira JSON。
  static String buildShareLink(TemplateRecord record, {bool usePptpl = false}) {
    final json = usePptpl
        ? TemplateExporter.exportToPptpl(record)
        : TemplateExporter.exportToLumira(record);
    final encoded = base64UrlEncode(utf8.encode(json));
    return 'lumira://tpl/$encoded';
  }

  /// 解析分享链接。
  /// 支持：`lumira://tpl/{base64}` / `https://lumira.app/tpl/{base64}` / `https://lumira.app/tpl?name=...&category=...`
  static Map<String, dynamic>? parseLink(String url) {
    try {
      Uri? uri;
      try {
        uri = Uri.parse(url);
      } catch (_) {
        return null;
      }

      // 路径形式：lumira://tpl/{base64}
      if (uri.scheme == 'lumira' && uri.host == 'tpl') {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final decoded = safeBase64Decode(segments.last);
          if (decoded != null) {
            final data = jsonDecode(decoded);
            if (data is Map<String, dynamic>) {
              final name = data['name'];
              if (name is String && name.isNotEmpty) return data;
            }
          }
        }
      }

      // https://lumira.app/tpl?name=xxx&category=xxx（轻量形式，无完整 JSON）
      if (uri.scheme == 'https' && uri.host.endsWith('lumira.app')) {
        final params = uri.queryParameters;
        if (params.containsKey('name') && params['name']!.isNotEmpty) {
          return {
            'name': params['name'],
            'category': params['category'] ?? 'still-life',
            'tags': params['tags']?.split(',') ?? <String>[],
            'coverSeed': params['coverSeed'],
          };
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 解析分享码（LUMIRA-分类-名称）
  static Map<String, dynamic>? parseCode(String code) {
    if (!code.startsWith('LUMIRA-')) return null;

    final parts = code.split('-');
    if (parts.length < 3) return null;

    final category = normalizeCategory(parts[1].toLowerCase());
    final name = parts.sublist(2).join('-');

    return {
      'name': name,
      'category': category,
      'tags': <String>['导入'],
      'coverSeed': 'qr-$code',
    };
  }

  /// base64url 解码（兼容标准 base64 的 +/ 与 = 填充）
  static String? safeBase64Decode(String s) {
    try {
      final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized + '=' * ((4 - normalized.length % 4) % 4);
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      return null;
    }
  }

  /// 分类名归一化：非法分类回退到 still-life
  static String normalizeCategory(String s) {
    const valid = {
      'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'
    };
    return valid.contains(s) ? s : 'still-life';
  }

  /// 清理分享码分段：去除会破坏 `LUMIRA-a-b` 拆分的字符（`-`、空白等）
  static String _sanitizeSegment(String s) {
    return s.trim().replaceAll(RegExp(r'[-\\s]'), '_');
  }
}
```

- [ ] **Step 4: 重构 `template_import_sheet.dart` 委托解析逻辑**

在 import 区新增:
```dart
import '../services/template_share_code.dart';
```

删除私有方法 `_parseTemplateLink`、`_parseTemplateCode`、`_safeBase64Decode`、`_normalizeCategory`（原文件第 401-482 行），替换调用点:

`_handleLinkImport`（原第 233 行）:
```dart
    final parsed = TemplateShareCode.parseLink(url.trim());
```

`_handleQrImport`（原第 306 行）:
```dart
    final parsed = TemplateShareCode.parseCode(code.trim());
```

- [ ] **Step 5: 运行测试确认通过**

Run:
```powershell
flutter test test/template_share_code_test.dart
flutter test test/template_import_test.dart
```
Expected: 全部 PASS（新往返测试 + 既有导入测试，确认粘贴导入通路未回归）。

- [ ] **Step 6: 提交并推送双远程**

```powershell
git add lumira_app_flutter/lib/features/templates/services/template_share_code.dart lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart lumira_app_flutter/test/template_share_code_test.dart
git commit -m "feat(templates): 模板分享码/链接生成与解析（与接收端往返一致）"
git push origin master
git push github master
```

---

### Task 3: Flutter — 导出 UI 增加分享链接/分享码/文本分享

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`（导出 Sheet 增加复制链接/码选项 + 传 shareLink/shareCode 给导出详情页）
- Modify: `lumira_app_flutter/lib/features/templates/pages/export_detail_page.dart`（增加复制链接/复制码/文本分享按钮）
- Modify: `lumira_app_flutter/lib/app/router.dart`（templatesExportDetail 路由透传 shareLink/shareCode）

**Interfaces:**
- Consumes: `TemplateShareCode.buildShareLink/buildShareCode`（Task 2）、`SafeShare.share`、`Clipboard`
- Produces: 导出详情页新增可选入参 `shareLink` / `shareCode`；导出 Sheet 新增复制操作。Task 4 的 `SafeShare` 接入后，本任务里的 `SafeShare.share` 会自动触发分享积分上报。

- [ ] **Step 1: `templates_detail_page.dart` — 导出 Sheet 增加复制链接/分享码，并传参给导出详情页**

import 区新增:
```dart
import 'package:flutter/services.dart';
import '../../../core/utils/safe_share.dart';
import '../services/template_share_code.dart';
```

在 `_showExportFormatSheet` 中、`简化 .lumira` tile 之后、`取消` tile 之前，插入:
```dart
          LumiraListTile(
            leading: Icon(Icons.link_outlined, color: tokens.brand),
            title: const Text('复制分享链接'),
            subtitle: const Text('粘贴到微信/聊天，对方用如画导入'),
            onTap: () {
              Navigator.pop(ctx, null);
              _copyShareLink(record);
            },
          ),
          if (record.isBuiltin)
            LumiraListTile(
              leading: Icon(Icons.qr_code_2_outlined, color: tokens.brand),
              title: const Text('复制分享码'),
              subtitle: const Text('内置模板：对方输入分享码即可导入'),
              onTap: () {
                Navigator.pop(ctx, null);
                _copyShareCode(record);
              },
            ),
          LumiraListTile(
            leading: Icon(Icons.chat_bubble_outline, color: tokens.brand),
            title: const Text('以文本分享'),
            subtitle: const Text('发送模板名 + 链接 + 分享码'),
            onTap: () {
              Navigator.pop(ctx, null);
              _shareAsText(record);
            },
          ),
```

`_showExportFormatSheet` 的 push 处（原第 209-216 行）改为:
```dart
      GoRouter.of(context).push(
        RouteNames.templatesExportDetail,
        extra: {
          'filePath': filePath,
          'templateName': record.name,
          'usePptpl': usePptpl,
          'shareLink': TemplateShareCode.buildShareLink(record, usePptpl: usePptpl),
          'shareCode': record.isBuiltin ? TemplateShareCode.buildShareCode(record) : null,
        },
      );
```

新增私有方法（放在 `_showExportFormatSheet` 之后）:
```dart
  Future<void> _copyShareLink(TemplateRecord record) async {
    final link = TemplateShareCode.buildShareLink(record);
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('分享链接已复制');
  }

  Future<void> _copyShareCode(TemplateRecord record) async {
    final code = TemplateShareCode.buildShareCode(record);
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('分享码已复制');
  }

  Future<void> _shareAsText(TemplateRecord record) async {
    final link = TemplateShareCode.buildShareLink(record);
    final code = TemplateShareCode.buildShareCode(record);
    await SafeShare.share(
      '我用如画分享了模板「${record.name}」\n链接：$link\n分享码：$code',
      subject: '如画模板：${record.name}',
    );
  }
```

- [ ] **Step 2: `router.dart` — templatesExportDetail 透传 shareLink/shareCode**

在 `templatesExportDetail` builder（原第 246-268 行）中，`extra` 分支与 query 分支都补上:
```dart
          final extra = state.extra as Map<String, dynamic>?;
          if (extra != null) {
            filePath = extra['filePath'] as String? ?? '';
            templateName = extra['templateName'] as String? ?? '';
            usePptpl = (extra['usePptpl'] as bool?) ?? false;
            shareLink = extra['shareLink'] as String?;
            shareCode = extra['shareCode'] as String?;
          } else {
            filePath = state.queryParams['filePath'] ?? '';
            templateName = state.queryParams['templateName'] ?? '';
            usePptpl = state.queryParams['usePptpl'] == 'true';
            shareLink = state.queryParams['shareLink'];
            shareCode = state.queryParams['shareCode'];
          }

          return ExportDetailPage(
            filePath: filePath,
            templateName: templateName,
            usePptpl: usePptpl,
            shareLink: shareLink,
            shareCode: shareCode,
          );
```
需在 builder 顶部声明 `String? shareLink; String? shareCode;`。

- [ ] **Step 3: `export_detail_page.dart` — 增加复制链接/码/文本分享按钮**

import 区新增:
```dart
import 'package:flutter/services.dart';
import '../services/template_share_code.dart';
```

Widget 新增两个可选入参:
```dart
  const ExportDetailPage({
    super.key,
    required this.filePath,
    required this.templateName,
    required this.usePptpl,
    this.shareLink,
    this.shareCode,
  });

  final String? shareLink;
  final String? shareCode;
```

在「分享文件」按钮之后（原第 373 行后）追加:
```dart
          if (widget.shareLink != null) ...[
            const SizedBox(height: 12),
            LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => _copyText(widget.shareLink!, '分享链接已复制'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text('复制分享链接'),
                ],
              ),
            ),
          ],
          if (widget.shareCode != null) ...[
            const SizedBox(height: 12),
            LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => _copyText(widget.shareCode!, '分享码已复制'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text('复制分享码'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: _shareAsText,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 8),
                const Text('以文本分享'),
              ],
            ),
          ),
```

新增私有方法（放在 `_shareFile` 之后）:
```dart
  Future<void> _copyText(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    LumiraToast.show(context, toast);
  }

  Future<void> _shareAsText() async {
    final link = widget.shareLink ?? '';
    final code = widget.shareCode ?? '';
    await SafeShare.share(
      '我用如画分享了模板「${widget.templateName}」\n链接：$link\n分享码：$code',
      subject: '如画模板：${widget.templateName}',
    );
  }
```

- [ ] **Step 4: 静态检查 + 手测**

Run:
```powershell
flutter analyze
```
Expected: 无新增 error。

手测：模板详情页 → 导出图标 → Sheet 出现「复制分享链接 / 复制分享码（仅内置）/ 以文本分享」；选择格式后导出详情页出现对应按钮；点复制后剪贴板内容正确；以文本分享唤起系统分享。

- [ ] **Step 5: 提交并推送双远程**

```powershell
git add lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart lumira_app_flutter/lib/features/templates/pages/export_detail_page.dart lumira_app_flutter/lib/app/router.dart
git commit -m "feat(templates): 导出页/导出面板增加分享链接、分享码与文本分享"
git push origin master
git push github master
```

---

### Task 4: Flutter — 分享得积分上报（ShareReporter）

**Files:**
- Create: `lumira_app_flutter/lib/core/utils/share_reporter.dart`
- Modify: `lumira_app_flutter/lib/core/utils/safe_share.dart`（shareXFiles / share 尾部调用 notify）
- Modify: `lumira_app_flutter/lib/app/main.dart`（启动时 wire onShare）
- Test: `lumira_app_flutter/test/share_reporter_test.dart`

**Interfaces:**
- Consumes: `pointsRepositoryProvider`（`features/points/data/points_repository.dart`）、后端 `POST /points/earn`（Task 1）
- Produces: `ShareReporter.onShare`（可注入 hook）+ `ShareReporter.notify()`。所有经 `SafeShare` 的分享入口（拍摄预览/相册/模板/足迹/精选集/成就海报/碎片海报 + Task 3 的文本分享）自动上报。

- [ ] **Step 1: 写失败测试 `test/share_reporter_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/safe_share.dart';
import 'package:lumira_app_flutter/core/utils/share_reporter.dart';

void main() {
  test('notify 触发 onShare hook（同步段立即执行）', () {
    var called = 0;
    ShareReporter.onShare = () async {
      called++;
    };
    ShareReporter.notify();
    expect(called, 1);
    ShareReporter.onShare = null;
  });

  test('未 wire hook 时 notify 不抛错', () {
    ShareReporter.onShare = null;
    expect(ShareReporter.notify, returnsNormally);
  });

  test('SafeShare.share 调起后调用 notify（测试环境走剪贴板降级路径）', () async {
    var called = 0;
    ShareReporter.onShare = () async {
      called++;
    };
    await SafeShare.share('hello');
    expect(called, 1);
    ShareReporter.onShare = null;
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```powershell
flutter test test/share_reporter_test.dart
```
Expected: 编译 FAIL（`ShareReporter` 未定义）。

- [ ] **Step 3: 创建 `share_reporter.dart`**

```dart
/// 分享积分上报 hook。
///
/// SafeShare 调起分享后调用 [notify]，由 main.dart 在启动时 wire 到
/// pointsRepository.earn(type: 'share')（每日首享 +2，fire-and-forget）。
/// 保持无状态静态类 + 可选 hook，便于测试不 wire 或 mock。
class ShareReporter {
  ShareReporter._();

  static Future<void> Function()? onShare;

  static void notify() {
    final hook = onShare;
    if (hook == null) return;
    // fire-and-forget：上报失败不影响分享主流程
    // ignore: unawaited_futures
    hook();
  }
}
```

- [ ] **Step 4: `safe_share.dart` 接入 notify**

import 区新增:
```dart
import 'share_reporter.dart';
```

`shareXFiles` 方法体末尾（catch 分支之后）新增一行:
```dart
    ShareReporter.notify();
```

`share` 方法体末尾（catch 分支之后）新增一行:
```dart
    ShareReporter.notify();
```

（修改后的 `shareXFiles` 整体参考）:
```dart
  static Future<void> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
  }) async {
    try {
      await Share.shareXFiles(
        files,
        subject: subject,
        text: text,
      );
    } on MissingPluginException {
      debugPrint('[safe_share] share_plus 未注册，降级到剪贴板');
      await _fallbackToClipboard(files.first.path);
    } catch (e) {
      debugPrint('[safe_share] shareXFiles 异常: $e');
      await _fallbackToClipboard(files.first.path);
    }
    ShareReporter.notify();
  }
```

- [ ] **Step 5: `main.dart` 启动时 wire**

import 区新增:
```dart
import 'core/utils/share_reporter.dart';
import 'features/points/data/points_repository.dart';
```

在 `container` 创建之后、`runApp` 之前（原第 68 行后）插入:
```dart
  // 4.5 分享积分上报：调起系统分享即计分（每日首享 +2，幂等由后端保证）
  ShareReporter.onShare = () async {
    try {
      final repo = await container.read(pointsRepositoryProvider.future);
      await repo.earn(type: 'share');
    } catch (_) {
      // 网络/鉴权失败静默，不影响分享主流程
    }
  };
```

- [ ] **Step 6: 运行测试确认通过**

Run:
```powershell
flutter test test/share_reporter_test.dart
flutter test test/template_share_code_test.dart
```
Expected: 全部 PASS。

- [ ] **Step 7: 提交并推送双远程**

```powershell
git add lumira_app_flutter/lib/core/utils/share_reporter.dart lumira_app_flutter/lib/core/utils/safe_share.dart lumira_app_flutter/lib/app/main.dart lumira_app_flutter/test/share_reporter_test.dart
git commit -m "feat(share): 分享即上报积分（每日首享 +2，SafeShare 中心化接入）"
git push origin master
git push github master
```

---

### Task 5: Flutter — 模板导入服务抽取（供粘贴导入与深链共用）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/services/template_import_service.dart`
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`（文件/链接导入改走 `TemplateImportService.importJson`）

**Interfaces:**
- Consumes: `TemplateMapper.recordFromImportedJson`、`PptplFormat.validate`、`TemplatesDao`、`CaptureState.allTemplatesProvider`
- Produces: `TemplateImportService.importJson(Map<String,dynamic>, {required TemplatesDao dao, required Future<void> Function() invalidateTemplates}) → Future<TemplateImportResult>`；`TemplateImportResult{ok, id, error, message, warnings}`。Task 6 深链直接导入复用本方法。

- [ ] **Step 1: 写失败测试（随 Task 6 一并验证；本任务先建服务与重构）**

本任务的可验证交付 = 既有 `test/template_import_test.dart` 与 `test/template_mapper_test.dart` 不回归 + `flutter analyze` 通过。深链导入的端到端单测放 Task 6 Step 5。

- [ ] **Step 2: 创建 `template_import_service.dart`**

```dart
import '../../../core/db/dao/templates_dao.dart';
import '../../capture/data/capture_state.dart';
import 'pptpl_format.dart';
import 'template_mapper.dart';

/// 模板导入结果（无 UI 依赖，由调用方负责 toast / 弹窗）
class TemplateImportResult {
  final bool ok;
  final String? id; // 导入成功的模板 id（ok=true 时）
  final String? error; // 失败原因（ok=false 时）
  final String message; // 成功提示文本（ok=true 时）
  final List<TemplateImportWarning> warnings;

  const TemplateImportResult({
    required this.ok,
    this.id,
    this.error,
    this.message = '',
    this.warnings = const [],
  });
}

/// 模板导入服务：把已解析的模板 JSON 持久化到本地 DAO。
/// 供「从链接导入」「从文件导入」及「深链自动导入」复用，逻辑单一来源。
class TemplateImportService {
  TemplateImportService._();

  /// 导入完整模板 JSON（format/meta 形式）。
  ///
  /// [invalidateTemplates]：导入成功后刷新 Capture 页模板缓存
  /// （如 CaptureState.allTemplatesProvider），使新模板立即出现在拍摄页。
  static Future<TemplateImportResult> importJson(
    Map<String, dynamic> json, {
    required TemplatesDao dao,
    required Future<void> Function() invalidateTemplates,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final warnings = PptplFormat.validate(json);
      var record = TemplateMapper.recordFromImportedJson(json, createdAt: now);

      // ID 冲突处理：已存在则追加 _imported_ 时间戳后缀
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = record.copyWith(id: finalId);
      }

      await dao.upsert(record);
      await invalidateTemplates();

      return TemplateImportResult(
        ok: true,
        id: record.id,
        message: '已导入模板：${record.name}',
        warnings: warnings,
      );
    } catch (e) {
      return TemplateImportResult(ok: false, error: '$e');
    }
  }
}
```

- [ ] **Step 3: 重构 `template_import_sheet.dart` 使用 importJson**

import 区新增:
```dart
import '../services/template_import_service.dart';
```

`_handleFileImport` 中，删除原来的「ID 冲突处理 + upsert + invalidate」块（原第 180-195 行），替换为:
```dart
      final dao = await ref.read(templatesDaoProvider.future);
      final result = await TemplateImportService.importJson(
        parsed,
        dao: dao,
        invalidateTemplates: () async =>
            ref.invalidate(CaptureState.allTemplatesProvider),
      );
      if (!result.ok) {
        if (context.mounted) {
          navigator.pop();
          _showToast(context, '导入失败：${result.error}');
        }
        return;
      }

      if (context.mounted) {
        if (result.warnings.isNotEmpty) {
          _showWarningsDialog(context, result.warnings);
        }
        _showToast(context, result.message);
        navigator.pop();
      }
      onImported(result.id!);
```

`_handleLinkImport` 中，删除原来的「完整 JSON → 走 DAO 持久化」try 块内部逻辑（原第 252-280 行），替换为:
```dart
    // 完整 JSON 形式 → 走 DAO 持久化
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final result = await TemplateImportService.importJson(
        parsed,
        dao: dao,
        invalidateTemplates: () async =>
            ref.invalidate(CaptureState.allTemplatesProvider),
      );
      if (!result.ok) {
        if (context.mounted) {
          navigator.pop();
          _showToast(context, '导入失败：${result.error}');
        }
        return;
      }

      if (context.mounted) {
        _showToast(context, result.message);
        if (result.warnings.isNotEmpty) {
          _showWarningsDialog(context, result.warnings);
        }
        navigator.pop();
      }
      onImported(result.id!);
    } catch (e, st) {
      debugPrint('[TemplateImport] link FAILED: $e\n$st');
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '导入失败：$e');
      }
    }
```

- [ ] **Step 4: 运行既有测试确认不回归**

Run:
```powershell
flutter test test/template_import_test.dart
flutter test test/template_mapper_test.dart
flutter analyze
```
Expected: 全部 PASS，无新增 error。

- [ ] **Step 5: 提交并推送双远程**

```powershell
git add lumira_app_flutter/lib/features/templates/services/template_import_service.dart lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart
git commit -m "refactor(templates): 抽取 TemplateImportService 复用导入逻辑"
git push origin master
git push github master
```

---

### Task 6: Flutter — URL 深链接收（DeepLinkService + Android + 拉起流程）

**Files:**
- Modify: `lumira_app_flutter/pubspec.yaml`（新增 uni_links）
- Modify: `lumira_app_flutter/android/app/src/main/AndroidManifest.xml`（intent-filter）
- Create: `lumira_app_flutter/lib/core/services/deep_link_service.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`（navigatorKey 导出）
- Modify: `lumira_app_flutter/lib/app/main.dart`（start + _handleTemplateLink）
- Test: `lumira_app_flutter/test/deep_link_service_test.dart`

**Interfaces:**
- Consumes: `TemplateShareCode.parseLink`（Task 2）、`TemplateImportService.importJson`（Task 5）、`TemplateImportSheet.show`、`CaptureState.allTemplatesProvider`
- Produces: `DeepLinkService.instance.start({void Function(String link)? onTemplateLink})`、`getInitialLink()`、`onLink`、`isTemplateLink(String)`。Task 7 的 OHOS 插件通过同一 service 分发。

- [ ] **Step 1: 写失败测试 `test/deep_link_service_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/services/deep_link_service.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isTemplateLink：lumira://tpl 深链为 true', () {
    final link = TemplateShareCode.buildShareLink(
      TemplateRecordForTest.make(),
    );
    expect(DeepLinkService.isTemplateLink(link), isTrue);
  });

  test('isTemplateLink：非模板链接为 false', () {
    expect(DeepLinkService.isTemplateLink('https://example.com'), isFalse);
    expect(DeepLinkService.isTemplateLink('lumira://other/abc'), isFalse);
  });
}
```
（`TemplateRecordForTest.make()` 为本测试文件内新增的构造辅助类，返回与 `_makeRecord()` 相同的 `TemplateRecord`，见 Step 3 示例。）

- [ ] **Step 2: 运行测试确认失败**

Run:
```powershell
flutter test test/deep_link_service_test.dart
```
Expected: 编译 FAIL（`DeepLinkService` 未定义）。

- [ ] **Step 3: 添加 uni_links 依赖 + 创建 `deep_link_service.dart`**

`pubspec.yaml` dependencies 区（`share_plus` 附近）新增:
```yaml
  # URL 深链接收（仅 Android/iOS 注册原生实现；OHOS 走自研 MethodChannel，见 ohos DeepLinkPlugin）
  uni_links: ^0.5.1
```

创建 `lib/core/services/deep_link_service.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uni_links/uni_links.dart' as uni_links;

import '../../features/templates/services/template_share_code.dart';

/// 统一 URL 深链接收服务。
///
/// 平台分发：
/// - HarmonyOS：自定义 MethodChannel `lumira/deep_link`（见 ohos DeepLinkPlugin.ets）
/// - Android / 其他：uni_links 插件
/// 均封装为 [getInitialLink] + [onLink]，业务层只关心链接字符串。
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  String? _initial;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<String>.broadcast();

  /// 运行中收到的深链（冷启动 initial 链接也会先推送）
  Stream<String> get onLink => _controller.stream;

  void Function(String link)? onTemplateLink;

  /// 启动监听：读取冷启动链接 + 订阅运行中链接。
  Future<void> start({void Function(String link)? onTemplateLink}) async {
    this.onTemplateLink = onTemplateLink;
    _controller.stream.listen(_dispatch);

    final initial = await getInitialLink();
    if (initial != null && initial.isNotEmpty) {
      // 等首帧挂载后再分发，确保 navigator 就绪
      WidgetsBinding.instance.addPostFrameCallback((_) => _dispatch(initial));
    }
    _subscribeStream();
  }

  /// 冷启动时的初始链接（null = 无）
  Future<String?> getInitialLink() async {
    if (_initial != null) return _initial;
    try {
      if (Platform.operatingSystem == 'ohos') {
        const channel = MethodChannel('lumira/deep_link');
        final link = await channel.invokeMethod<String>('getInitialLink');
        _initial = (link == null || link.isEmpty) ? null : link;
        return _initial;
      }
      final link = await uni_links.getInitialLink();
      _initial = link;
      return _initial;
    } catch (_) {
      // 插件缺失 / 平台不支持 → 静默降级（粘贴导入通路保留）
      return null;
    }
  }

  void _subscribeStream() {
    if (Platform.operatingSystem == 'ohos') return; // OHOS 走插件通道
    _sub ??= uni_links.uriLinkStream.listen((uri) {
      final link = uri?.toString();
      if (link != null && link.isNotEmpty) {
        _controller.add(link);
      }
    });
  }

  void _dispatch(String link) {
    if (isTemplateLink(link)) {
      onTemplateLink?.call(link);
    }
  }

  /// 判断链接是否命中模板深链（可被 [TemplateShareCode.parseLink] 解析）
  static bool isTemplateLink(String link) {
    return TemplateShareCode.parseLink(link) != null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
```

- [ ] **Step 4: `router.dart` 导出 rootNavigatorKey + `main.dart` 拉起流程**

`router.dart` 顶部（`final routerProvider` 之前）新增:
```dart
/// 全局导航 key：供深链/后台任务在无页面 context 时唤起 UI
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
```

`routerProvider` 中 `return GoRouter(` 处加:
```dart
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
```

`main.dart` import 区新增:
```dart
import 'core/router/route_names.dart';
import 'core/services/deep_link_service.dart';
import 'features/templates/services/template_import_service.dart';
import 'features/templates/services/template_share_code.dart';
import 'features/templates/widgets/template_import_sheet.dart';
```

`main()` 中、`runApp(...)` 之前（`ShareReporter.onShare` 赋值之后）插入:
```dart
  // 7. 深链监听：冷启动链接 + 运行中链接
  // ignore: unawaited_futures
  DeepLinkService.instance.start(
    onTemplateLink: (link) => _handleTemplateLink(container, link),
  );
```

`main.dart` 底部新增顶层函数:
```dart
/// 处理模板深链：完整 JSON → 直接导入；否则打开导入面板让用户手动操作。
void _handleTemplateLink(ProviderContainer container, String link) {
  final parsed = TemplateShareCode.parseLink(link);
  if (parsed == null || !(parsed['meta'] is Map)) {
    // 无法解析或为轻量形式 → 打开导入面板手动粘贴/选择
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      TemplateImportSheet.show(ctx, onImported: (_) {});
    }
    return;
  }

  // 完整 JSON → 直接导入本地
  // ignore: unawaited_futures
  container.read(templatesDaoProvider.future).then((dao) async {
    final result = await TemplateImportService.importJson(
      parsed,
      dao: dao,
      invalidateTemplates: () async {
        container.invalidate(CaptureState.allTemplatesProvider);
      },
    );
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(result.ok ? result.message : '导入失败：${result.error}'),
    ));
    if (result.ok) {
      GoRouter.of(ctx).go(RouteNames.profileMyTemplates);
    }
  });
}
```
（`main.dart` 需新增 import：`features/capture/data/capture_state.dart`，用于 `CaptureState.allTemplatesProvider`。）

- [ ] **Step 5: 补全测试文件（含记录构造辅助）并运行**

`test/deep_link_service_test.dart` 完整内容:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/services/deep_link_service.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';

class TemplateRecordForTest {
  static TemplateRecord make() {
    return TemplateRecord(
      id: 'r1',
      name: '测试模板',
      author: 'tester',
      version: '1.0.0',
      category: 'portrait',
      classification: {},
      tags: ['人像'],
      tagIds: [],
      price: 0,
      cover: '',
      description: '',
      referenceSource: '',
      composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
      pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
      camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
      sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
      postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
      createdAt: 1700000000000,
      updatedAt: 1700000000000,
      isBuiltin: false,
      isRecommended: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isTemplateLink：lumira://tpl 深链为 true', () {
    final link = TemplateShareCode.buildShareLink(TemplateRecordForTest.make());
    expect(DeepLinkService.isTemplateLink(link), isTrue);
  });

  test('isTemplateLink：非模板链接为 false', () {
    expect(DeepLinkService.isTemplateLink('https://example.com'), isFalse);
    expect(DeepLinkService.isTemplateLink('lumira://other/abc'), isFalse);
  });
}
```

Run:
```powershell
flutter test test/deep_link_service_test.dart
flutter analyze
```
Expected: 全部 PASS，无新增 error。

- [ ] **Step 6: Android 真机手测**

`AndroidManifest.xml` 的 `MainActivity` 内、现有 MAIN intent-filter 之后新增:
```xml
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="lumira" android:host="tpl"/>
            </intent-filter>
```

手测：Android 真机安装后，在浏览器/备忘录输入 `lumira://tpl/{导出页复制的链接后半段}` 点击，App 应唤起并直接导入模板。

- [ ] **Step 7: 提交并推送双远程**

```powershell
git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock lumira_app_flutter/android/app/src/main/AndroidManifest.xml lumira_app_flutter/lib/core/services/deep_link_service.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/app/main.dart lumira_app_flutter/test/deep_link_service_test.dart
git commit -m "feat(deeplink): URL 深链接收（uni_links + 统一 DeepLinkService + 拉起导入）"
git push origin master
git push github master
```

---

### Task 7: HarmonyOS — 原生深链插件（best-effort）

**Files:**
- Modify: `lumira_app_flutter/ohos/entry/src/main/module.json5`（EntryAbility skills 增加 uris）
- Create: `lumira_app_flutter/ohos/entry/src/main/ets/plugins/DeepLinkPlugin.ets`
- Modify: `lumira_app_flutter/ohos/entry/src/main/ets/entryability/EntryAbility.ets`（注册插件 + 透传 want uri）

**Interfaces:**
- Consumes: Task 6 的 `DeepLinkService.getInitialLink()`（OHOS 分支读 MethodChannel `lumira/deep_link`）
- Produces: MethodChannel `lumira/deep_link` 的 `getInitialLink` 方法，返回 Ability 启动 want 中的 `lumira://tpl/...` uri。**需真机验证；若 flutter_ohos 引擎对 want 传递支持受限，本任务可降级（粘贴导入通路已由 Task 2/5 保证），不阻塞其余功能。**

- [ ] **Step 1: `module.json5` 增加 uris 技能**

`EntryAbility.skills`（原第 24-33 行）追加一个 skill:
```json5
          {
            "entities": [
              "entity.system.viewData"
            ],
            "actions": [
              "ohos.want.action.viewData"
            ],
            "uris": [
              {
                "scheme": "lumira",
                "host": "tpl",
                "pathStartWith": "/"
              }
            ]
          }
```

- [ ] **Step 2: 创建 `DeepLinkPlugin.ets`**

```ets
import {
  FlutterPlugin,
  FlutterPluginBinding,
  AbilityAware,
  AbilityPluginBinding
} from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';

/**
 * HarmonyOS 原生深链插件。
 * 通过 MethodChannel "lumira/deep_link" 与 Flutter 层通信。
 *
 * 能力：
 * - getInitialLink：返回 Ability 冷启动时携带的 lumira:// uri。
 * - pushLink：由 EntryAbility 在收到新 want 时调用，主动推送 uri 给 Flutter。
 *
 * ⚠️ best-effort：flutter_ohos 引擎对 onNewWant / want 透传的支持需真机验证；
 * 若受限，仅 getInitialLink（冷启动）生效，热启动自动拉起降级为「App 内手动粘贴」。
 */
export default class DeepLinkPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private pendingLink: string | null = null;
  // 记录 EntryAbility 启动/热启动时收到的 uri（插件在 configureFlutterEngine 中创建，晚于 onCreate）
  static latestLaunchUri: string | null = null;

  getUniqueClassName(): string {
    return 'DeepLinkPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/deep_link');
    this.channel.setMethodCallHandler(this);
    // 冷启动 want 在 onCreate 时已记录
    if (DeepLinkPlugin.latestLaunchUri) {
      this.pendingLink = DeepLinkPlugin.latestLaunchUri;
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    // 无额外处理；uri 通过静态 latestLaunchUri 传递
  }

  onDetachedFromAbility(): void {
    // 无额外处理
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getInitialLink':
        result.success(this.pendingLink ?? '');
        this.pendingLink = null;
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /** 由 EntryAbility 在收到新 want 时调用，推送热启动 uri */
  static notifyNewLink(uri: string): void {
    DeepLinkPlugin.latestLaunchUri = uri;
    // 若通道已就绪且 Flutter 侧支持 native→Dart 调用，可在此推送；
    // 当前最小实现：Flutter 侧在 getInitialLink 阶段消费 latestLaunchUri。
  }
}
```

- [ ] **Step 3: `EntryAbility.ets` 注册插件 + 记录 want uri**

import 区新增:
```ets
import DeepLinkPlugin from '../plugins/DeepLinkPlugin';
import { Want, AbilityConstant } from '@kit.AbilityKit';
```

`configureFlutterEngine` 末尾新增:
```ets
    // 注册原生深链插件（uni_links 无 ohos 实现）
    flutterEngine.getPlugins()?.add(new DeepLinkPlugin());
```

类内新增生命周期方法（**若编译报 `super.onCreate` / `super.onNewWant` 不存在，则去掉 super 调用仅保留静态记录**）:
```ets
  override onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    DeepLinkPlugin.notifyNewLink(this.extractUri(want));
  }

  override onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    DeepLinkPlugin.notifyNewLink(this.extractUri(want));
  }

  private extractUri(want: Want): string {
    // 从 want 中取 uri 字段（深链 want 的 uri 在 want.uri）
    const uri: string | undefined = (want as Want & { uri?: string }).uri;
    return (uri && uri.length > 0) ? uri : '';
  }
```

- [ ] **Step 4: 真机验证（或降级确认）**

- 在 DevEco Studio 构建 ohos 工程，安装到 HarmonyOS 真机。
- 手测：浏览器/备忘录打开 `lumira://tpl/{链接}`，确认 App 唤起并导入。
- 若唤起失败：确认粘贴导入通路（Task 2/5）可用，并在本任务 Step 5 提交说明中标注「OHOS 深链受限，保留粘贴导入」。
- 若编译报错（如 flutter_ohos 未暴露 `onNewWant`），按 Step 3 括号说明调整后重新编译。

- [ ] **Step 5: 提交并推送双远程**

```powershell
git add lumira_app_flutter/ohos/entry/src/main/module.json5 lumira_app_flutter/ohos/entry/src/main/ets/plugins/DeepLinkPlugin.ets lumira_app_flutter/ohos/entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(deeplink): HarmonyOS 原生深链插件（best-effort，真机验证）"
git push origin master
git push github master
```

---

### Task 8: Flutter — EXIF 海报优化（照片铺满 + 两列参数）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/services/exif_card_generator.dart`（重写绘制逻辑）
- Test: `lumira_app_flutter/test/exif_card_generator_test.dart`

**Interfaces:**
- Consumes: 现有 `ExifInfo`、`generate({photoPath, outputPath, exif})` 签名不变
- Produces: 输出仍为 1080×1620 PNG；照片 center-crop 铺满顶部 1080×980；参数区两列网格；底部水印保留。预览流（`capture_preview_page.dart` 用 `PosterGenerator.showPoster` + `Image.file`）无需改动。

- [ ] **Step 1: 写失败测试 `test/exif_card_generator_test.dart`**

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/exif_card_generator.dart';

Future<String> _createTestPhoto(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFE04040), // 纯红照片
  );
  final img = await recorder.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  final dir = await Directory.systemTemp.createTemp('exif_src');
  final path = '${dir.path}/photo.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生成 1080x1620 海报且竖图照片铺满无左右留白', () async {
    final photoPath = await _createTestPhoto(100, 200); // 竖图（旧实现左右留白大）
    final outDir = await Directory.systemTemp.createTemp('exif_out');
    final outPath = '${outDir.path}/card.png';

    await ExifCardGenerator.generate(
      photoPath: photoPath,
      outputPath: outPath,
      exif: const ExifInfo(
        cameraModel: 'HUAWEI P50',
        focalLength: '35mm',
        fNumber: 'f/1.8',
        iso: 'ISO 200',
        shutterSpeed: '1/200s',
        timestamp: '2026-08-19 10:00',
        sceneName: '人像',
        template: '经典人像',
      ),
    );

    final bytes = await File(outPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    try {
      expect(img.width, 1080);
      expect(img.height, 1620);

      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = data!.buffer.asUint8List();
      ui.Color px(int x, int y) {
        final i = (y * img.width + x) * 4;
        return ui.Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
      }

      // 照片区：中间 + 左边缘 都应是照片红色（铺满，无白边）
      final mid = px(540, 600);
      expect(mid.r, greaterThan(200));
      expect(mid.g, lessThan(100));
      expect(mid.b, lessThan(100));

      final leftEdge = px(2, 600);
      expect(leftEdge.r, greaterThan(200));
      expect(leftEdge.g, lessThan(100));
      expect(leftEdge.b, lessThan(100));

      // 标题区背景：深色（0xFF1C1A17）
      final topBg = px(2, 20);
      expect(topBg.r, lessThan(80));
    } finally {
      img.dispose();
      codec.dispose();
    }
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```powershell
flutter test test/exif_card_generator_test.dart
```
Expected: FAIL（旧实现竖图左右留白，`leftEdge` 为背景深色而非红色）。

- [ ] **Step 3: 重写 `exif_card_generator.dart` 绘制逻辑**

将 `generate` 方法体整体替换为（类头、`ExifInfo` 不变）:
```dart
  static Future<String> generate({
    required String photoPath,
    required String outputPath,
    required ExifInfo exif,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码原图
      final bytes = await File(photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      // 2. 卡片尺寸：竖版 1080x1620（3:4.5），适合分享
      const cardW = 1080;
      const cardH = 1620;
      const padding = 48;

      // 3. 顶部照片区：铺满 1080x980，center-crop
      const photoTop = 110;
      const photoH = 980;
      final photoRect = ui.Rect.fromLTWH(
          0, photoTop.toDouble(), cardW.toDouble(), photoH.toDouble());

      // 计算 center-crop 源矩形（对齐目标比例后居中裁剪，横/竖图均不留两侧空白）
      final srcW = srcImage.width.toDouble();
      final srcH = srcImage.height.toDouble();
      const dstAspect = cardW / photoH; // 1080 / 980
      final srcAspect = srcW / srcH;
      final srcRect = srcAspect > dstAspect
          ? ui.Rect.fromLTWH(
              (srcW - srcH * dstAspect) / 2, 0,
              srcH * dstAspect, srcH)
          : ui.Rect.fromLTWH(
              0, (srcH - srcW / dstAspect) / 2,
              srcW, srcW / dstAspect);

      // 4. 绘制
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // 背景
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, cardW.toDouble(), cardH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1C1A17),
      );

      // 顶部标题
      final titlePainter = TextPainter(textDirection: ui.TextDirection.ltr);
      titlePainter.text = const TextSpan(
        text: 'EXIF',
        style: TextStyle(
          color: ui.Color(0xFFC9A96E),
          fontSize: 36,
          fontWeight: ui.FontWeight.w700,
        ),
      );
      titlePainter.layout();
      titlePainter.paint(canvas, ui.Offset(padding.toDouble(), 32));

      // 照片（center-crop 铺满）
      canvas.drawImageRect(
        srcImage,
        srcRect,
        photoRect,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      srcImage.dispose();

      // 5. 参数区：两列网格（label 上 / value 下，紧凑排布）
      const labelStyle = TextStyle(
        color: ui.Color(0xFFC9A96E),
        fontSize: 20,
        fontWeight: ui.FontWeight.w600,
      );
      const valueStyle = TextStyle(
        color: ui.Color(0xFFE5E0D8),
        fontSize: 22,
      );

      // Dart 2.19 不支持 records，用 MapEntry 承载 label/value
      final items = <MapEntry<String, String>>[
        MapEntry('相机', exif.cameraModel ?? ''),
        MapEntry('焦距', exif.focalLength ?? ''),
        MapEntry('光圈', exif.fNumber ?? ''),
        MapEntry('ISO', exif.iso ?? ''),
        MapEntry('快门', exif.shutterSpeed ?? ''),
        MapEntry('时间', exif.timestamp ?? ''),
        MapEntry('场景', exif.sceneName ?? ''),
        MapEntry('模板', exif.template ?? ''),
      ].where((it) => it.value.isNotEmpty).toList();

      const gap = 32;
      final colW = (cardW - padding * 2 - gap) / 2;
      const rowH = 70;
      final gridTop = photoTop + photoH + 48;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final col = i % 2;
        final row = i ~/ 2;
        final x = padding + col * (colW + gap);
        final y = gridTop + row * rowH;

        final labelTp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(text: item.key, style: labelStyle);
        labelTp.layout(maxWidth: colW);
        labelTp.paint(canvas, ui.Offset(x, y));

        final valueTp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(text: item.value, style: valueStyle);
        valueTp.layout(maxWidth: colW);
        valueTp.paint(canvas, ui.Offset(x, y + 30));
      }

      // 6. 底部水印
      final watermark = TextPainter(textDirection: ui.TextDirection.ltr)
        ..text = const TextSpan(
          text: 'Lumira · 摄影学院',
          style: TextStyle(
            color: ui.Color(0xFFC9A96E),
            fontSize: 18,
            fontStyle: ui.FontStyle.italic,
          ),
        );
      watermark.layout();
      watermark.paint(canvas,
          ui.Offset((cardW - watermark.width) / 2, cardH - 50));

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(cardW, cardH);
      picture.dispose();

      // 编码 PNG 并保存
      try {
        final pngBytes =
            await resultImage.toByteData(format: ui.ImageByteFormat.png);
        if (pngBytes == null) {
          throw StateError('toByteData(png) 返回 null');
        }
        await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      } finally {
        resultImage.dispose();
      }

      debugPrint('[exif-card] 生成: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[exif-card] 失败: $e\n$st');
      rethrow;
    }
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run:
```powershell
flutter test test/exif_card_generator_test.dart
```
Expected: PASS（尺寸 1080×1620、照片区中间与左边缘均为红色、标题区背景深色）。

- [ ] **Step 5: 手测**

运行 App → 拍摄 → 生成 EXIF 卡片 → 分享/保存：海报照片铺满顶部，参数两列紧凑，水印在底部。

- [ ] **Step 6: 提交并推送双远程**

```powershell
git add lumira_app_flutter/lib/features/capture/services/exif_card_generator.dart lumira_app_flutter/test/exif_card_generator_test.dart
git commit -m "feat(exif-card): 照片 center-crop 铺满顶部 + 参数两列网格"
git push origin master
git push github master
```

---

## 验证策略汇总

- 后端：`pnpm exec jest --config ./test/jest-e2e.json --runInBand points` → share 首享 granted:true 余额 +2；当日重复 granted:false。
- Flutter 单测：`flutter test test/`（template_share_code / share_reporter / deep_link_service / exif_card_generator + 既有 template_import、template_mapper、template_exporter 不回归）。
- 手测：Android 深链唤起导入；OHOS 深链（受限则验证粘贴导入）；分享一次后钱包积分 +2；EXIF 海报视觉验收。
- 全程 `flutter analyze` 无新增 error。

## 非目标（YAGNI）

- 不做微信等国内平台 SDK 直发分享。
- 不做分享成功与否的精确确认（系统分享面板无法回传）。
- 不做分享次数成就（1/3/5/10/20 分享）真实计数（当前 mock，不在本次范围）。
- 不新增 iOS 平台（项目无 iOS 目录）。
