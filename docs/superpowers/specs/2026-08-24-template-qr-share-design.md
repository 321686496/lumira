# 自定义模板「二维码分享与导入」— 设计文档

日期：2026-08-24
范围：
- `lumira-server/packages/backend/`（NestJS + Drizzle + MySQL + Redis）
- `lumira_app_flutter/`（Flutter 客户端）
- 涉及合规文档（用户协议 / 隐私政策）已同期更新条款

## 1. 目标

为自定义模板新增「二维码分享 / 导入」能力，满足：

1. 分享方可将自定义模板通过二维码分享到社交平台，其他用户扫码导入本地。
2. 分享方可在分享时设置有效期，**服务端硬性上限 12 小时**。
3. 有效期内**允许多次导入**，过期自动失效。
4. 封面、剪影等图片随模板上传，**每张 ≤1MB，上传前压缩但不过度损失画质**。
5. 接收端支持**真机相机扫码**，并保留**手动输码/输链接**兜底。
6. **保证服务器性能**：短命低频数据，选用 Redis 原生 TTL 存储，到期自动清除，无表堆积、无定时清扫。

## 2. 总体架构与数据流

选择 **Redis 原生 TTL 存储**，而非 MySQL 临时表 + 定时清理。

- 共享数据是短命、低频、读多的一次性内容。
- Redis `SETEX` 写入后由 Redis 自行过期删除，读取 O(1)，无需建表、不用 cron 清扫、不造成表体积增长 → 符合「保证服务器性能」。
- 不持久化到 MySQL，因此**无需新增 Drizzle 表 / 迁移**。

```
分享方 App ──POST /templates/share {payload, expiresInSeconds}──▶ 后端
后端：校验 TTL/尺寸/格式 → Redis SETEX lumira:share:{token} (EX=ttl) → 返回 {token, expiresAt}
分享方 App：qr_flutter 生成二维码（内容 lumira://imp/{token}）

接收方 App：qr_code_scanner 相机扫码 → 识别 token → GET /templates/share/:token
后端：Redis GET → 命中返回 {payload, expiresAt}；缺省/过期 → 404
接收方 App：TemplateImportService.importJson 落库
```

## 3. 二维码内容（token 语义）

二维码文本为深链 `lumira://imp/{token}`（与现有 `lumira://tpl/{base64}` 并存）。

- `token` 来自后端 `crypto.randomBytes(16).toString('base64url')`（约 22 字符，不可猜测，充当访问密钥）。
- 识别规则（接收端）：
  - `lumira://imp/{token}` 或 `https://lumira.app/imp/{token}` → token 型，走后端 GET。
  - `lumira://tpl/{base64}` 或 `https://lumira.app/tpl?...` → 现有离线型，保持原逻辑。
  - 其余 → 提示无效 / 转手动输入。

## 4. 后端改动

### 4.1 存储（无新表）
- Key：`lumira:share:{token}`
- Value：`.pptpl` 模板 JSON 字符串
- TTL：由分享方指定，范围 `[60, 43200]` 秒（**服务端硬上限 12h**）
- 附加字段：`ownerDeviceId`（存于同一 JSON 或前缀元数据，用于撤回鉴权）、`expiresAt`（unix 秒，随响应返回）

### 4.2 接口（均挂 `DeviceAuthGuard`，路径前缀 `/api/v1/templates`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/templates/share` | body `{ payload, expiresInSeconds }` → `{ token, expiresAt }` |
| GET | `/templates/share/:token` | → `{ payload, expiresAt }`；过期/不存在 404 |
| DELETE | `/templates/share/:token` | 仅创建者可撤回；成功后删除 Redis key |

### 4.3 校验（POST）
- `expiresInSeconds`：整数，且在 `[60, 43200]`，否则 400。
- `payload`：字符串，总大小 ≤ 3MB（超限 413/400）。
- `payload` 格式：可 `JSON.parse` 且含非空 `format` 与 `meta`，否则 400。
- 写入用当前设备 id 作为 `ownerDeviceId`。

### 4.4 防滥用 / 性能
- 两端均挂 `DeviceAuthGuard`（需先注册设备，有合法 token）挡匿名爬取。
- GET 加轻量单设备限速：Redis `INCR` 计数 + EX，如 **30 次/分钟/设备**，超限 429。
- 尺寸封顶（3MB）与图片 1MB 上限，保证单次传输与存储有界。

