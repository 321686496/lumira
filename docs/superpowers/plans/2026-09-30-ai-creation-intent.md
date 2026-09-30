# 实施计划：AI 一键生成模板 · 创作意图解析

设计文档：`docs/superpowers/specs/2026-09-30-ai-creation-intent-design.md`

## Task 1 · 新增 `creation-intent.ts`
文件：`lumira-server/packages/backend/src/modules/ai/creation-intent.ts`

- [ ] `CreationIntent` / `CreationIntentMode` 类型
- [ ] `normalizeCreationIntent(raw, { poseCount, subjectCount })`：枚举校验 + 夹取 1~9 + 显式值覆盖
- [ ] `fallbackCreationIntent({ poseCount, subjectCount })`
- [ ] `buildCreationIntentParsePrompt({ creationReq, textDesc, poseCount, subjectCount, refImageCount })`
- [ ] `parseCreationIntent(textCfg, runtime, input)`：`textChatJson`；失败/超时 → fallback
- [ ] `creationIntentOfDraft(draft): CreationIntent | null`
- [ ] `renderCreationIntentLines(intent): string[]`
- [ ] `describeCreationIntent(intent): string`

## Task 2 · `normalize.ts`
- [ ] `creationIntent` 白名单块（合法 `outputMode` + 数值夹取）
- [ ] `subjectCount` 夹取上限 8 → 9（含 warning 文案）

## Task 3 · `analyze.prompt.ts`
- [ ] `poseCountLine` / `subjectCountLine` 上限 9；`AnalyzeUserPromptInput.creationIntent`
- [ ] 硬约束 `meta.subjectCount` 规则补「多格拼图同一人 = 同一主体，人数按单格计」
- [ ] `extrasLines` 注入 `renderCreationIntentLines`

## Task 4 · `ai-analyze.service.ts`
- [ ] `traceStep('intent', '创作意图解析', …)` 解析意图
- [ ] 强制值：`forcedPoseCount` / `forcedSubjectCount`（仅 `source==='llm'` 时用意图值）
- [ ] `subjectCountHint` 改用意图的 `subjectPerImage`
- [ ] 归一化前写 `json.creationIntent`；归一化后按 `pose` 条数回填 `imageCount`

## Task 5 · `image-prompt.builder.ts`
- [ ] `subjectCountOfDraft` 上限 9
- [ ] singlePose 分支由 `creationIntent` 驱动（人数句 / merge-group 反向句 / 分身禁令 / 一致性句跳过）

## Task 6 · `ai-generate-image.service.ts`
- [ ] `describeReferences` system prompt 增加「不得据此推断画面人数」

## Task 7 · `ai-pipeline-job.service.ts`
- [ ] `sameSubjectAcross=false` → 依赖张不传锚点、`consistency.mode='loose'`
- [ ] `generateWithRetry` 每次重试前补 `note` 事件（尝试次数 + 退避秒数）

## Task 8 · 后台 `wizard.tsx`
- [ ] 「人物数量」下拉扩展到 1~9

## Task 9 · 测试
- [ ] 新增 `creation-intent.spec.ts`
- [ ] `analyze.prompt.spec.ts` / `normalize.spec.ts` / `image-prompt.builder.spec.ts` / `ai-pipeline-job.service.spec.ts` 增量断言

## Task 10 · 验证与提交
- [ ] `pnpm --filter @lumira/backend typecheck`
- [ ] `pnpm --filter @lumira/backend test`
- [ ] commit + `git push origin master` + `git push github master`