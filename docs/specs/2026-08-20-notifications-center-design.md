# 通知中心优化设计（2026-08-20）

> 功能设计文档，存放于 `docs/specs/`。登记「后续优化」内容见 `docs/future-optimizations.md`。

## 1. 目标

将通知中心从「5 条 mock」改造为真实数据：**后端公告（后台可配置定向投放）+ 本地应用事件通知（真实本地数值）**。已读/清除/未读红点状态当前存本机（方案 C），后续迁移到数据库（已登记后续优化）。

## 2. 已确认决策

1. **本地通知来源**：应用事件自动生成，保留五类但用真实数值（连续打卡/模板更新/挑战提醒/成就解锁/系统通知）。
2. **定向维度**：全部设备 / 指定 deviceId / 指定手机型号 / App 版本 / 平台 / 邮箱 / 按用户属性筛选。
3. **触达方式**：站内通知中心拉取（不做 FCM/鸿蒙推送）。
4. **交互**：本地关联事件通知可点击跳转对应页；后端公告仅展示（不可跳转）；支持标记全部已读、单条删除、左滑/长按清除。
5. **读状态存储**：方案 C（后端只下发公告内容，已读/清除/红点存本机 sqflite）；后续迁移到后端数据库持久化（登记于 `docs/future-optimizations.md`）。
6. 既有功能文档与「后续优化」文档分离；后续“先实现再优化”内容统一登记到 `docs/future-optimizations.md`（AGENTS.md 已加规则）。

## 3. 整体架构与数据流

```
后台(Next.js 通知管理页) → AdminAuth 管理接口 → NestJS(notifications 表+定向匹配)
                                                            │ DeviceAuth：按设备信息+邮箱匹配
                                                            ▼
Flutter 通知中心 = 后端公告(拉取) ＋ 本地应用事件通知(生成)；已读/清除/红点存本机
```

- 首页铃铛图标展示未读红点（`home_page.dart`）。
- 打开通知中心：并行「拉取后端公告」+「生成本地应用事件通知」→ 合并 → 时间倒序 → 过滤已清除。

## 4. 后端设计

### 4.1 表 `notifications`

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | text PK | 业务 ID（`ntf-uuid`） |
| `title` / `body` | text | 标题 / 正文 |
| `iconKey` | text | 图标（system/version/announcement…） |
| `category` | text | 展示分组（system/announcement/version/activity） |
| `targetScope` | text | `all` / `devices` / `criteria` |
| `targetDeviceIdsJson` | text | scope=devices 时的 deviceId 列表 |
| `targetCriteriaJson` | text | scope=criteria 时的定向条件对象 |
| `startAt` / `endAt` | int | 投放窗口（毫秒时间戳，可空=长期） |
| `isActive` | int | 1 展示 0 停用 |
| `sortOrder` | int | 排序 |
| `createdAt` / `updatedAt` | int | 毫秒时间戳 |

`targetCriteriaJson` 结构（空数组=不限；支持 `*` 通配）：
```jsonc
{
  "platform": ["ios", "ohos"],
  "deviceModel": ["iPhone 15"],
  "osVersion": ["15.0"],
  "appVersion": ["1.2.0"],
  "email": ["a@x.com"],
  "region": [],
  "userIdList": []
}
```
> 「按用户属性筛选」落地为上述 criteria 定向条件；基于 `devices` 表字段，不接入积分/问卷等业务属性（避免范围膨胀），保留 `userIdList`/`region` 预留位。

### 4.2 接口

| 方法 | 路径 | 鉴权 |
|---|---|---|
| GET | `/api/v1/notifications` | DeviceAuthGuard |
| GET | `/api/v1/admin/notifications` | AdminAuthGuard（分页） |
| POST | `/api/v1/admin/notifications` | AdminAuthGuard |
| PATCH | `/api/v1/admin/notifications/:id` | AdminAuthGuard（含启停） |
| DELETE | `/api/v1/admin/notifications/:id` | AdminAuthGuard |

- 设备拉取：`notifications.service.ts` 拉启用的公告，用 deviceId 查 `devices`，逐条判定 scope/criteria/窗口命中。
- 后端发布时也可下发 `deviceId` 供手机端幂等 upsert。

### 4.3 改动文件

`020_notifications.sql`、`schema.ts`、`notifications.{module,service,controller}.ts`、admin 控制器（挂 AdminAuthGuard）。

## 5. Flutter 设计

### 5.1 本地应用事件通知（真实数据，key+日期去重）

| 类别 | key | 数据来源 | 条件 |
|---|---|---|---|
| 连续打卡 | streak | `user_progress.streak_days` | ≥2，含真实天数 |
| 模板更新 | template | `remote_templates` 最近更新 | 有新增模板时 |
| 挑战提醒 | challenge | 今日挑战未完成 | 存在且未完成 |
| 成就解锁 | achievement | `user_progress.achievements_json` 最新 | 有未读新成就 |
| 系统通知 | system | App 版本常量 | 静态 |

### 5.2 读状态表 `notifications`（sqflite，`_kDbVersion` 升到 32）

```
id TEXT PK  source TEXT('remote'|'local')  remoteId TEXT
kind TEXT  title TEXT  body TEXT  timeMs INTEGER
read INTEGER(0/1)  cleared INTEGER(0/1)
```
- 进页拉后端公告并 upsert；已读/清除为本地状态。
- 后端删/下架：以返回列表为准，清理本机已不在返回列表的 `remoteId`。

### 5.3 UI/交互

- 首页铃铛显示未读红点角标（接 provider）。
- 通知中心：本地关联事件通知可点击跳转（打卡/挑战/成就/模板）；后端公告不可跳（仅已读）。
- 顶部：「全部已读」「清空」；列表项左滑或长按清除；未读加粗+左侧指示点。
- UI 严格遵循 `themeTokensProvider`/`uiStyleProvider` 风格规范（禁止硬编码主题色）。

### 5.4 改动文件

新增 `lib/features/notification/`（models、dao、repository、providers、pages）；改造通知中心页；首页铃铛挂红点 provider；DB 版本升级迁移。

## 6. 后台设计（Next.js）

- `dashboard/notifications/page.tsx` + `notifications.ts` action + 侧边栏入口。
- 列表：标题、分类、定向摘要、投放窗口、启停、创建时间；启停切换、删除、分页。
- 新建/编辑：公共字段（标题/正文/分类/图标/窗口/排序/启停）+ 定向作用域单选（all/devices/criteria；devices 填 deviceId 列表；criteria 填平台/机型/系统版本/App版本/邮箱）。
- 复用 shadcn/ui 与现有 admin action 模式。
- 公告不可跳转；本地关联事件跳转由手机端本地决定。

## 7. 后续优化登记

- **P1** · 通知读状态由本机迁移到后端数据库持久化（`docs/future-optimizations.md` 已登记）。

## 8. 部署/提交

- 后端与后台每完成一次修改，commit 并按 AGENTS.md 规则 push 到 origin(gitee)+github 两个远程。