### 4.5 新增文件
- `backend/src/modules/templates/share-templates.controller.ts`
- `backend/src/modules/templates/share-templates.service.ts`
- `backend/src/modules/templates/share-templates.module.ts`（或在 `templates.module.ts` 内注册 controller/provider）
- 注入 `RedisService` 与 `DatabaseService` 无需（不查库）；如需 deviceId 从 guard 装饰器取。

## 5. Flutter 端改动

### 5.1 分享方（发送）
新增 `lib/features/templates/services/template_share_service.dart`：
- `buildSharePayload(TemplateRecord)`：复用 `TemplateExporter.exportToPptpl`（含 meta/composition/pose/sceneGuide/camera/postProcess 六段），把封面 + 剪影嵌入为 base64 data URL；用 `image: ^4.0.16` 对超 1MB 的图片做**压缩/缩放至 ≤1MB，不过度压画质**。
- `uploadShare(TemplateRecord, Duration expiresIn)`：POST `/templates/share`，返回 `ShareToken { token, expiresAt }`。
- 模型：`ShareToken`、有效期枚举常量。

UI（`export_detail_page.dart`）：
- 新增按钮「生成分享二维码」。
- 点击弹有效期选择 BottomSheet：**15 分钟 / 1 小时 / 6 小时 / 12 小时**。
- 确认后 `uploadShare` → `qr_flutter`（`QrImage`）展示二维码 + 复制链接，并显示到期时间与「已分享，扫码即可导入」提示。

### 5.2 接收方（导入）
改造 `lib/features/templates/widgets/template_import_sheet.dart` 的「扫码导入」：
- 主路径：`qr_code_scanner` `QRView` 真机相机扫码。
- 兜底：保留手动输入分享码/链接对话框。
- `parseScannedText(String)`：识别 `lumira://imp/...` / `https://lumira.app/imp/...` → 取 token → `TemplateShareService.fetchShare(token)` GET → 得 payload → `TemplateImportService.importJson` 落库；识别 `lumira://tpl/...` 走现有离线解析；其余提示重试/转手动。

### 5.3 网络
- 复用现有 `ApiClient.get/post`，`auth_interceptor` 自动附 Bearer token（`/device/register` 除外）。
- 若未注册设备（无 token），先触发设备注册（复用 `AuthController`）。

## 6. 与合规条款对齐

本实现兑现用户协议 / 隐私政策（`compliance_content.dart` 已更新）已承诺事项：

- **临时存储**：仅发送端主动「二维码分享」且需中转时上传。
- **短时效**：有效期硬上限 12h，过期自动清除。
- **可撤回 / 删除**：`DELETE /templates/share/:token` 由创建者随时撤回。
- **内容安全 / 处置能力**：后端具备按 token 定向删除能力；二维码分享的内容不公开展示。

## 7. 明确不做（本期 YAGNI）

- 不做「公开展示 / 去中心化列表 / 搜索」——分享仅凭 token 定向获取。
- 不做 MySQL 持久化与历史记录——共享数据仅 Redis 短效存储。
- 不做一次性消费（本期为「有效期内多次导入」）。
- 不改动 uni-app 原型（`lumira-app/`）。
- 不上传图片为独立文件——以 base64 内嵌在 payload 中（服务端无需持久化文件）。

## 8. 测试计划

- 后端 e2e / 单测（share-templates.service）：
  - 创建 → 读取往返一致。
  - 过期 → 404（可用极短 TTL + 等待或模拟）。
  - 尺寸超限 / 非法 `expiresInSeconds`（>43200、非整数）→ 400。
  - 撤销：创建者可 DELETE，非创建者 403/404；删除后再 GET → 404。
  - 限速：同一设备超频读取 → 429。
- Flutter：
  - `template_share_service_test.dart`：payload 构建（含图片压缩后 ≤1MB）、扫描文本解析、`uploadShare` 与 `fetchShare`（mock ApiClient）。
  - 更新 `template_import_sheet` 相关测试以覆盖扫码识别分支。
  - 运行 `flutter analyze` 与相关 `flutter test`。