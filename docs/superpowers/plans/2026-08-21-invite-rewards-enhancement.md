# 邀请有礼功能完善 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复「邀请有礼」的 4 处缺陷：邀请码存储重构、生成邀请海报+复制/保存、邀请记录显示真实好友、奖励阶梯动态化。

**Architecture:** 后端新增 `devices.invite_code` 专属列（含一次性迁移），改造 `invite.service` 读写与 `stats` 返回（`myInviteCode`/`tiers`/`invitees`）；Flutter 端重写 `profile_invite_page.dart` 的阶梯、记录、海报三块，并扩展模型与测试。

**Tech Stack:** NestJS + Drizzle ORM + MySQL8（后端）；Flutter 3.7.12 / Dart 2.19（客户端，不支持 Dart 3 records）。

## Global Constraints

- **Dart 版本**：Dart 2.19.6，不支持 records / 新语法。
- **后端改动后必须 commit 并同时 push 两个远端**（见 AGENTS.md）：`git push origin master`（gitee）+ `git push github master`（github）。
- **Flutter 端改动不自动提交/推送**（用户指示才推）。
- **Migrations**：新增 SQL 放 `lumira-server/packages/backend/src/database/migrations/`，文件名必须 > 现有最大序号（当前 020 → 新建 `021_`）。迁移由 `database.service` 每次启动按 `_migrations` 表去重执行一次。
- **UI 规范**（Flutter）：颜色/阴影/圆角一律从 `appThemeProvider` / `themeTokensProvider` 派生，禁止硬编码；复用 `NeuCard` / `LumiraButton` 等共享组件；叠图浮层按当前风格「表面 + 细边」，不做模糊/玻璃。
- **邀请码格式**：6 位，去易混淆字符（`ABCDEFGHJKMNPQRSTUVWXYZ23456789`）。
- 验收：后端 `pnpm --filter @lumira/backend build`（typecheck）+ e2e 通过；Flutter `flutter analyze` + 相关测试全绿。

---

### Task 1: 后端 — 新增 `devices.invite_code` 列与迁移

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/021_device_invite_code.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts` (devices 表)

**Interfaces:**
- Produces: `devices.inviteCode: varchar(16)` 列 + 唯一索引 `uq_devices_invite_code`。Task 2 的 service 依赖该列名。

- [ ] **Step 1: 创建迁移 SQL**

`lumira-server/packages/backend/src/database/migrations/021_device_invite_code.sql`:
```sql
-- lumira-server/packages/backend/src/database/migrations/021_device_invite_code.sql
-- 邀请码从 devices.ip_region 迁移到专属列（spec 2026-08-21-invite-rewards-enhancement）。
-- 幂等：由 _migrations 表记录，仅执行一次。

-- 1) 新增 invite_code 列（可空，未生成邀请码的设备为 NULL）
ALTER TABLE `devices` ADD COLUMN `invite_code` VARCHAR(16) NULL;

-- 2) 一次性迁移：把旧 ip_region 前缀值搬到新列（先迁移后建索引，避免唯一冲突）
UPDATE `devices`
SET `invite_code` = SUBSTRING(`ip_region`, 8)
WHERE `invite_code` IS NULL
  AND `ip_region` LIKE 'invite:%';

-- 3) 唯一索引（MySQL 允许多个 NULL，不影响未生成邀请码的设备）
CREATE UNIQUE INDEX `uq_devices_invite_code` ON `devices`(`invite_code`);
```

- [ ] **Step 2: 更新 `schema.ts` devices 表**

在 `schema.ts`（约 L14 `ipRegion: text('ip_region'),` 之后）加入：
```ts
  inviteCode: varchar('invite_code', { length: 16 }),
