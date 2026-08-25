# 自定义模板「二维码分享与导入」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户可将自定义模板通过二维码分享（有效期≤12h，含封面/剪影、每张≤1MB），接收方扫码或输码后导入本地。

**Architecture:** 后端用 Redis 原生 TTL 存共享模板 payload（`SETEX`，到期自动清除，O(1)），无需新表/清扫；前端分享方用 qr_flutter 生成 `lumira://imp/{token}` 二维码，接收方用 qr_code_scanner 相机扫码后向后端拉取并走现有本地导入管线。设计详见 `docs/superpowers/specs/2026-08-24-template-qr-share-design.md`。

**Tech Stack:** NestJS + Fastify + Drizzle + MySQL + Redis(ioredis) + class-validator；Flutter 3.7.12/Dart 2.19.6 + Riverpod + Dio + qr_flutter + qr_code_scanner + image 4.x。

## Global Constraints
- Dart 必须兼容 2.19.6，**禁用 Dart 3 records 语法**。
- 后端全局路径前缀 `/api/v1`；模板接口在 `@Controller('templates')` 下。
- 两端新接口均需通过 `DeviceAuthGuard`（`@DeviceId()` 取设备 id）。
- 二维码内容：`lumira://imp/{token}`；兼容解析 `https://lumira.app/imp/{token}`。
- 有效期硬上限 `43200` 秒；下限 `60` 秒；payload 总大小 ≤3MB。
- 图片（封面/剪影）内嵌 base64，**每张 ≤1MB**，压缩时不可过度损失画质。
- 共享数据仅放 Redis，**不写 MySQL，不新增 Drizzle 表**。
- 参考既有实现：后端 `templates.controller.ts` / `templates.module.ts` / `ExchangeTemplateDto` / `RedisService`；前端 `template_export_service.dart` / `template_import_service.dart` / `export_detail_page.dart` / `TemplateImportSheet` / `ApiClient`。
- 完成后后端改动需 commit + push 到 `origin`(gitee) 与 `github` 两个远程 master。

---

### Task 1: 后端 — 分享 DTO 与 service（创建/读取/撤回/校验/限速）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/templates/dto/share-template.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/templates/share-templates.service.ts`

**Interfaces:**
- `class ShareTemplateDto { payload: string; expiresInSeconds: number }` （`payload` 为 JSON 字符串；`expiresInSeconds` 为正整数）
- `ShareTemplatesService.create(payload, expiresInSeconds, ownerDeviceId): Promise<{token, expiresAt}>`
- `ShareTemplatesService.get(token): Promise<{payload, expiresAt}>`（缺省/过期返回 `null`）
- `ShareTemplatesService.revoke(token, deviceId): Promise<boolean>`（非 owner 抛 `ForbiddenException`）
- 常量 `SHARE_KEY_PREFIX = 'lumira:share:'`、`MAX_TTL = 43200`、`MIN_TTL = 60`、`MAX_PAYLOAD_BYTES = 3*1024*1024`、`GET_RATE_LIMIT = 30`、`RATE_WINDOW = 60`

参考 `templates.service.ts` 的注入风格：注 `RedisService`。设 `templates.handler.ts` 无，直接在此 service 内实现。

- [ ] **Step 1: 写失败的 e2e 测试骨架引用文件**

新建 `test/share-templates.e2e-spec.ts`（本 Task 仅建占位，Task 4 写断言）。此处先仅创建文件占位，具体断言在 Task 4 补全后才会通过。

- [ ] **Step 2: 写 DTO**

`share-template.dto.ts`（镜像 `ExchangeTemplateDto` 风格）：

```ts
import { IsInt, IsString } from 'class-validator';

export class ShareTemplateDto {
  @IsString()
  payload!: string;

  @IsInt()
  expiresInSeconds!: number;
}
```

- [ ] **Step 3: 写 service**

`share-templates.service.ts`：

