# 反馈建议功能设计（Feedback）

日期：2026-08-18
状态：设计稿（待评审）

## 1. 背景与目标

当前用户在 App 使用中遇到不便、发现问题、或希望开发者新增某些功能 / 模板 / 场景时，缺少一个正式、可达的反馈渠道。「关于如画」页目前只有占位邮箱，无实际提交路径，开发者也无法集中收集与追踪反馈。

本设计为 App 增加**意见反馈**能力：用户可通过 App 内表单直接提交反馈（类型 + 正文 + 联系方式 + 0~3 张截图），同时可在注册位置通过**邮箱 / 微信号**二次联系开发者；开发者通过**后台「反馈管理」页**查看、筛选、标记已处理。

### 成功标准
- 用户能在 App 内以不超过 3 处可见入口触达反馈，提交后收到明确成功提示。
- 反馈（含截图）落库，开发者可在后台集中查看并按类型 / 状态 / 时间 / 关键词筛选，单条可标记「已处理」。
- 联系开发者信息（真实邮箱 + 微信号）在「关于如画」页展示，支持一键复制 / 拉起邮件。

## 2. 范围

本次横跨三端，按端切分为独立子阶段，但属于同一功能、共用一份设计：

| 端 | 交付物 |
|---|---|
| 后端 NestJS | `feedbacks` 表 + `feedback` 模块（App 提交 / Admin 列表 / Admin 标记处理）|
| 后台 Next.js | 「反馈管理」页（列表 + 详情 + 标记已处理）|
| 客户端 Flutter | 反馈表单页 + 三处入口 + 联系方式展示改造 + `ApiClient` multipart 支持 |

### 明确不做（YAGNI）
- 不做「管理员在后台一键回复 / 邮件发送」
- 不做反馈的公开展示 / 用户侧反馈列表回顾
- 不做后台的反馈删除 / 多选批量处理（首期仅单条标记状态）

## 3. 核心决策

### 3.1 截图上传：提交接口直接接收 multipart（方案 A，已确认）
`POST /api/v1/feedback` 一次请求携带：
- 文本字段：`type`、`content`、`contact`（可选）
- 文件字段：`screenshots`（0~3 张，multipart）

后端用现有 `@fastify/multipart` 解析，保存到
`{UPLOAD_DIR}/feedback/{feedbackId}/shot-{i}.{ext}`，并经现有 `buildPublicUrl` 逻辑生成
`{BACKEND_PUBLIC_URL}/uploads/feedback/{id}/shot-{i}.{ext}` 公网 URL，写入 `screenshots_json`。

理由：与后台模板封面上传同一套基建；一个请求原子提交，无孤儿文件；客户端只需一次上传交互。

## 4. 后端设计（lumira-server/packages/backend）

### 4.1 数据表 `feedbacks`（迁移 `src/database/migrations/010_feedback.sql`）

```sql
CREATE TABLE `feedbacks` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `device_id` TEXT NOT NULL,
  `type` TEXT NOT NULL,               -- bug|inconvenience|feature|template|scene|other
  `content` TEXT NOT NULL,
  `contact` TEXT,                     -- 选填，邮箱或微信号（自由文本）
  `status` TEXT NOT NULL DEFAULT 'pending',  -- pending|handled
  `screenshots_json` TEXT NOT NULL DEFAULT '[]', -- 格式 ["https://.../shot-0.jpg", ...]
  `client_ip` TEXT,
  `created_at` INT NOT NULL
);
CREATE INDEX `idx_feedbacks_created` ON `feedbacks` (`created_at`);
```

`schema.ts` 新增 `feedbacks` 表定义，与现有表保持一致写法。

### 4.2 模块 `modules/feedback/`
参照 `questionnaire` 模块的目录结构：

```
modules/feedback/
├── dto/
│   └── create-feedback.dto.ts      # type(content 校验) + content + contact（可选）
├── feedback.controller.ts
├── feedback.module.ts
└── feedback.service.ts
```

`@fastify/multipart` 的处理：由于该请求同时含字段与文件，Controller 中在 `DeviceAuthGuard` 下用 `@Req()` 读取 `request.file()`/`request.files()`（与 admin-templates 上传一致），DTO 用于字段校验。`content` 必填、`type` 限定枚举、`contact` 选填限长。

### 4.3 接口

| Method | Path | Guard | 说明 |
|---|---|---|---|
| POST | `/api/v1/feedback` | DeviceAuthGuard | 提交反馈（multipart，字段 + 0~3 截图）|
| GET | `/api/v1/admin/feedbacks` | AdminAuthGuard | 列表，支持 `type`/`status`/`page` 筛选 |
| PATCH | `/api/v1/admin/feedbacks/:id` | AdminAuthGuard | 标记状态 `handled`/`pending` |

返回结构保持后端惯例：成功 `{ success: true, id, receivedAt }`；Admin 列表 `{ list, total }`（分页字段与现有后台接口一致）。

`app.module.ts` 注册 `FeedbackModule`；`FeedbackModule` 依赖 `DatabaseModule`、`JwtModule`。

> 说明：截图上传的 Admin 鉴权沿用现有后台模式；App 提交走 `DeviceAuthGuard`。multipart 依赖 `@fastify/multipart` 已在 `main.ts` 全局注册，无需额外配置。

## 5. 后台设计（lumira-server/packages/admin）

新增「反馈管理」页，接入后台现有布局与路由（参照 category-manager 的页面/路由接入方式）：

- **入口**：后台侧边栏新增「反馈管理」项。
- **列表页**：表格列 = 反馈类型（badge）、正文（截断）、联系方式、状态（未处理/已处理 标签）、提交时间、操作。
- **筛选**：顶部按类型、状态筛选；列表按时间倒序，分页。
- **详情抽屉 / 弹窗**：查看完整正文、0~3 张截图（可点击放大）、设备、IP、联系方式。
- **操作**：单条「标记已处理 / 恢复未处理」。