```
在 devices 表级索引配置（当前 `(table) => ({ emailIdx: ... })`）中加入：
```ts
}, (table) => ({
  emailIdx: uniqueIndex('uq_devices_email').on(table.email),
  inviteCodeIdx: uniqueIndex('uq_devices_invite_code').on(table.inviteCode),
}));
```
确保 `varchar` 与 `uniqueIndex` 已在文件顶部 import（已存在）。

- [ ] **Step 3: typecheck 验证**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过，无类型错误。

- [ ] **Step 4: Commit + 双推**

```bash
git add lumira-server/packages/backend/src/database/migrations/021_device_invite_code.sql lumira-server/packages/backend/src/database/schema.ts
git commit -m "feat(backend): add devices.invite_code column with data migration"
git push origin master
git push github master
```

---

### Task 2: 后端 — `invite.service.ts` 改用新列并扩展 stats

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/invite/invite.service.ts`

**Interfaces:**
- Consumes: `devices.inviteCode` 列（Task 1）。
- Produces: `getInviteStats` 返回新增 `myInviteCode: string|null`、`tiers: Array<{tier,requiredInvites,rewards,done,locked}>`、`invitees: Array<{inviteeDeviceId,channel,activatedAt}>`。

- [ ] **Step 1: 重写 `generateInviteCode` / `inviteCodeExists` / `findInviterByCode`**

将 `invite.service.ts` 中 L14-L65 的三处 ip_region 前缀逻辑替换为：
```ts
  // 生成或获取已有邀请码（存入 devices.invite_code 列）
  async generateInviteCode(deviceId: string): Promise<string> {
    const db = this.dbService.getDb();

    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    // 兼容读取：优先新列；为空但旧 ip_region 前缀存在则一次性迁移
    let existingCode = device?.inviteCode ?? null;
    if (!existingCode && device?.ipRegion?.startsWith('invite:')) {
      existingCode = device.ipRegion.substring(7);
      await db.update(devices)
        .set({ inviteCode: existingCode })
        .where(eq(devices.deviceId, deviceId));
    }
    if (existingCode) {
      return existingCode;
    }

    // 生成唯一邀请码
    let code: string;
    let attempts = 0;
    do {
      code = generateInviteCode();
      attempts++;
      if (attempts > 10) {
        throw new BadRequestException('Failed to generate unique invite code');
      }
    } while (await this.inviteCodeExists(code));

    await db.update(devices)
      .set({ inviteCode: code })
      .where(eq(devices.deviceId, deviceId));

    return code;
  }

  private async inviteCodeExists(code: string): Promise<boolean> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.inviteCode, code),
    });
    return !!result;
  }

  // 通过邀请码找到邀请人设备
  async findInviterByCode(code: string): Promise<string | null> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.inviteCode, code),
    });
    return result?.deviceId || null;
  }
```

- [ ] **Step 2: 扩展 `getInviteStats`**

在 `getInviteStats` 的返回对象前追加逻辑（放在 `unlockedRewards` 组装之后、`return` 之前），并替换 return ：

```ts
    // 我的邀请码
    const me = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    const myInviteCode = me?.inviteCode ?? null;

    // 全量活动阶梯 + done/locked 状态（供前端动态渲染）
    const tiers = sortedTiers.map((t) => {
      const done = totalInvites >= t.requiredInvites;
      const isNext = nextTier && nextTier.tier === t.tier;
      return {
        tier: t.tier,
        requiredInvites: t.requiredInvites,
        rewards: JSON.parse(t.rewardsJson),
        done,
        locked: !done && !isNext,
      };
    });

    // 被邀请人真实记录（作为邀请人的邀请）
    const inviteesRows = await db.query.inviteRecords.findMany({
      where: eq(inviteRecords.inviterDeviceId, deviceId),
      orderBy: (r, { desc }) => [desc(r.activatedAt)],
    });
    const invitees = inviteesRows.map((r) => ({
      inviteeDeviceId: r.inviteeDeviceId,
      channel: r.channel,
      activatedAt: r.activatedAt,
    }));

    return {
      totalInvites,
      currentTier,
      nextTier,
      unlockedRewards: rewardsWithItems,
      myInviteCode,
      tiers,
      invitees,
    };
```

