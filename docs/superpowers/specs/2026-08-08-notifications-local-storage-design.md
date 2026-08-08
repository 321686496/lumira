# 通知中心本地化设计（Notifications Local Storage）

日期：2026-08-08
状态：已确认（用户批准方案 A）

## 1. 背景与目标

当前「通知中心」页（`lumira_app_flutter/lib/features/profile/pages/profile_notifications_page.dart`）是占位实现，展示 5 条硬编码 mock 通知，长按可清除（仅内存态，重启丢失）。

目标：将通知功能完善为**真实数据**，所有通知数据（创建与获取）**全部存储在本地 SQLite**：

- 应用内事件自动创建通知并写入本地库
- 通知列表/未读数/已读状态/删除全部持久化
- 首页铃铛图标显示未读角标

## 2. 方案选型

| 方案 | 说明 | 结论 |
|---|---|---|
| A. 独立通知表 + Repository + 事件埋点 | 新增 `notifications` 表，事件发生时写入，支持已读/删除/去重 | **采纳** |
| B. 查询时动态派生 | 由 challenge_history/gallery 实时计算，无存储 | 无法持久化已读/删除，系统公告无处存放 |
| C. 混合（表 + 派生） | 复杂度高收益低 | 不采纳 |

## 3. 数据层设计

### 3.1 通知类型（`type`）

| type | 触发事件 | 示例文案 |
|---|---|---|
| `challenge` | 挑战提交成功 | 「挑战完成」+ 标题 + 奖励 XP |
| `achievement` | 成就解锁（新解锁项） | 「成就解锁」+ 成就名称 |
| `checkin` | 连续打卡达里程碑（7/15/30 天） | 「连续打卡」+ 天数 |
| `system` | App 启动种子化公告 | 欢迎语 / 版本说明 |

### 3.2 `notifications` 表（v21 迁移）

```sql
CREATE TABLE IF NOT EXISTS notifications (
  id         TEXT PRIMARY KEY,
  type       TEXT NOT NULL,             -- challenge | achievement | checkin | system
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  icon_key   TEXT NOT NULL,             -- Material 图标名，如 emoji_events_outlined
  is_read    INTEGER NOT NULL DEFAULT 0,
  source_key TEXT NOT NULL UNIQUE,      -- 去重键
  created_at INTEGER NOT NULL           -- 毫秒时间戳
);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(is_read) WHERE is_read = 0;
```

- `source_key` 唯一约束实现幂等去重（插入用 `ConflictAlgorithm.ignore`）：
  - 挑战完成：挑战历史 id（如 `2026-08-08_c01`）→ 重拍重复提交不产生重复通知
  - 成就解锁：`achievement:<id>`
  - 打卡里程碑：`checkin:<7|15|30>`
  - 系统公告：`system:<key>`（如 `system:welcome`、`system:v1.2`）

### 3.3 新增文件（`lib/features/notifications/`）

| 文件 | 职责 |
|---|---|
| `data/notification_models.dart` | `AppNotification` 模型（id/type/title/body/iconKey/isRead/sourceKey/createdAt）+ 图标名→IconData 映射 |
| `data/notification_dao.dart` | `NotificationDao`：insert(ignore 去重)/getAll/markRead/markAllRead/delete/clearAll/getUnreadCount/hasBySourceKey |
| `data/notification_repository.dart` | `NotificationRepository`：事件化 API + 去重 + 打卡里程碑判定 |
| `data/notification_providers.dart` | Riverpod providers：列表 / 未读数 / 操作 Notifier |

### 3.4 Provider 注册

在 `database_provider.dart` 新增：

```dart
final notificationDaoProvider = FutureProvider<NotificationDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return NotificationDao(db);
});
```

Provider 集（`notification_providers.dart`）：

- `notificationsProvider`：`FutureProvider<List<AppNotification>>`，按 `created_at DESC` 取全部
- `unreadNotificationsProvider`：`FutureProvider<int>`
- `notificationActionsProvider`：`Notifier`，提供 `markRead(id)` / `markAllRead()` / `delete(id)` / `clearAll()`，操作后 `ref.invalidate` 两个查询 provider

### 3.5 迁移

- `_kDbVersion` 20 → 21
- `_onCreate` 追加建表语句（fresh install）
- `_onUpgrade` 追加 `if (oldVersion < 21)` 分支（既有安装），沿用静默回退风格
- `Tables` 类新增 `NotificationsTable` 常量（仿 `WatermarkTemplatesTable`）

## 4. 事件埋点（通知创建）

| 位置 | 埋点逻辑 |
|---|---|
| `challenge_confirm_page.dart` `_onSubmit` 成功路径（XP 累加后） | `notifyChallengeCompleted(historyId, title, rewardXP)`；随后检测成就与打卡里程碑 |
| 挑战提交后的成就检测 | 调 `ChallengeRepository.getAchievements()`（挑战成就，基于 challenge_history 实际计算解锁；`user_progress.achievements_json` 从未被写入，成长成就恒为锁死态，不可用），对比已通知集合（`hasBySourceKey`），对**新解锁**项逐条 `notifyAchievementUnlocked` |
| 打卡里程碑检测 | 复用 streak 计算（连续完成挑战天数，对齐 `home_providers.dart` 的 HomeStreakProvider 逻辑），达 7/15/30 时 `notifyCheckinStreak(days)` |
| App 启动（splash 初始化） | `seedSystemAnnouncements()`：表内无 system 类型时写入欢迎语 + 版本说明公告 |

> 去重保障：所有写入均带 `source_key`，DB 唯一约束兜底，重复触发不会产生重复通知。

## 5. UI 改造

### 5.1 通知中心页（重写 `profile_notifications_page.dart`）

- 数据源改为 `notificationsProvider`（真实 DB 数据），移除 `_kMockNotifications`
- 相对时间格式化：刚刚 / N 分钟前 / N 小时前 / 昨天 / M月d日
- 未读样式：标题加粗 + 左侧圆点；已读：常规样式
- 点击 → `markRead(id)` 并更新列表
- 长按 → `delete(id)` + Toast「已清除」（保留现有交互）
- 导航栏新增「全部已读」action（`markAllRead()`）
- 空态「暂无通知」保持不变
- 支持点击通知跳转（可选，MVP 不做——避免引入复杂路由映射）

### 5.2 首页铃铛角标（`home_page.dart`）

- `_NavAction` 或导航铃铛外层加 `Stack` 红点角标
- 数据源 `unreadNotificationsProvider`，未读数 > 0 时显示数字角标

## 6. 错误处理

- DAO 写库失败：不阻塞主流程（静默降级，`debugPrint` 记录），与现有 DAO 风格一致
- 通知创建埋点在成功路径中，失败不影响挑战/XP 主流程
- 空数据/读库失败：UI 显示空态

## 7. 测试

- `test/core/db/dao/notification_dao_test.dart`：插入去重、未读计数、标记已读、删除、全部已读
- `test/features/notifications/notification_repository_test.dart`：挑战/成就/打卡/系统公告事件 → 正确创建通知且幂等
- 对齐现有测试模式（内存数据库 + 真实 DAO 构造）

## 8. 验收标准

1. 通知中心展示真实本地数据，不再是 mock
2. 完成挑战后自动出现「挑战完成」通知，重复提交不重复
3. 解锁新成就后自动出现「成就解锁」通知
4. 连续打卡达 7/15/30 天出现里程碑通知
5. 全新安装启动后出现系统公告（欢迎 + 版本说明）
6. 未读数角标实时正确；点击/全部已读后角标归零
7. 长按删除持久化，重启后仍为删除状态
