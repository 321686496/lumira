# 邀请有礼功能完善 — 设计文档

> 日期：2026-08-21
> 状态：待实现

## 1. 背景与目标

「邀请有礼」功能已具备最小闭环（Flutter 页 → `/invite/generate|activate|stats` → `invite_records` / `reward_tiers` / `reward_unlocks` 表 → Admin 后台表格），但存在 4 处明显不完善：

1. **邀请码存储设计缺陷**：邀请码被复用 `devices.ip_region` 字段存储（`invite:XXXXXX`）。而该字段本用于记录设备真实 IP（见 `device.service.ts` 注册时写入 `ipRegion: ip`）。邀请功能会覆盖设备 IP，且 IP 定位 / Admin 展示 `ip_region` 场景互相干扰。
2. **「生成邀请卡片」名不副实**：前端 `_generateInviteCard` 仅拿到邀请码后弹 toast，既无海报，也无复制 / 分享能力。
3. **「邀请记录」卡片语义错误**：`_RecordCard` 实际渲染的是「已解锁奖励」列表，而非真实的被邀请好友记录；后端 `stats` 未返回被邀请人名单。
4. **前端奖励阶梯硬编码**：页面写死 1/3/5/10/15/20 六档，与后端 `reward_tiers` 表（当前种子仅 1/3/5/10 四档）不一致，后台调整阶梯无法跟随。

本方案目标：彻底解决上述 4 点，后端数据模型理顺、前端分享与记录体验可用、前后台奖励阶梯数据一致。

## 2. 技术决策（已与用户确认）

### 决策 A：邀请卡片分享方式 — 海报预览 + 复制邀请码 + 保存海报
- 不依赖原生「系统分享」（`share_plus` 在 Harmony 抛出 `MissingPluginException`，见既有教训）。
- 采用：生成一张**可预览 / 可保存相册的「邀请海报」**（含 App 品牌、邀请语、大号邀请码、二维码），并提供**「复制邀请码」**按钮（`Clipboard.setData`，全平台可靠）。
- 数组件依赖：`qr_flutter`（二维码渲染，已在依赖）、`saver_gallery`（保存相册，已在依赖 3.0.6）。

### 决策 B：邀请码存储重构
- 将邀请码迁移到新建的 `devices.invite_code` 专属列（加唯一索引）。
- 做**兼容读取 / 一次性迁移**：读取时若 `invite_code` 为空但 `ip_region` 前缀为 `invite:`，则转存到新列并保留旧值；老用户邀请码不失效。
- 唯一性校验改由新列承担；`findInviterByCode` / `inviteCodeExists` 改查 `invite_code` 列。

## 3. 数据模型改动

### 3.1 新迁移 `021_device_invite_code.sql`
```sql
-- 1) 新增 invite_code 列（可空，兼容未生成邀请码的设备）
ALTER TABLE devices ADD COLUMN invite_code VARCHAR(16) NULL;

-- 2) 数据迁移：把旧 ip_region 中的 invite 前缀值搬到新列（一次性）
--    仅在 invite_code 为空时迁移，避免覆盖
UPDATE devices
SET invite_code = SUBSTRING(ip_region, 8)   -- 去掉 'invite:' 7 个前缀字符
WHERE invite_code IS NULL
  AND ip_region LIKE 'invite:%';

-- 3) 唯一索引（MySQL 允许多个 NULL，未生成邀请码的设备不影响）
--    先迁移再建唯一索引，避免重复值导致建索引失败
CREATE UNIQUE INDEX uq_devices_invite_code ON devices(invite_code);
```
> 说明：先执行数据迁移、后建唯一索引，确保已有唯一邀请码不因索引冲突失败。因旧逻辑已保证全局唯一，SUBSTRING 后理论上无重复。

### 3.2 `schema.ts` 变更
`devices` 表新增字段并在表级添加唯一索引：
```ts
inviteCode: varchar('invite_code', { length: 16 }),
// (table) => ({ ... existing emailIdx, inviteCodeIdx: uniqueIndex('uq_devices_invite_code').on(table.inviteCode) })
```

## 4. 后端改动（lumira-server/packages/backend）

### 4.1 `invite.service.ts` 重构
替换所有对 `ip_region` 前缀的读写为 `invite_code` 列：

- **`generateInviteCode(deviceId)`**：
  1. 查设备 → 若 `inviteCode` 非空则直接返回。
  2. 若 `inviteCode` 为空但 `ipRegion` 前缀为 `invite:` → 迁移到 `inviteCode` 列后返回（一次性兼容）。
  3. 否则生成新码（`generateInviteCode()`，6 位，去易混淆字符），写入 `invite_code` 列（用 `insert on conflict` / 先查重 `inviteCodeExists` 保证唯一）。
- **`inviteCodeExists(code)` / `findInviterByCode(code)`**：改为 `eq(devices.inviteCode, code)`。
  具体 `findInviterByCode`：
  ```ts
  const result = await db.query.devices.findFirst({ where: eq(devices.inviteCode, code) });
  return result?.deviceId || null;
  ```
- **`activateInvite(...)`**：核心逻辑（自邀拦截 / 防重复激活 / 防回流 / 写记录 / 计算阶梯解锁）保持不变，仅内部 `findInviterByCode` 已切换。

### 4.2 `getInviteStats(deviceId)` 扩展返回
在原有 `totalInvites / currentTier / nextTier / unlockedRewards` 基础上新增：