- [ ] **Step 3: typecheck 验证**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过。若 `db.query.inviteRecords.findMany` 的 `orderBy` 类型报错，改用 `.orderBy(inviteRecords.activatedAt)` 筛语句数组形式；`desc` 需从 `drizzle-orm` import（文件顶部已 `import { eq, and, count }`，需补 `desc`）。

- [ ] **Step 4: Commit + 双推**

```bash
git add lumira-server/packages/backend/src/modules/invite/invite.service.ts
git commit -m "feat(backend): store invite code in devices.invite_code, extend invite stats with tiers/invitees/myInviteCode"
git push origin master
git push github master
```

---

### Task 3: 后端 — e2e 断言扩展

**Files:**
- Modify: `lumira-server/packages/backend/test/invite.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 2 的 `stats` 返回结构。

- [ ] **Step 1: 在归档统计测试中补充新字段断言**

修改「GET /api/v1/invite/stats — should return invite stats」用例（此测试在 invitee 已激活后、用 inviterToken 查询），追加断言：
```ts
  it('GET /api/v1/invite/stats — should include myInviteCode/tiers/invitees', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/invite/stats')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.myInviteCode).toBe(inviteCode);
    expect(Array.isArray(res.body.tiers)).toBe(true);
    expect(res.body.tiers.length).toBeGreaterThan(0);
    expect(res.body.tiers[0]).toHaveProperty('done');
    expect(res.body.tiers[0]).toHaveProperty('locked');
    expect(res.body.tiers[0]).toHaveProperty('rewards');
    // invitees 为真实被邀请记录（inviteeDeviceId 已在激活写入）
    expect(res.body.invitees).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ inviteeDeviceId, channel: 'direct' }),
      ]),
    );
  });
```
> 注意：`inviteeDeviceId` 变量在文件顶部已定义。此用例放在原 stats 用例之后即可。

- [ ] **Step 2: 运行 e2e**

前置：本地存在可用的 MySQL（默认 root/root, 端口 3306），测试库 `lumira_test` 会被自动 DROP 重建，需应用全部迁移。

Run: `pnpm --filter @lumira/backend test:e2e -- invite`
Expected: 新用例与既有 invite 用例全部 PASS。

- [ ] **Step 3: Commit + 双推**

```bash
git add lumira-server/packages/backend/test/invite.e2e-spec.ts
git commit -m "test(backend): assert invite stats myInviteCode/tiers/invitees"
git push origin master
git push github master
```

---

### Task 4: Flutter — 模型新增字段与类型

**Files:**
- Modify: `lumira_app_flutter/lib/features/invite/data/invite_models.dart`

**Interfaces:**
- Consumes: `RewardItem`（来自 `rewards_models.dart`，已 import）。
- Produces: `InviteStats.tiers` / `InviteStats.invitees` / `InviteStats.myInviteCode`、`InviteTierEntry`、`Invitee`。Task 5/6 用到。

- [ ] **Step 1: 新增 `InviteTierEntry` 与 `Invitee` 模型**

在 `invite_models.dart` 末尾追加：
```dart
/// 单档奖励阶梯（stats.tiers 动态数据）
@immutable
class InviteTierEntry {
  final int tier;
  final int requiredInvites;
  final List<RewardItem> rewards;
  final bool done;
  final bool locked;

  const InviteTierEntry({
    required this.tier,
    required this.requiredInvites,
    required this.rewards,
    required this.done,
    required this.locked,
  });

  factory InviteTierEntry.fromJson(Map<String, dynamic> j) => InviteTierEntry(
        tier: j['tier'] as int,
        requiredInvites: j['requiredInvites'] as int,
        rewards: (j['rewards'] as List<dynamic>)
            .map((e) => RewardItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        done: j['done'] as bool? ?? false,
        locked: j['locked'] as bool? ?? false,
      );
}

/// 被邀请人记录（stats.invitees）
@immutable
class Invitee {
  final String inviteeDeviceId;
  final String channel;
  final int activatedAt;