```ts
import { ForbiddenException, Injectable } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { RedisService } from '../../common/redis/redis.service';

export const SHARE_KEY_PREFIX = 'lumira:share:';
export const MAX_TTL = 43200;
export const MIN_TTL = 60;
export const MAX_PAYLOAD_BYTES = 3 * 1024 * 1024;
export const GET_RATE_LIMIT = 30;
export const RATE_WINDOW = 60; // 秒

interface ShareRecord {
  payload: string;
  expiresAt: number;
  ownerDeviceId: string;
}

@Injectable()
export class ShareTemplatesService {
  constructor(private readonly redis: RedisService) {}

  private key(token: string): string {
    return SHARE_KEY_PREFIX + token;
  }

  async create(
    payload: string,
    expiresInSeconds: number,
    ownerDeviceId: string,
  ): Promise<{ token: string; expiresAt: number }> {
    if (!payload || payload.length === 0) {
      throw new Error('empty_payload');
    }
    const bytes = Buffer.byteLength(payload, 'utf8');
    if (bytes > MAX_PAYLOAD_BYTES) {
      throw new Error('payload_too_large');
    }
    if (!Number.isInteger(expiresInSeconds)) {
      throw new Error('invalid_ttl');
    }
    if (expiresInSeconds < MIN_TTL || expiresInSeconds > MAX_TTL) {
      throw new Error('invalid_ttl');
    }
    const token = randomBytes(16).toString('base64url');
    const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const record: ShareRecord = { payload, expiresAt, ownerDeviceId };
    await this.redis.setJson<ShareRecord>(this.key(token), record, expiresInSeconds);
    return { token, expiresAt };
  }

  async get(
    token: string,
  ): Promise<{ payload: string; expiresAt: number } | null> {
    if (!token) return null;
    const record = await this.redis.getJson<ShareRecord>(this.key(token));
    if (!record) return null;
    return { payload: record.payload, expiresAt: record.expiresAt };
  }

  async revoke(token: string, deviceId: string): Promise<boolean> {
    if (!/^[A-Za-z0-9_-]{10,64}$/.test(token)) return false;
    const record = await this.redis.getJson<ShareRecord>(this.key(token));
    if (!record) return false;
    if (record.ownerDeviceId !== deviceId) {
      throw new ForbiddenException('not_owner');
    }
    await this.redis.del(this.key(token));
    return true;
  }

  async checkRateLimit(deviceId: string): Promise<void> {
    const rk = `lumira:ratelimit:${deviceId}:shareGet`;
    const current = (await this.redis.getJson<number>(rk)) ?? 0;
    if (current >= GET_RATE_LIMIT) {
      throw new Error('rate_limited');
    }
    await this.redis.setJson<number>(rk, current + 1, RATE_WINDOW);
  }
}
```

- [ ] **Step 4: 类型检查**

Run: `pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit`（在 `lumira-server/` 根目录）。Expected: 通过。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/dto/share-template.dto.ts lumira-server/packages/backend/src/modules/templates/share-templates.service.ts
git commit -m "feat(backend): 自定义模板分享 service（TTL 存储/校验/限速）"
```

---

### Task 2: 后端 — 分享 controller 与模块注册

**Files:**
- Create: `lumira-server/packages/backend/src/modules/templates/share-templates.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/templates/share-templates.module.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.module.ts`

**Interfaces:**
- `POST /templates/share` body `ShareTemplateDto` → `200 {token, expiresAt}`
  - 业务错误映射：`empty_payload`/`payload_too_large`/`invalid_ttl` → `400`。
- `GET /templates/share/:token` → `200 {payload, expiresAt}`；命中 `rate_limited` → `429`；无记录 → `404`。
- `DELETE /templates/share/:token` → `200 {deleted:true}`；`ForbiddenException` → `403`；无记录 → `404`。

参考 `templates.controller.ts` 的装饰器与异常映射风格（业务错误统一转 HttpException）。

- [ ] **Step 1: 写 controller**

`share-templates.controller.ts`：

```ts
import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
  BadRequestException,
  TooManyRequestsException,
} from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';
import { ShareTemplateDto } from './dto/share-template.dto';
import { ShareTemplatesService, GET_RATE_LIMIT } from './share-templates.service';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class ShareTemplatesController {
  constructor(private readonly shares: ShareTemplatesService) {}

  @Post('share')
  async create(@Body() dto: ShareTemplateDto, @DeviceId() deviceId: string) {
    try {
      return await this.shares.create(dto.payload, dto.expiresInSeconds, deviceId);
    } catch (err) {
      const message = (err as Error).message;
      if (message === 'empty_payload' || message === 'payload_too_large' || message === 'invalid_ttl') {
        throw new BadRequestException(message);
      }
      throw err;
    }
  }

  @Get('share/:token')
  async read(@Param('token') token: string, @DeviceId() deviceId: string) {
    try {
      await this.shares.checkRateLimit(deviceId);
    } catch (err) {
      if ((err as Error).message === 'rate_limited') {
        throw new TooManyRequestsException(`limit_${GET_RATE_LIMIT}_per_minute`);
      }
      throw err;
    }
    const found = await this.shares.get(token);
    if (!found) throw new NotFoundException('share_not_found_or_expired');
    return found;
  }

  @Delete('share/:token')
  async revoke(@Param('token') token: string, @DeviceId() deviceId: string) {
    const deleted = await this.shares.revoke(token, deviceId);
    if (!deleted) throw new NotFoundException('share_not_found_or_expired');
    return { deleted: true };
  }
}
```

- [ ] **Step 2: 写 module 并在 templates.module 注册**

`share-templates.module.ts`：
```ts
import { Module } from '@nestjs/common';
import { ShareTemplatesController } from './share-templates.controller';
import { ShareTemplatesService } from './share-templates.service';