- **`myInviteCode: string | null`**：当前设备邀请码（未生成返回 null）。
- **`tiers: Array<{ tier, requiredInvites, rewards, done, locked }>`**：全量活动阶梯（`is_active=1`），每档标注 done / locked 状态，供前端动态渲染而非硬编码。
- **`invitees: Array<{ inviteeDeviceId, channel, activatedAt }>`**：该设备作为邀请人的被邀请记录（查 `invite_records` where `inviter_device_id = deviceId`，按 `activated_at` 倒序），供前端「邀请记录」展示真实好友。

返回结构（兼容旧字段，前端旧字段可继续用）：
```ts
return {
  totalInvites,
  currentTier,
  nextTier,
  unlockedRewards,          // 兼容保留
  myInviteCode,
  tiers,
  invitees,
};
```

### 4.3 `rewards.service.ts`
无需改动。奖励阶梯仍由 `reward_tiers` 表驱动，本次仅让前端按其动态渲染。

## 5. Flutter 端改动（lumira_app_flutter）

### 5.1 `invite_models.dart`
- `InviteStats` 新增可选字段：`myInviteCode: String?`、`tiers: List<InviteTierEntry>`（默认空）、`invitees: List<Invitee>`（默认空）。
- 新增模型：
  - `InviteTierEntry { tier, requiredInvites, rewards: List<RewardItem>, done, locked }`
  - `Invitee { inviteeDeviceId, channel, activatedAt }`
- `fromJson` 对缺失字段做默认值兜底，保持向后兼容。

### 5.2 `invite_repository.dart`
- 保持现有接口不变（`generate / activate / stats`），仅 `stats()` 解析新增字段。

### 5.3 `profile_invite_page.dart` 改造
按 4 大改进同步调整：

1. **奖励阶梯动态化**：
   - 新增 `_DynamicRewardLadder` 优先使用 `stats.tiers`（按 `tier` 升序渲染），状态（done/locked/进行中）直接用后端 `done/locked` 标记。
   - 保留原有兜底逻辑：`tiers` 为空时回退到旧的静态阶梯渲染，避免接口空响应白屏。
   - 移除写死的 `_rewardLadder` 六档（或仅用作兜底占位）。

2. **真实邀请记录**：
   - `_RecordCard` 改用 `stats.invitees` 渲染：每行显示被邀请人（`inviteeDeviceId` 短格式）、激活日期、渠道标签（direct/share_card/qrcode → 直接/分享卡片/二维码）。
   - 「暂无邀请记录」空态保留。

3. **生成邀请卡片 → 海报**：
   - 「生成邀请卡片」按钮改为：调用 `repo.generate()` 确保拿到邀请码，然后**打开全屏「邀请海报预览」**（`_InvitePosterSheet` / 独立路由）。
   - 海报内容：顶部品牌区 + 居中大号邀请码 + 二维码（`QrImageView` 编码邀请码字符串）+ 邀请语。
   - 底部操作条：**「复制邀请码」**（`Clipboard.setData` 成功 toast）、**「保存海报」**（`SaverGallery.saveImage`，失败时提示改用截图）。
   - 头部新增"我的邀请码"展示区（用 `stats.myInviteCode`，为空则显示"尚未生成"）。

4. **风格自适应**：所有新增 UI 遵循项目 UI 规范（`NeuCard`、`LumiraButton` 等共享组件，`appThemeProvider` 派生色值，不硬编码颜色；叠图浮层按当前风格走「表面 + 细边」规则）。

### 5.4 依赖说明
- `qr_flutter`、`saver_gallery` 已在 `pubspec.yaml`，无需新增依赖。

## 6. Admin 后台
- `invites-table.tsx` / `rewards-table.tsx` 已覆盖真实数据，**无需改动**。
- 可选：`@types/admin` 的 `InviteListResponse` 不变。

## 7. 测试计划

### 7.1 后端（lumira-server/packages/backend）
- 更新 `invite.service.spec.ts`：
  - 生成邀请码幂等（重复调用返回同一码）。
  - 兼容迁移：`ip_region` 含 `invite:XXX` 且 `invite_code` 为空时能读取并返回旧码。
  - `getInviteStats` 返回 `tiers`（全量活动阶梯 + done/locked）、`invitees`（被邀请记录）、`myInviteCode`。
  - 激活后 `findInviterByCode` 走新列命中。
- `flutter analyze`（后端 typecheck / e2e 走 CI）。

### 7.2 Flutter（lumira_app_flutter）
- 更新/新增 widget 测试：
  - 奖励阶梯动态渲染（mock `tiers` 数据，校验档位与 done/locked 状态）。
  - 邀请记录真实好友渲染（mock `invitees`）。
  - 生成海报打开、复制邀请码调用、保存海报调用（打桩 `Clipboard` / `SaverGallery`）。
- 相关 mock（`profile_mock_data.dart`）按新模型同步更新。
- `flutter analyze` 通过、相关测试全绿。

## 8. 部署
- 改动集中在 `lumira-server/packages/backend/**`（迁移 + service）与 `lumira_app_flutter/**`。
- 后端改动提交后 push `origin`(gitee) 与 `github`，触发 `backend-deploy.yml` → 服务器 `git reset --hard` + `docker build` + `up -d`（迁移在容器启动时由 `database.service` 自动执行）。
- Flutter 端按惯例不自动提交，按用户指示人工构建发布。

## 9. 范围与不做
- **不做**：分享行为的「待绑定」跟踪（需新增埋点记录分享事件，改动大，本轮不做）。
- **不做**：邀请海报的图片背景 AI 生成（本轮用纯 UI 组件绘制海报，文字 + 邀请码 + 二维码）。
- **不做**：Admin 端新增 reward_tiers 配置 UI（阶梯仍以种子/直改库维护）。