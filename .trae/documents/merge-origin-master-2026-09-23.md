# 合并 origin/master 到本地 master（真合并，保留两边）

## Context（为什么做这件事）

用户执行 `git pull origin master` 后，因本地 `master`（HEAD=1d085704）与 `origin/master`（f573773f）严重分叉，进入合并失败状态：**36 个文件未合并、约 96 处冲突块**；随后 `git pull github master` 也被未合并文件阻塞。

三方历史关系（已用 `git merge-base` 确认）：
- `origin/master`（f573773f）= 本次 MERGE_HEAD，与本地分叉，包含大量更新的特性代码
- `github/master`（d27d5baf）= 本地 `master` 的**直接祖先** → 本地已领先 github，`git push github master` 将安全 fast-forward

冲突性质（经 3 个探索代理逐子系统核实）：在 storage、AI 识别/生图链路、Flutter splash 三块里，**origin/master 都是更新/演进后的实现，HEAD 侧只是它重构之前的旧版本**：
- **Storage**：origin 引入 `runtime-storage.ts`（运行时动态切换激活存储）、qiniu 七牛支持、`storage-config.*` + `storage_config` 表（DB 驱动配置）；HEAD 用静态 `resolveActiveStorageId`。origin 版 storage-registry 仍保留 `buildStorageAdapter/resolveActiveStorageId` 并新增 qiniu，内部自洽，无悬空引用。
- **AI 链路**：origin 新增 trend-research 研究前置（`researchDigest`/`research` 透传）、`image-prompt.composer.ts`（取代 HEAD 的 `prompt-polisher` 路线）、`research-digest.ts`；HEAD 侧是旧链路。
- **Flutter splash**：origin 完成 splash 重设计（去光晕、发丝线、版本号）+ `APP_VERSION` + `dev_seed` 相册种子图 + 相关测试；HEAD 是重设计前旧态。

本地真正独立的工作（OHOS 拍摄「先快后真」链路等）位于冲突之外的 OHOS/misc 文件，已随干净自动合入保留，不受影响。

## 决策

用户已选择「真合并，保留两边」。对全部 36 个冲突文件，其中每个冲突块要么是 origin 纯新增（TAKE_ORIGIN），要么是 HEAD 为旧实现、origin 为演进版（HAND）。因此对这些文件**整体采用 origin/master 版本**即可保留两边应有的全部功能意图：origin 的演进功能完整落地，本地非冲突的独立工作保留。不做逐 hunk 手工拼合（那会把 origin 的演进覆盖回旧实现，反而丢失功能）。

## 实施步骤

### 1. 解析冲突（整体采用 origin/master 版本）
对 `git diff --name-only --diff-filter=U` 列出的 36 个未合并文件执行 `git checkout --theirs -- <file>`（合并场景下 `--theirs` = MERGE_HEAD = origin/master），随后 `git add <file>`。

冲突文件清单（全部走上述策略）：
- 根：`.gitignore`
- admin：`components/ai-create/step-cover.tsx`、`wizard.tsx`、`components/sidebar.tsx`、`lib/__tests__/ai-task.test.ts`、`lib/ai-task.ts`、`lib/api.ts`、`types/admin.ts`
- backend 存储：`common/storage/asset-url.ts`、`s3-storage.adapter.ts`、`storage-registry.ts`、`storage.module.ts`、`storage.provider.ts`、`storage-migration.service.ts`、`database/schema.ts`
- backend AI：`ai-analyze.service.ts`(+spec)、`ai-generate-image.service.ts`(+spec)、`ai-image-task.service.ts`(+spec)、`ai-orchestrator.service.ts`(+spec)、`ai-templates.controller.ts`、`analyze.prompt.ts`、`golden-set.service.spec.ts`、`llm-client.spec.ts`、`trend-research/trend-research.service.ts`(+spec)、`trend-research/web-search-qwen.ts`(+spec)
- Flutter：`core/config/app_config.dart`、`features/splash/pages/splash_page.dart`、`main.dart`、`pubspec.yaml`、`test/features/splash/splash_page_test.dart`

### 2. 验证引用一致性
替换后检查是否有非冲突文件引用了被 origin 移除/改名的符号。已知安全：
- `runtime-storage.ts`（origin 新文件）仍 import 并调用 `buildStorageAdapter/resolveActiveStorageId` → origin 的 storage-registry 保留它们，自洽。
- `prompt-polisher.ts`/`image-prompt.builder.ts`（HEAD 旧文件）在 ai-generate-image 改用 origin 版本后可能成为未被引用的死代码——**保留文件不动**（避免过度删改），仅确认无构建/类型错误。

### 3. 提交合并
全部冲突解析并 `git add` 后，`git commit` 生成合并提交（信息沿用仓库风格）。

### 4. 推送两端（符合 AGENTS.md 后端改动即推）
- `git push origin master`（gitee，fast-forward 到合并提交）
- `git push github master`（github，本地已是 github/master 的祖先，fast-forward 安全）

## 验证

1. `git status`：无未合并路径；`git diff --check` 无残留冲突标记（`<<<<<<<`/`>>>>>>>`）。
2. 后端类型检查 + 相关测试（在 `lumira-server` 运行）：
   - `pnpm --filter @lumira/backend typecheck`
   - 运行 AI + storage 相关单测（ai-orchestrator / ai-analyze / ai-generate-image / storage-migration / trend-research / web-search-qwen）
3. Flutter（在 `lumira_app_flutter` 运行）：
   - `flutter analyze`
   - `flutter test test/features/splash/splash_page_test.dart`（验证 splash 重设计版测试通过）