@Module({
  controllers: [ShareTemplatesController],
  providers: [ShareTemplatesService],
})
export class ShareTemplatesModule {}
```

修改 `templates.module.ts`：把 `ShareTemplatesModule`、`ShareTemplatesController`、`ShareTemplatesService` 加入对应 `imports`/`controllers`/`providers`（遵循该模块现有对 `JwtModule`/`RedisService` 的注入方式，`RedisService` 已在全局 provider 提供，无需重复 import RedisModule）。

- [ ] **Step 3: typecheck**

Run: `pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit`。Expected: 通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/share-templates.controller.ts lumira-server/packages/backend/src/modules/templates/share-templates.module.ts lumira-server/packages/backend/src/modules/templates/templates.module.ts
git commit -m "feat(backend): 模板分享 controller 与模块注册（POST/GET/DELETE + 限速）"
```

---

### Task 3: 后端 — share e2e 测试

**Files:**
- Create: `lumira-server/packages/backend/test/share-templates.e2e-spec.ts`

测试用 supertest；**Step 1 先建立本 Task，替换 Task 1 的占位文件**。镜像 `test/templates.e2e-spec.ts` 的 app 启动/设备注册流程（`beforeAll` 注册一台设备拿 `deviceToken` 与 `deviceId`，`afterAll` close app）。断言之 Redis 依赖真实 Redis。

- [ ] **Step 1: 写 e2e spec**

构造完整 json payload 样例：
```ts
const payload = JSON.stringify({ format: 'lumira-pptpl', meta: { name: '测试模板' }, composition: {}, pose: {}, sceneGuide: {}, camera: {}, postProcess: {} });
```
示例断言要点：
- POST `/api/v1/templates/share` 带 `deviceToken`+ body `{payload, expiresInSeconds: 3600}` → 201/200 且返回 `token`、`expiresAt`。
- GET 用返回 token → 200 且 `payload` 与上传一致。
- POST `expiresInSeconds: 999999`（>43200）→ 400。
- POST 超大 payload（>3MB，可用 `'a'.repeat(3*1024*1024+1)`）→ 400。
- GET 随机不存在 token → 404。
- DELETE：创建者 token → 200；再用原 token GET → 404；非创建者模拟另一设备 DELETE → 403。
- 限速：循环 31 次 GET 同设备 → 第 31 次 429（若环境不便，可把 `GET_RATE_LIMIT` 暂时调小或跳过此项，注明跳过原因）。

（若仓库 unit 测试框架也跑 Redis 相关，按需在 `test/templates.e2e-spec.ts` 同目录沿用其 helper。）

- [ ] **Step 2: 运行仅在需要 Redis 环境时**

Run: `pnpm --filter @lumira/backend test:e2e -- --runInBand test/share-templates.e2e-spec.ts`（在 `lumira-server/` 根）。若本地无 Redis（`REDIS_URL` 空）导致降级为 null 缓存，则共享逻辑会 404/找不到——此时需用真实 Redis 或标注测试依赖。Expected: 通过或明确记录环境依赖。

- [ ] **Step 3: Commit**

```bash
git add lumira-server/packages/backend/test/share-templates.e2e-spec.ts
git commit -m "test(backend): 模板分享 e2e 用例"
```

---

### Task 4: Flutter — ApiClient.delete、分享模型与 TemplateShareService

**Files:**
- Modify: `lumira_app_flutter/lib/core/network/api_client.dart`
- Create: `lumira_app_flutter/lib/features/templates/models/share_token.dart`
- Create: `lumira_app_flutter/lib/features/templates/services/template_share_service.dart`

