# 「个人信息修改」功能交付文档（未完成项清单）

> 日期：2026-08-05
> 功能：为「我的」页新增用户名 + 头像编辑能力（设备随 ID 存储、首次注册自动分配默认资料、内置 picsum 头像池 + 中文诗意昵称池、离线优先双写）
> 状态：**Task 1-6 已完成并评审通过，Task 7 及收尾未做**，本文档供后续接手者使用

## 一、已完成（无需重复）

| 任务 | 提交 | 内容 |
|---|---|---|
| Task 1 | `9129402` | 后端 shared 类型 + `user_profiles` 表 + 昵称/头像常量池 + register 返回 profile |
| Task 2 | `448246f` | 后端 ProfileModule（GET/PATCH `/profile`）+ e2e |
| Task 3 | `0d4db1f` | Flutter 数据层（v15 迁移 + ProfileData + DAO + 常量池） |
| Task 4 | `e399be4` | Flutter 网络层 + ProfileSyncService + providers + 单测 |
| Task 5 | `8a0194e` | 注册响应/启动同步/userProfileProvider/路由名接入 |
| Task 6 | `1e6250b` | ProfileEditPage（多风格×多主题）+ HeroCard 编辑入口 + 路由 |

> 注：上述提交间穿插了其他功能（checkin/拍摄页模板信息卡）的提交，属正常并发，无需处理。

## 二、未完成项（需后续处理）

### 1. Task 7：全量回归验证（无代码变更，仅验证）

- 后端全量 e2e：`cd lumira-server && pnpm --filter backend test:e2e`（预期全部 PASS）
- Flutter 全量：`cd lumira_app_flutter && flutter analyze && flutter test`（预期 analyze 无 error，测试全过；代码库存在约 270 条既有 info 级 lint，属历史存量）
- 将两端结果记录到 `docs/superpowers/plans/2026-08-05-profile-edit.md` 末尾「回归结果」小节

### 2. 最终 whole-branch review（SDD 流程收尾）

- 以 merge-base `9c46349`（特性基线）到 HEAD 生成全分支 review package，派发最终 code reviewer（模板见 `.trae/skills/requesting-code-review/code-reviewer.md`）
- 若返回 findings，用一个 fix subagent 集中修复

### 3. Minor 修复裁决（共 14 条，合并前逐条决定是否修复）

**后端（5 条）**
1. `getOrCreateProfile` 注册竞态窗口存在 PK 冲突 500 风险（建议 `onConflictDoNothing`）— `lumira-server/packages/backend/src/modules/profile/profile.service.ts`
2. 时间戳重复派生，未复用统一 `now`（同文件 `updateProfile`）
3. e2e 可补：重注册应返回相同 profile（`test/device.e2e-spec.ts`）
4. `updateProfile` 3 次查询可降为 2（`profile.service.ts`）
5. e2e 可补：单字段 PATCH、avatarSeed>64、坏 token PATCH（`test/profile.e2e-spec.ts`）

**Flutter（9 条）**
6. `_save()` 无 try/catch：本地 DB 写（`ProfileSyncService.save` 内 upsert）若抛异常，`_saving` 会卡死导致保存按钮永久禁用、无反馈、不返回 — `lumira_app_flutter/lib/features/profile/pages/profile_edit_page.dart`
7. `_loadInitial` 同类无兜底（可与 6 合并处理）
8. profile 解析逻辑在 `main.dart` `_doRegister` 与 `device_models.dart` `fromJson` 间轻微重复
9. 启动 fire-and-forget 同步无 catchError（风险低，sync 服务内部已吞错）— `lib/main.dart`
10. 新接线分支缺直接单测（项目无 `auth_controller_test.dart`/`device_repository_test.dart`）
11. `RemoteProfileRepository.fetch` 空哨兵 `ProfileData('','')` 静默兜底（建议改 `updated!`/StateError）— `lib/features/profile/data/profile_repository.dart`
12. `save()` 中 ApiException 与非 ApiException 的 error 文案格式不一致 — `lib/features/profile/services/profile_sync_service.dart`
13. DAO `get()` 空行分支未测 — `test/core/db/profile_dao_test.dart`
14. `ProfileData.copyWith` 无法将 `syncedAt` 重置为 null（当前由 DAO 处理，保持即可）

### 4. finishing-a-development-branch

- 完成上述后，走 `superpowers:finishing-a-development-branch` 技能决策合并/PR/清理

### 5. 后续可选（非阻塞）

- 用 `qwen_image_gen.py` 生成真实内置头像替换 picsum seed（首版已按 picsum 实现，用户确认作为后续可选）

## 三、关键文件索引

- 设计文档：`docs/superpowers/specs/2026-08-05-profile-edit-design.md`
- 实施计划（含 7 个任务完整代码块）：`docs/superpowers/plans/2026-08-05-profile-edit.md`
- SDD 进度台账：`.superpowers/sdd/progress.md`（Task 1-6 记录在此）
- 各任务 brief/report/review：`.superpowers/sdd/task-1-brief.md` ~ `task-6-brief.md`、`task-*-report.md`、`task-*-review.md`、`review-*.diff`

## 四、核心代码位置速查

- 后端：`lumira-server/packages/backend/src/modules/profile/`（controller/service/dto/constants）、`src/database/migrations/004_user_profiles.sql`、`src/database/schema.ts`
- Flutter：`lumira_app_flutter/lib/features/profile/`（data/services/providers/pages）、`lib/core/db/tables.dart`、`lib/core/db/database_provider.dart`（v15）、`lib/main.dart`、`lib/core/auth/auth_controller.dart`
