# AI Config Full Connectivity Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admin test all AI models by default and choose a subset when needed.

**Architecture:** Extend the backend config test service with target filtering and real minimal image requests. Add optional targets to the admin API action, then render target checkboxes and per-target results.

**Tech Stack:** NestJS, Drizzle, existing OpenAI-compatible clients, Next.js server actions, React, Vitest, Jest.

## Global Constraints

- Default targets are `vision`, `text`, `image`, and `silhouette`.
- Invalid, duplicate, unknown, or empty explicit target arrays return `BadRequestException`.
- Existing vision/text behavior stays backward compatible.
- Image/silhouette requests are real billed calls with 30-second timeouts.

---

### Task 1: Backend Targeted Tests

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.controller.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`

**Interfaces:**
- Produces: `type AiConfigTestTarget = 'vision' | 'text' | 'image' | 'silhouette'`
- Produces: `AiConfigService.test(targets?: AiConfigTestTarget[])`

- [ ] Write failing Jest tests for default all targets, subset filtering, invalid targets, image success, silhouette success, and independent image failures.
- [ ] Run `pnpm --filter @lumira/backend test -- ai-config.service` and verify new tests fail.
- [ ] Implement target normalization, target execution, and expanded result type.
- [ ] Run backend AI config tests and verify all pass.

### Task 2: Admin Target Selection

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/lib/api.ts`
- Modify: `lumira-server/packages/admin/src/actions/ai.ts`
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`
- Test: `lumira-server/packages/admin/src/lib/__tests__/api.test.ts`

**Interfaces:**
- Consumes: `AiConfigTestTarget` and `AiConfigTestResult`
- Produces: `api.testAiConfig(payload?: { targets?: AiConfigTestTarget[] })`

- [ ] Write a Vitest test proving selected targets are POSTed as JSON.
- [ ] Run admin API tests and verify the new test fails.
- [ ] Add target types, API payload, server action payload, checkbox state, and per-target result UI.
- [ ] Run admin tests and verify all pass.

### Task 3: Verification

- [ ] Run `pnpm --filter @lumira/backend test -- ai-config.service`.
- [ ] Run `pnpm --filter @lumira/admin test`.
- [ ] Commit and push backend/admin changes to `origin/master` and `github/master`.