**Interfaces:**
- `ApiClient.delete<T>(String path, {required T Function(Object? json) fromJson})`（镜像 `get`/`post` 实现，`_dio.delete`）
- `class ShareToken { final String token; final int expiresAt; }` + `fromJson`
- `TemplateShareService.instance` 或 Riverpod provider；方法：
  - `Future<ShareToken> shareTemplate(TemplateRecord record, int expiresInSeconds)`
  - `Future<Map<String, dynamic>> fetchShare(String token)`（GET，返回 `{payload, expiresAt}`）
  - `Future<void> revokeShare(String token)`
  - `String buildQrText(String token) => 'lumira://imp/$token'`
  - `String? parseTokenFromScannedText(String text)`（识别 token 或 `lumira://tpl/{base64}` 离线路径→返回 null 表示离线处理）
  - `Future<Uint8List> compressImageToLimit(Uint8List bytes, int maxBytes)`（>1MB 时用 `package:image` 缩放/JPEG q85 压至 ≤maxBytes）

参考 `template_export_service.dart` 如何用 `ApiClient`（其 `apiClientProvider`）、如何触发设备注册（`AuthController` 内的注册方法，见 `main.dart` 的 `_collectDeviceInfo`/register 调用）。payload 复用 `TemplateExporter.exportToPptpl(record)`（含 meta/composition/pose/sceneGuide/camera/postProcess），并保证封面 `coverData` 与剪影已内嵌为 base64 data URL。

- [ ] **Step 1: 写失败单测**

Create `test/features/templates/template_share_service_test.dart`，先只断言 `parseTokenFromScannedText` 与 `compressImageToLimit`（<maxBytes 不压缩、>maxBytes 后 ≤maxBytes），mock `ApiClient` 测 `shareTemplate`/`fetchShare`。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/templates/template_share_service_test.dart`。Expected: FAIL（类不存在）。

- [ ] **Step 3: 实现 ApiClient.delete + 模型 + service**

补 `api_client.dart` `delete`；新建 `share_token.dart`；新建 `template_share_service.dart`（注入 `ApiClient`），其中 `compressImageToLimit` 用 `package:image`：
```dart
import 'package:image/image.dart' as img;
Future<Uint8List> compressImageToLimit(Uint8List bytes, int maxBytes) async {
  if (bytes.length <= maxBytes) return bytes;
  var image = img.decodeImage(bytes);
  if (image == null) return bytes;
  var q = 90; var out = bytes;
  while (out.length > maxBytes && q > 55) {
    out = Uint8List.fromList(img.encodeJpg(img.copyResize(image, width: (image.width * q / 100).round(), height: (image.height * q / 100).round()), quality: q));
    q -= 5; image = img.decodeImage(out) ?? image;
  }
  return out;
}
```
`sanitize` payload 时对 `coverData` 等每张 ≤ `1*1024*1024`。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/features/templates/template_share_service_test.dart` 且 `flutter analyze lib/features/templates/services/template_share_service.dart lib/features/templates/models/share_token.dart lib/core/network/api_client.dart`。Expected: PASS + 无告警。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/core/network/api_client.dart lumira_app_flutter/lib/features/templates/models/share_token.dart lumira_app_flutter/lib/features/templates/services/template_share_service.dart lumira_app_flutter/test/features/templates/template_share_service_test.dart
git commit -m "feat(app): 模板分享 service 与 ApiClient.delete"
```

---

### Task 5: Flutter — 分享方 UI（有效期选择 + 二维码展示）

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/export_detail_page.dart`

在导出详情页新增「生成分享二维码」入口。点击弹 BottomSheet 选有效期（`15分钟/1小时/6小时/12小时` → 对应秒 `900/3600/21600/43200`），确认后调 `shareTemplate`，成功后用 `qr_flutter` 的 `QrImage` 展示二维码（数据 `buildQrText(token)`），同时显示到期时间与「随时可撤回」按钮（调 `revokeShare`）。

遵循项目 UI 规范：组件用 `ref.watch(appThemeProvider)` + `NeuCard`/`LumiraButton`；不得硬编码主题色（详见 AGENTS.md Flutter UI 规范）。

- [ ] **Step 1: 先阅读现有导出详情页分享按钮结构**（`export_detail_page.dart` 中「分享/导出」动作区），确定插入点与复用组件。

- [ ] **Step 2: 新增分享二维码入口 + BottomSheet + 结果展示**

（实现时严格用当前主题组件；按钮按压反馈遵循现有 `breathing_tap` 规范。）核心流程代码示意：
```dart
final token = await ref.read(templateShareProvider.notifier)
    .shareTemplate(record, expiresInSeconds);
_showQrSheet(context, token, updatedAt: token.expiresAt);
```
`QrImage(data: TemplateShareService.instance.buildQrText(token), size: 240)`。