数据来自 `GET/PATCH /api/v1/admin/feedbacks`；截图 URL 为后端绝对 URL，需要走后端代理（参照 `asset-url.ts` 的相对化逻辑，避免 Mixed Content）。

## 6. 客户端设计（lumira_app_flutter）

### 6.1 新目录 `features/profile/feedback/`
```
features/profile/feedback/
├── data/
│   └── feedback_repository.dart     # submit(类型/正文/联系方式/截图文件) → ApiClient.multipartPost
└── pages/
    └── feedback_page.dart           # 表单页
```

复用现有模式：repository + `FutureProvider`/`AsyncNotifier` 管理提交态，`file_picker_service` 选图。

### 6.2 `feedback_page.dart` 表单页
- 顶栏 `LumiraNav(title: '意见反馈')` + 返回键。
- **类型单选**：使用不便 / 漏洞Bug / 功能建议 / 模板建议 / 场景建议 / 其他（pill/chip 单选，符合现有 pill 风格，使用主题色）。
- **正文**：多行 `LumiraTextField`（必填，限长如 1000 字，含字数提示）。
- **联系方式**：单行输入（选填，占位「邮箱或微信号，便于我们联系你」）。
- **截图**：0~3 张，逐个缩略图 + 删除按钮 + 添加按钮（已达上限置灰）；入口复用 `file_picker_service`，仅图片。
- **提交**：主按钮（loading 态禁用）；前端校验（类型必选、正文非空）。成功后返回上一页并 `LumiraToast` 提示「已收到你的反馈，感谢！」，失败时 `LumiraToast` 或错误横幅展示原因。

### 6.3 `ApiClient` 增加 multipart 支持
新增 `multipartPost`（用 `dio.FormData` + `MultipartFile`），携带文本字段与截图文件，其余鉴权拦截器逻辑复用。

### 6.4 三处入口 + 联系方式
1. **个人中心主页**（`profile_page.dart`）：新增醒目「意见反馈」卡片 / 入口。
2. **设置页「关于」分组**（`profile_settings_page.dart`）：在「关于如画」上方新增「意见反馈」项，点击进 `feedback_page`。
3. **关于如画页**（`profile_about_page.dart`）：
   - 「联系我们」区更新为真实信息：官方邮箱 `15575712021@163.com`、微信号 `h15575712021`，支持一键复制（复制微信号/邮箱）与 `mailto:` 拉起邮件。
   - 新增「去反馈」按钮 → `feedback_page`。

路由：`RouteNames.feedback = '/profile/feedback'`，在 `router.dart` 注册；`route_names.dart` 新增常量。

## 7. 数据流

```
用户 → feedback_page.dart
   │ 填类型/正文/联系方式 + 选 0~3 图
   ▼
FeedbackRepository.submit()
   │ ApiClient.multipartPost('POST /api/v1/feedback')
   ▼
后端 FeedbackController(DeviceAuthGuard)
   │ multipart 解析 → FeedbackService
   │   1) 落库 feedbacks（device_id, type, content, contact, status=pending, created_at, client_ip）
   │   2) 保存截图 → uploads/feedback/{id}/shot-{i}.{ext}
   │   3) 生成公网 URL → 回填 screenshots_json
   ▼
返回 { success, id, receivedAt } → App toast 成功
后台 反馈管理页 ← GET /api/v1/admin/feedbacks（列表+详情）
   │ 查看正文/截图/设备/联系方式
   ▼ PATCH /api/v1/admin/feedbacks/:id
标记已处理
```

## 8. 错误处理与边界

- **正文必填**：前端 + 后端 DTO 双重校验，空正文阻止提交并提示。
- **截图数量/类型**：最多 3 张；后端校验单文件类型（jpg/png/webp 等）与大小（沿用现有 `fileSize` 25MB 上限），超限返回可读错误。
- **截图失败**：save 阶段出错整体返回失败（方案 A 原子性，不留孤儿）。
- **联系方式**：不强制，格式不强校验（自由文本），避免误拦自定义格式。
- **未授权**：App 无设备 JWT 时提交返回 401，App 按现有 `classifyDioError` 处理。
- **管理端**：标记已处理对不存在 id 返回 404；列表空数据显示空态。

## 9. 测试

- 后端（backend-ci）：为 `POST /api/v1/feedback`（含截图上传）、Admin 列表 / 标记接口补充 e2e / controller 级测试。
- Flutter：`flutter analyze` 通过；提交表单的服务层单测（mock ApiClient）。
- 后台：构建校验通过（沿用 admin-deploy 流程）。

## 10. 部署与配置

- **迁移执行机制（已确认）**：后端 `DatabaseService.onModuleInit → runMigrations()` 在**启动时自动执行**未应用的 SQL，`_migrations` 表记录已执行文件名保证幂等。因此将 `010_feedback.sql` 放入 `src/database/migrations/` 即可随部署自动建表，无需 CI 额外步骤。
- 截图 URL 依赖 `BACKEND_PUBLIC_URL`（已配置为 `https://lumira.iwtle.top`），与模板图片一致；后台查看走 `/uploads/*` 代理（Mixed Content）。
- `AGENTS.md` 规则：后端 / 后台改造完成后需 commit 并 push 到 `origin`(gitee) 与 `github` 两个远程。

## 11. 范围裁定（评审确认）
- 迁移 `010_feedback.sql`：随后端启动自动执行（已确认，见 §10）。
- 后台侧边栏 / 首页**不做**未读角标计数，首期仅提供列表页入口，避免扩大工作量。