  const Invitee({
    required this.inviteeDeviceId,
    required this.channel,
    required this.activatedAt,
  });

  factory Invitee.fromJson(Map<String, dynamic> j) => Invitee(
        inviteeDeviceId: j['inviteeDeviceId'] as String,
        channel: j['channel'] as String? ?? 'direct',
        activatedAt: j['activatedAt'] as int,
      );
}
```

- [ ] **Step 2: 扩展 `InviteStats`**

修改 `InviteStats`：新增字段（带默认值，保持既有构造调用不破坏）、更新 `fromJson`：
```dart
class InviteStats {
  final int totalInvites;
  final int currentTier;
  final NextInviteTier? nextTier;
  final List<UnlockedReward> unlockedRewards;
  // 新增
  final String? myInviteCode;
  final List<InviteTierEntry> tiers;
  final List<Invitee> invitees;

  const InviteStats({
    required this.totalInvites,
    required this.currentTier,
    this.nextTier,
    required this.unlockedRewards,
    this.myInviteCode,
    this.tiers = const [],
    this.invitees = const [],
  });

  factory InviteStats.fromJson(Map<String, dynamic> j) {
    final nextTierRaw = j['nextTier'] as Map<String, dynamic>?;
    final unlockedRaw = j['unlockedRewards'] as List<dynamic>? ?? const [];
    final tiersRaw = j['tiers'] as List<dynamic>? ?? const [];
    final inviteesRaw = j['invitees'] as List<dynamic>? ?? const [];
    return InviteStats(
      totalInvites: j['totalInvites'] as int,
      currentTier: j['currentTier'] as int,
      nextTier: nextTierRaw == null ? null : NextInviteTier.fromJson(nextTierRaw),
      unlockedRewards:
          unlockedRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
      myInviteCode: j['myInviteCode'] as String?,
      tiers: tiersRaw.map((e) => InviteTierEntry.fromJson(e as Map<String, dynamic>)).toList(),
      invitees: inviteesRaw.map((e) => Invitee.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
```
> `fromJson` 里的 `unlockedRewards` 用 `?? const []` 兜底（原为强转），避免新老契约空字段崩溃。

- [ ] **Step 3: 验证编译**

Run: `cd lumira_app_flutter && dart analyze lib/features/invite/data/invite_models.dart`
Expected: 无错误。

---

### Task 5: Flutter — 奖励阶梯动态化 + 邀请记录真实好友

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart`

**Interfaces:**
- Consumes: `InviteStats.tiers` / `InviteStats.invitees`（Task 4）。
- Produces: 页面渲染逻辑。Task 6 复用手头 `InviteStats`。

- [ ] **Step 1: 重写 `_RewardCard` 动态阶梯（保留静态兜底）**

将 `_RewardCard` 改为：优先用 `stats.tiers`，为空回退静态阶梯。
```dart
class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider).valueOrNull;
    final tiers = stats?.tiers ?? const [];
    final List<RewardEntry> rewards;
    if (tiers.isEmpty) {
      // 兜底：后端未返回 tiers 时用静态阶梯
      rewards = _buildRewardLadder(stats);
    } else {
      rewards = tiers.map((t) {
        final done = t.done;
        final locked = t.locked;
        final labelList = t.rewards.map((r) => r.label).join('、');
        return RewardEntry(
          icon: Icons.card_giftcard,
          countLabel: '${t.requiredInvites} 分享',
          name: labelList.isEmpty ? '第 ${t.tier} 档奖励' : labelList,
          done: done,
          locked: locked,
          status: done ? '已达成' : (locked ? '' : '进行中'),
        );
      }).toList();
    }
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '奖励阶梯',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(children: rewards.map((r) => _RewardRow(item: r, tokens: tokens)).toList()),
        ],
      ),
    );
  }
}
```
> 保留原 `_RewardLadderItem` / `_rewardLadder` / `_buildRewardLadder` / `RewardEntry` / `_RewardRow` 不动，仅作兜底。若 `InviteTierEntry` 奖励列表里某档有多个 `reward.label`，用「、」连接展示。

- [ ] **Step 2: 重写 `_RecordCard` 展示真实被邀请好友**

将 `_RecordCard` 改为读取 `stats.invitees`，并新增 `_InviteeRow`：
```dart
class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider).valueOrNull;
    final keepList = stats?.invitees ?? const <Invitee>[];
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('邀请记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 12),
          if (keepList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无邀请记录，邀请好友即可解锁奖励',
                    style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < keepList.length; i++)
                  _InviteeRow(
                    invitee: keepList[i],
                    isLast: i == keepList.length - 1,
                    tokens: tokens,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
```
并在文件内新增（保留旧的 `InviteRecord` / `_buildInviteRecords` / `_RecordRow` 删除或不再引用，避免死代码）：
```dart
class _InviteeRow extends StatelessWidget {
  const _InviteeRow({required this.invitee, required this.isLast, required this.tokens});
  final Invitee invitee;
  final bool isLast;
  final ThemeTokens tokens;

  static const _channelLabels = <String, String>{
    'direct': '直接邀请',
    'share_card': '分享卡片',
    'qrcode': '二维码',
  };
  static const _channelIcons = <String, IconData>{
    'direct': Icons.person_add_alt_1,
    'share_card': Icons.share,
    'qrcode': Icons.qr_code_2,
  };

  @override
  Widget build(BuildContext context) {
    final id = invitee.inviteeDeviceId;
    final short = id.length > 12 ? '${id.substring(0, 6)}…${id.substring(id.length - 4)}' : id;
    final channel = invitee.channel;
    final label = _channelLabels[channel] ?? channel;
    final date = _formatTimestamp(invitee.activatedAt);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(_channelIcons[channel] ?? Icons.person_add_alt_1,
                size: 20, color: tokens.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(short,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: tokens.textPrimary)),
                const SizedBox(height: 2),
                Text(date,
                    style: TextStyle(fontSize: 12, fontFamily: 'Courier New', color: tokens.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.success,
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
```
> 顶部需 import：`import '../../../features/invite/data/invite_models.dart';`（已存在）。若删除旧 `InviteRecord`/`_buildInviteRecords`/`_RecordRow` / `_formatTimestamp` 仍被别处引用需保留 `_formatTimestamp`（`_InviteeRow` 用到）。删除 `_RecordRow`、`InviteRecord`、`_buildInviteRecords` 三个不再使用的定义（YAGNI）。

- [ ] **Step 3: 运行页面测试**

Run: `cd lumira_app_flutter && flutter test test/features/profile/profile_invite_page_test.dart`
Expected: 现有用例中「renders all 5 sections」里「邀请记录」断言 `小雅/小琳/小悦`（取自 `unlockedRewards`）会失败——这正符合预期改动（记录改为真实好友）。先确认失败，Task 7 统一改断言。

---

### Task 6: Flutter — 生成邀请海报 + 复制/保存 + 我的邀请码

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart`

**Interfaces:**
- Consumes: `InviteStats.myInviteCode`、`generate()`。
- Produces: 生成按钮打开海报、头部展示我的邀请码。

- [ ] **Step 1: 新增 import**

在文件顶部加入：
```dart
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saver_gallery/saver_gallery.dart';
```

- [ ] **Step 2: 替换「生成邀请卡片」逻辑与头部展示**

将 `_generateInviteCard` 改为：确保拿到邀请码后打开海报：
```dart
  Future<void> _generateInviteCard() async {
    final toastContext = context;
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final code = await repo.generate();
      if (!mounted) return;
      // 打开全屏邀请海报
      await _showInvitePoster(code.code);
      if (!mounted) return;
      ref.invalidate(inviteStatsProvider); // 刷新 myInviteCode
    } on ApiException catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成失败：${e.message}', duration: const Duration(milliseconds: 1500));
    } catch (_) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成邀请卡片', duration: const Duration(milliseconds: 1000));
    }
  }
```
在 `build` 的 Hero 之后、`_RewardCard` 之前插入「我的邀请码」展示卡（用 `inviteStatsProvider`）：
```dart
                FadeUp(
                  delay: const Duration(milliseconds: 60),
                  child: _MyInviteCodeCard(tokens: tokens),
                ),
                const SizedBox(height: 20),
```
定义：
```dart
class _MyInviteCodeCard extends ConsumerWidget {
  const _MyInviteCodeCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(inviteStatsProvider).valueOrNull?.myInviteCode;
    return NeuCard(
      child: Row(
        children: [
          Icon(Icons.tag, size: 20, color: tokens.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code == null ? '尚未生成邀请码' : '我的邀请码：$code',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            ),
          ),
          if (code != null)
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                LumiraToast.show(context, '邀请码已复制', duration: const Duration(milliseconds: 1200));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text('复制', style: TextStyle(fontSize: 12, color: tokens.brandText)),
              ),
            ),
        ],
      ),
    );
  }
}
```
> `Clipboard.setData` 返回 `Future`；`if (!context.mounted) return;` 守卫。

- [ ] **Step 3: 新增海报底部弹层**

在文件末尾追加 `_showInvitePoster` 与 `_InvitePosterSheet`：
```dart
  Future<void> _showInvitePoster(String code) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvitePosterSheet(code: code, posterKey: _posterKey),
    );
  }