- [ ] **Step 3: 运行验证**

Run: `flutter analyze lib/features/templates/pages/export_detail_page.dart`；`flutter test test/features/profile/compliance_doc_page_test.dart`（回归）。Expected: PASS、无告警。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/export_detail_page.dart
git commit -m "feat(app): 导出详情页支持生成分享二维码"
```

---

### Task 6: Flutter — 接收方相机扫码 + 兜底输入

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`

将「扫码导入」升级：主路径 `qr_code_scanner` `QRView` 真机扫码；保留手动输入分享码/链接兜底；解析 `parseTokenFromScannedText`:
- `lumira://imp/{token}` / `https://lumira.app/imp/{token}` → 取 token → `fetchShare(token)` 得 payload（`map['payload']` 字符串 JSON）→ `TemplateImportService.importJson(payloadJSON)` 落库 → 成功 toast。
- `lumira://tpl/{base64}` / 现有离线 → 走原有离线解析。
- 其它 → 提示重试或转手动输入。

参考现有扫码用法：`recover_account_page.dart` 的 `QRView`（仅 Android/iOS，非支持平台引导手动输码）。扫描到后需在结果处理里先 `await storage` 关闭相机预览再导入。

- [ ] **Step 1: 写失败单测**（解析分支）

Create `test/features/templates/template_import_sheet_test.dart`（若已存在则补充），只断言 `parseScannedText` 的 token/离线/无效三分支（把解析逻辑抽为可测的 `TemplateShareService.parseTokenFromScannedText` 纯函数）。Run 确认失败。

- [ ] **Step 2: 实现扫码 + 兜底**

（遵循现有 `TemplateImportSheet` 的结构：读取 sheet 的按钮与输入框。）扫码结果处理：
```dart
final token = TemplateShareService.instance.parseTokenFromScannedText(text);
if (token != null) {
  final data = await TemplateShareService.instance.fetchShare(token);
  final payload = (data['payload'] as String?) ?? '';
  await TemplateImportService.instance.importJson(payload); // 见现有导入绑定
} else if (isOfflineTpl(text)) {
  // 复用现有离线解析
} else {
  showManualEntryFallback();
}
```

- [ ] **Step 3: 运行验证**

Run: `flutter analyze lib/features/templates/widgets/template_import_sheet.dart` 与对应单测。Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart lumira_app_flutter/test/features/templates/
git commit -m "feat(app): 扫码导入自定义模板 + 手动输入兜底"
```

---

### Task 7: 收尾 — 文档、回归、commit + push

**Files:**
- Modify: `docs/future-optimizations.md`（如适用，登记后续优化项）
- （设计文档/合规内容已在先期更新，无需改动）

- [ ] **Step 1: 全量回归**

后端：`pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit`；`pnpm --filter @lumira/backend test:e2e -- --runInBand`。
Flutter：`flutter analyze`；`flutter test`。
Expected: 全绿（e2e 若需真实 Redis，记录依赖）。

- [ ] **Step 2: 更新 future-optimizations（如需要）**

扫描是否有「当前先这样实现、后续再优化」的点（例如图片压缩策略、限速阈值），按文档格式追加。

- [ ] **Step 3: Commit + 推送后端改动**

`git add` 后端相关文件 + `docs/future-optimizations.md`；按 `AGENTS.md` 提交说明 commit；然后：
```bash
git push origin master
git push github master
```

- [ ] **Step 4: 汇报**

总结完成的功能点、测试结果、环境依赖（Redis）、以及已推送的远程。

## Self-Review（实施前由主 agent 对照 checklist 执行）
1. Spec 覆盖：POST/GET/DELETE、TTL≤43200、含封面/剪影且每图≤1MB、接收方相机扫码+输码兜底、Redis 保证性能、合规条款（临时存储/可撤回/过期清除）均已映射到 Task 1–7。
2. Placeholder 扫描：除 Task 1 明确标注、Task 4/6 引用既有文件需按现有实现对齐外，无 TBD；实现时若对接现有签名与计划不符，以仓库现存代码为准并在 commit message 说明。
3. 类型一致性：token 为 base64url string；`{payload, expiresAt}` 响应在前后端一致；`parseTokenFromScannedText`、`buildQrText`、`shareTemplate`、`fetchShare` 命名在各 Task 间一致。