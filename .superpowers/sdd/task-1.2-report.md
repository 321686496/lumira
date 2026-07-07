# Task 1.2 Report: 创建首页子组件

## Status

**DONE**

## Commits

- **SHA:** `9430b7f757e7d3528db4aab3d5de6c9ed957afc3`
- **Message:** `feat(home): add all home section components`
- **Files:** 6 files changed, 525 insertions(+)
  - `lumira-app/src/components/home/BrandHeader.vue`
  - `lumira-app/src/components/home/DailyInspiration.vue`
  - `lumira-app/src/components/home/RecentPhotos.vue`
  - `lumira-app/src/components/home/FeaturedTemplates.vue`
  - `lumira-app/src/components/home/SceneQuickAccess.vue`
  - `lumira-app/src/components/home/StatsSummary.vue`

## Test Results

- **Before (baseline):** 131 tests passing
- **After:** 131 tests passing (7 test files)
- **Failures:** None
- **Command:** `pnpm test -- --run` (exit 0)

```
Test Files  7 passed (7)
     Tests  131 passed (131)
```

## Build Result

- **Status:** Success (exit 0)
- **Command:** `pnpm build:h5`
- **Output:** `DONE  Build complete.`

## Implementation Notes

All 6 components were created verbatim from the brief using `<script setup lang="ts">` and `<style lang="scss" scoped>`. Props/emits match the brief exactly:

| Component | Props | Emits |
|-----------|-------|-------|
| BrandHeader | (none) | (none) |
| DailyInspiration | `inspiration: Inspiration` | `on-try(category: string)` |
| RecentPhotos | `photos: LocalPhoto[]`, `totalCount: number` | `on-photo-click(id: string)`, `on-view-all` |
| FeaturedTemplates | `templates: LocalTemplate[]` | `on-template-click(id: string)`, `on-view-all` |
| SceneQuickAccess | `scenes: SceneDef[]` | `on-scene-click(sceneKey: string)` |
| StatsSummary | `photoCount: number`, `templateCount: number` | `on-click` |

Type imports verified against existing files:
- `LocalPhoto` (`@/types/photo`): uses `id`, `imagePath` ✓
- `LocalTemplate` (`@/types/template`): uses `id`, `coverPath?`, `name` ✓
- `Inspiration` (`@/data/inspirations`): uses `emoji`, `text`, `relatedCategory` ✓
- `SceneDef` (`@/data/scenes`): uses `key`, `emoji`, `label` ✓

CSS color, font-family, font-weight, line-height, letter-spacing, and most sizing values use design tokens from `lumira-app/src/theme/tokens.scss` (Task 0.1). The brief encodes a few fixed pixel dimensions for component-specific layouts (e.g., photo card 100×130px, template card 140×180px, divider 1×32px, line-height: 1) — these are kept verbatim per brief and are component-scoped, not tokens.

## Concerns / Deviations

None. The brief was implemented exactly as specified with no deviations.

Pre-existing (not caused by this task) observations worth noting for context only:
- The build emits Sass deprecation warnings (`legacy-js-api` and `@import` rules). These originate from existing `.vue` files that use `@import "@/theme/tokens.scss"`. The 6 new components in this task do **not** use `@import` (they rely on the global tokens), so they do not add any new warnings.
- Git on Windows emitted `LF will be replaced by CRLF` warnings for the 6 new files. This is the repository's normal line-ending behavior on Windows and is harmless.
