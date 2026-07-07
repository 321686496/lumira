# Task 0.2 Report: 更新路由配置与 TabBar 为 3+1 结构

## Status: DONE_WITH_CONCERNS

## Summary

按照 task-0.2-brief.md 的要求，将 `lumira-app/src/pages.json` 替换为新的 3+1 路由 + TabBar 配置。所有 131 个单元测试通过。提交 SHA: `e3528cb`。

## Changes Made

**File modified:** `lumira-app/src/pages.json`

### Diff 摘要
1. **新增 Splash 路由（冷启动入口）**: 在 `pages` 数组首位添加 `pages/splash/index`，使用 `navigationStyle: custom`
2. **TabBar 切换为自定义模式**: 将原 `"height": "0px"` 占位配置改为 `"custom": true`，启用 uni-app 自定义 tabBar 机制（实际 UI 由 `FloatingTabBar.vue` 渲染）
3. **TabBar 配色对齐设计令牌**: `color` 由 `#000000` 改为 `#9C9690`（text-tertiary），`selectedColor` 由 `#000000` 改为 `#C9A96E`（brand-primary）
4. **list 项规范化**: 移除空 `iconPath`/`selectedIconPath` 字段；list 保留 `home` + `profile` 两条（uni-app 强制要求 tabBar.list 至少 2 项），`capture` 由 FloatingTabBar 中间悬浮快门按钮承载，不进入原生 list
5. **所有 13 个页面统一使用 `navigationStyle: custom`**

## Verification

### Test Suite
- Command: `pnpm test -- --run` (run from `lumira-app/`)
- Result: **7 test files passed, 131 tests passed**, 0 failed
- Duration: 1.94s
- 测试套件不导入 `pages.json`，所以路由配置变更不会影响 vitest 单元测试
- `FloatingTabBar.vue` 组件测试（19 项）继续通过，证明组件层 3+1 结构（首页/拍摄快门/我的）未受影响

### Git
- Commit SHA: `e3528cb`
- Commit message: `feat(routes): add splash page and update tabBar to 3+1 layout`（与 brief 完全一致）
- 1 file changed, 6 insertions(+), 9 deletions(-)
- 父提交: `955037f5` (Task 0.1 design tokens)

## Self-Review

✅ Splash 作为冷启动入口排在 pages 首位（uni-app 默认启动 pages[0]）
✅ 所有 13 个路由均配置 `navigationStyle: custom`，与全屏沉浸式设计一致
✅ `tabBar.custom: true` 正确启用 uni-app 自定义 tabBar 模式，由 `FloatingTabBar.vue` 接管 UI
✅ tabBar.list 含 home + profile 两条，满足 uni-app 最少 2 项的硬性要求
✅ 配色与 Task 0.1 引入的设计令牌（`#9C9690` text-tertiary / `#C9A96E` brand-primary）一致
✅ FloatingTabBar 组件内部 3+1 结构（home/capture/mine）独立于 pages.json，capture 中间快门按钮由组件自身定义
✅ Commit message 与 brief 完全一致
✅ 测试全部通过

## Concerns

1. **`pages/splash/index.vue` 文件尚不存在**: pages.json 已声明该路由，但 `lumira-app/src/pages/splash/` 目录尚未创建。这意味着 brief 中的 Step 2（`npm run dev:h5`）当前会因路由指向的页面文件缺失而编译失败。由于父任务指令只要求运行 `pnpm test -- --run`（vitest 单元测试，不涉及页面编译），测试套件正常通过；但后续必须有一个任务实际创建 `src/pages/splash/index.vue` 文件，否则 H5/小程序构建会报错。预计在后续 splash 实现任务中完成。

2. **"3+1" 命名说明**: 该命名指 3 个可见 Tab（首页/拍摄/我的，由 FloatingTabBar.vue 渲染）+ 1 个 Splash 入口路由。原生 `tabBar.list` 中只有 2 项（home/profile），因为 uni-app 不允许在原生 list 中放置"中间突出按钮"，capture 由 FloatingTabBar 的中间快门按钮承载。这是 uni-app 自定义 tabBar 的标准做法。

3. **行尾警告**: Git 提示 `LF will be replaced by CRLF`（Windows 工作树）。这是 Windows 环境的正常行为，不影响功能。仓库应通过 `.gitattributes` 统一行尾，但本任务范围之外。

## Files

- Modified: `d:\app\projects\photo_post\.worktrees\lumira-v1-rebuild\lumira-app\src\pages.json`

## Next Steps (out of scope for this task)

- 实现 `lumira-app/src/pages/splash/index.vue`（含 Splash 自动跳转到 home 的逻辑）
- 在 App.vue 或对应页面挂载 `FloatingTabBar.vue` 组件
- 运行 `npm run dev:h5` 验证编译（需 splash 页面文件就绪后）

---

## Post-Review Fix (Task 0.2 Review Issues)

### Issues Addressed

1. **Critical**: brief Step 2 required `npm run dev:h5` verification but the original implementer used `pnpm test` (vitest) instead, which doesn't verify route compilation.
2. **Important**: `pages/splash/index.vue` file didn't exist, making H5 route compilation impossible. `pages.json` declared this route but the file was missing.

### Fix Applied

**File created:** `lumira-app/src/pages/splash/index.vue`

Minimal placeholder content (template + empty script setup + scoped style referencing `--color-bg-primary` design token). Full Splash implementation (auto-navigation to home, branding animation, etc.) deferred to Task 0.3 as planned.

### Verification

#### Route File Coverage (13/13 routes)
All 13 routes declared in `pages.json` now have corresponding `.vue` files:

| # | pages.json path | File exists? |
|---|---|---|
| 1 | `pages/splash/index` | ✅ (created in this fix) |
| 2 | `pages/home/index` | ✅ |
| 3 | `pages/capture/index` | ✅ |
| 4 | `pages/capture/preview` | ✅ |
| 5 | `pages/capture/parameters` | ✅ |
| 6 | `pages/templates/index` | ✅ |
| 7 | `pages/templates/detail` | ✅ |
| 8 | `pages/templates/editor` | ✅ |
| 9 | `pages/templates/import` | ✅ |
| 10 | `pages/gallery/index` | ✅ |
| 11 | `pages/gallery/detail` | ✅ |
| 12 | `pages/profile/index` | ✅ |
| 13 | `pages/profile/settings` | ✅ |

No other route files were missing. Only `pages/splash/index.vue` needed to be created.

#### H5 Build Verification (replaces brief Step 2)
- Command: `pnpm build:h5` (run from `lumira-app/`) — equivalent to `npm run build:h5` (`uni build`)
- Result: **DONE Build complete.** Exit code 0
- Output artifact: `lumira-app/dist/build/h5/index.html` (1029 bytes, generated 2026/7/7 12:17:43)
- Only sass `@import` deprecation warnings (pre-existing, unrelated to this fix; affects all components equally)
- All 13 route `.vue` files compiled successfully, including the new splash placeholder

Note: Used `build:h5` (one-shot production build) instead of `dev:h5` (long-running dev server) so the command terminates naturally and produces a verifiable artifact. Both exercise the same uni-app route compilation pipeline, so this satisfies the brief Step 2 verification intent.

### Files

- Created: `d:\app\projects\photo_post\.worktrees\lumira-v1-rebuild\lumira-app\src\pages\splash\index.vue`
- Updated: this report file (appendix)

### Commit

- Message: `fix(routes): add splash placeholder for compilation verification`
- (SHA recorded after commit by parent agent)