class _InvitePosterSheet extends ConsumerWidget {
  const _InvitePosterSheet({required this.code, required this.posterKey});
  final String code;
  final GlobalKey posterKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    // 复制邀请码
    void copyCode() async {
      await Clipboard.setData(ClipboardData(text: code));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('邀请码已复制：$code'), duration: const Duration(seconds: 1)),
      );
    }

    // 保存海报：捕获 RepaintBoundary 为 PNG 存入相册
    Future<void> savePoster() async {
      try {
        final boundary = posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        if (byteData == null) return;
        await SaverGallery.saveImage(
          Uint8List.fromList(byteData.buffer.asUint8List()),
          name: 'lumira_invite_${DateTime.now().millisecondsSinceEpoch}',
          quality: 95,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('海报已保存到相册'), duration: Duration(seconds: 1)),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请长按截图保存'), duration: Duration(seconds: 2)),
        );
      }
    }

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('邀请卡片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.close, color: tokens.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: posterKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tokens.brandSubtle, tokens.surface],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('邀请好友，获得奖励',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                        const SizedBox(height: 8),
                        Text('输入我的邀请码，一起记录美好时光',
                            style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
                        const SizedBox(height: 24),
                        QrImageView(
                          data: code,
                          version: QrVersions.auto,
                          size: 160,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: tokens.textPrimary),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.canvas,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(code,
                              style: TextStyle(
                                  fontFamily: 'Courier New',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: tokens.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: LumiraButton(variant: ButtonVariant.secondary, onPressed: copyCode, child: const Text('复制邀请码')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumiraButton(variant: ButtonVariant.primary, onPressed: savePoster, child: const Text('保存海报')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```
并在页面 State 顶部全局定义 `_posterKey`：
```dart
  final GlobalKey _posterKey = GlobalKey();
```
> `SaverGallery.saveImage` 需 `Uint8List`（`flutter/foundation.dart` 或 `typed_data` 已含于 `flutter/services.dart`）。若 `SaverGallery` 签名不同，以实际包 API 为准（`saveImage(bytes, name:, quality:)` 或 `fileBytes`）；如编译报参数名错，运行 `flutter pub deps` 对照 `saver_gallery` 3.0.6 的 `lib/saver_gallery.dart` 调整。

- [ ] **Step 4: import 补全**

确认文件顶部已 import：`Uint8List`（`dart:typed_data` 或经 `flutter/services.dart`）、`GlobalKey`（`flutter/widgets.dart` 已由 material 提供）、`RenderRepaintBoundary`（material 含）。

- [ ] **Step 5: 分析验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无新错误（可能残留与本次无关的既有 info）。

- [ ] **Step 6: 更新 widget 测试**

在 `test/features/profile/profile_invite_page_test.dart` 的 `wrap()` 中给 mock 的 `InviteStats` 补充新字段并新增断言：
```dart
        inviteStatsProvider.overrideWith((ref) async => const InviteStats(
              totalInvites: 3,
              currentTier: 1,
              myInviteCode: 'ABC234',
              tiers: [
                InviteTierEntry(tier: 1, requiredInvites: 1, rewards: [RewardItem(type: RewardType.template, id: 'jp-film', label: '日系胶片模板')], done: true, locked: false),
                InviteTierEntry(tier: 2, requiredInvites: 5, rewards: [RewardItem(type: RewardType.templatePack, id: 'atmosphere', label: '氛围感包')], done: false, locked: false),
              ],
              invitees: [
                Invitee(inviteeDeviceId: '33333333-3333-4333-8333-333333333333', channel: 'direct', activatedAt: 1700000000000),
              ],
              nextTier: NextInviteTier(tier: 2, requiredInvites: 5, rewards: [RewardItem(type: RewardType.templatePack, id: 'atmosphere', label: '氛围感包')]),
              unlockedRewards: const [],
            )),
```
新增用例：
- 「renders dynamic reward ladder from tiers」：断言 `日系胶片模板`、`氛围感包` 存在，`已达成` 存在。
- 「renders real invite records from invitees」：断言 `33333333…3333`（短 ID）与非空渠道标签 `直接邀请` 存在。
- 「shows my invite code」：断言 `我的邀请码：ABC234` 存在。
- 「copy my invite code」：tap 复制后断言出现 `邀请码已复制` toast。
- 「tapping 生成邀请卡片 opens poster」：tap 后 `pumpAndSettle`，断言 `邀请卡片` 与 `复制邀请码` 存在。若 `LumiraToast` 使 tap 后的既有用例「findsNWidgets(2)」不再成立（改为弹层），将该旧用例更新为「opens poster 且显示 code」。
> 对 Clipboard 的「复制」测试需在 `setUp` 里 mock：
> ```dart
> tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
>   SystemChannels.platform, (call) async => null);
> ```
> 在对应复制用例的 `testWidgets` 内调用，并在用例结束 `addTearDown(...setMockMethodCallHandler(..., null))`。

- [ ] **Step 7: 运行全部相关测试**

Run: `cd lumira_app_flutter && flutter test test/features/profile/profile_invite_page_test.dart test/features/invite/data/invite_repository_test.dart`
Expected: 全绿。

---

### Task 7: Flutter — 收尾清理

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/data/profile_mock_data.dart`（如仍引用旧 `InviteRecord`，同步调整）
- Modify: `lumira_app_flutter/test/features/invite/data/invite_repository_test.dart`（如需覆盖新字段解析）

**Interfaces:**
- Consumes: Task 4-6 的产物。

- [ ] **Step 1: 清理死代码与 mock 引用**

- 若 `profile_invite_page.dart` 中旧 `InviteRecord` / `_buildInviteRecords` / `_RecordRow` 已无人引用，删除。
- 检查 `profile_mock_data.dart` 是否仍 export 旧的 `InviteRecord` / `inviteRecords`，若仅被已删代码引用则移除对应常量/注释；若被页面兜底 `_buildRewardLadder` 仍用，保留。
- `invite_repository_test.dart`：确认 `stats` 解析正常覆盖 `tiers/invitees/myInviteCode`（如有 mock 响应，补字段断言）。

- [ ] **Step 2: 全量验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无新增错误。

Run: `cd lumira_app_flutter && flutter test`
Expected: 全量测试通过（既有无关失败用例不计入本计划验收）。