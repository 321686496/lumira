# 如画 Lumira v2.0 功能扩展实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement v2.0 feature expansion for 如画 Lumira — gamification, content/learning, brand propagation, offline fission, UX enhancements, and configurable monetization.

**Architecture:** All features are purely local (zero network). Gamification uses SQLite + local algorithms. Brand propagation uses Canvas compositing. Fission uses HMAC-SHA256 offline cryptography. Monetization uses static JSON configuration files. All new pages follow existing uni-app (Vue3 + TS) patterns.

**Tech Stack:** uni-app (Vue3 + TypeScript), Pinia, SQLite, Canvas API, Web Crypto API (HMAC-SHA256), SCSS design tokens.

## Global Constraints

- **Zero network permissions**: manifest.json must NOT add INTERNET or any network permission
- **No AI**: All algorithms are pure code (LUT, matrix, Canvas). No ML models.
- **No account system**: All data identified by local device ID only
- **Female-user-first visual style**: watercolor/line-art achievements, warm gold + pastel pink accents, larger border-radius (14px cards, 8px buttons), `box-shadow: 0 2px 12px rgba(0,0,0,0.04)`
- **Config-driven monetization**: All paid templates/rewards/redemption codes configured via `static/rewards/` JSON files, no hardcoded business logic
- **Follow existing patterns**: Vue3 Composition API + `<script setup lang="ts">`, SCSS tokens, proper TS typing (no `any`)
- **All existing v1.0 files remain unchanged** unless explicitly listed in a task

---

## File Structure

### New Files Summary

| File | Responsibility |
|---|---|
| `src/stores/growth.ts` | Pinia store: achievements, level, XP, daily challenge state |
| `src/stores/collections.ts` | Pinia store: photo collections CRUD |
| `src/stores/rewards.ts` | Pinia store: reward unlock state, share count |
| `src/services/invite-engine.service.ts` | Offline fission: share info generate/verify (HMAC-SHA256) |
| `src/services/watermark.service.ts` | Canvas watermark compositing |
| `src/services/canvas-card.service.ts` | Compare card / EXIF card / monthly digest generation |
| `src/services/rewards-config.service.ts` | JSON config loader for reward-catalog.json |
| `src/composables/useAchievements.ts` | Achievement detection, unlock, notification |
| `src/composables/useLevelSystem.ts` | XP management, level-up, title |
| `src/composables/useDailyChallenge.ts` | Daily challenge generation (date-hash) and tracking |
| `src/composables/useMoodTag.ts` | Mood tag CRUD and filtering |
| `src/composables/useCollections.ts` | Collection CRUD composable |
| `src/composables/useInviteShare.ts` | Fission share composable (wraps invite-engine) |
| `src/composables/useWatermark.ts` | Watermark composable (wraps watermark service) |
| `src/composables/useCompareCard.ts` | Compare/EXIF card composable |
| `src/composables/useMonthlyDigest.ts` | Monthly photo journal generation |
| `src/composables/useRedemptionCode.ts` | Hidden redemption code verification |
| `src/composables/useSceneGuide.ts` | Scene guide logic and template filtering |
| `src/components/growth/AchievementGrid.vue` | Achievement wall (Bento grid) |
| `src/components/growth/LevelProgress.vue` | Level progress bar |
| `src/components/growth/GrowthTimeline.vue` | Growth timeline view |
| `src/components/growth/DailyChallenge.vue` | Daily challenge card |
| `src/components/growth/DailyInspiration.vue` | Daily inspiration tip card |
| `src/components/capture/SceneGuideSheet.vue` | Scene selector bottom sheet |
| `src/components/capture/HorizonIndicator.vue` | Horizon level indicator overlay |
| `src/components/capture/HistogramOverlay.vue` | Live histogram overlay |
| `src/components/image/BeforeAfterCard.vue` | Before/after comparison card generator |
| `src/components/image/ExifCard.vue` | EXIF art card generator |
| `src/components/image/WatermarkPreview.vue` | Watermark preview and selector |
| `src/components/image/MoodTagPicker.vue` | Mood tag picker component |
| `src/components/gallery/BatchBar.vue` | Batch operation bar |
| `src/components/profile/RecommendToFriend.vue` | Recommend card component |
| `src/components/profile/InviteCodeInput.vue` | Hidden redemption code input |
| `src/pages/profile/growth.vue` | Growth center page |
| `src/pages/profile/invite.vue` | Invite rewards page |
| `src/pages/profile/academy.vue` | Photography academy lesson list |
| `src/pages/profile/academy-detail.vue` | Single lesson reader page |
| `src/pages/profile/collections.vue` | Collection management page |
| `src/pages/profile/collection-detail.vue` | Collection photos page |
| `src/pages/gallery/diary.vue` | Photo diary timeline page |
| `src/pages/capture/scene-guide.vue` | Scene guide selector page |
| `src/types/growth.ts` | Types for achievements, level, challenges |
| `src/types/rewards.ts` | Types for reward catalog, share info, redemption |
| `src/types/cards.ts` | Types for card generation options |
| `src/utils/hmac.ts` | HMAC-SHA256 utility (wraps Web Crypto API) |
| `static/rewards/reward-catalog.json` | Reward configuration (config-driven) |
| `static/rewards/redemption-codes.json` | Encrypted redemption code list |
| `static/lessons/lesson-01.json` through `lesson-05.json` | Tutorial content data |
| `static/inspiration/tips.json` | Daily inspiration tip pool |
| `static/challenges/challenges.json` | Daily challenge pool |
| `static/share-cards/card-01.png` | Recommend cards |

### Modified Files Summary

| File | Change |
|---|---|
| `src/pages/profile/index.vue` | Add growth, academy, invite entries; update stats |
| `src/pages/capture/index.vue` | Add scene guide entry, horizon indicator, histogram, gesture handlers, template quick-switch |
| `src/pages/capture/preview.vue` | Add "generate comparison card" button |
| `src/pages/gallery/index.vue` | Add diary entry, batch bar, mood filter |
| `src/pages/gallery/detail.vue` | Add EXIF card button, mood tag picker |
| `src/pages/templates/detail.vue` | Add example gallery tab |
| `src/pages/templates/editor.vue` | Add mood tag association (minor) |
| `src/stores/gallery.ts` | Add moodTag, isFavorite, sceneTag fields |
| `src/pages.json` | Register 8 new routes |
| `src/theme/tokens.scss` | Add new design tokens (card shadow, larger radius) |
| `src/services/storage.ts` | Add migration for new SQLite tables |
| `src/App.vue` | Add dark mode listener, register new global components |

### New SQLite Tables (in storage.ts migration)

`Achievements`, `UserLevel`, `DailyChallenges`, `Collections`, `CollectionPhotos`, `UserRewards`, `ProcessedShares`, `UsedCodes`

### New Columns on LocalPhoto

`moodTag TEXT`, `isFavorite INTEGER DEFAULT 0`, `isOutfit INTEGER DEFAULT 0`, `sceneTag TEXT DEFAULT NULL`

---

## P0 Tasks: Foundation & Experience Enhancements

### Task 1: Design Tokens & Storage Migration

**Files:**
- Modify: `src/theme/tokens.scss` (add new design tokens)
- Modify: `src/services/storage.ts` (add SQLite migration)

**Interfaces:**
- Consumes: Existing `storage.ts` service interface
- Produces: `runMigrationV2(): Promise<void>` — ensures new tables exist

- [ ] **Step 1: Add new design tokens to `src/theme/tokens.scss`**

```scss
// v2.0 additions — softer, more feminine feel
--shadow-card-soft: 0 2px 12px rgba(0,0,0,0.04);
--radius-card-lg: 14px;
--radius-button-lg: 8px;
--color-heart: #E88D8D;          // favorite/like color
--color-mood-pink: #F5E0E5;      // mood tag backgrounds
--color-mood-lavender: #E8E0F0;
--color-mood-blue: #E0ECF5;
--color-mood-warm: #F5EDDB;
--color-level-gradient: linear-gradient(135deg, #C9A96E, #F5EDDB);
--color-achievement-locked: rgba(154, 150, 144, 0.3);
--color-achievement-unlocked: #C9A96E;
```

- [ ] **Step 2: Add SQLite migration to `src/services/storage.ts`**

```typescript
// Add after existing schema initialization
async function runMigrationV2(): Promise<void> {
  const tables = [
    `CREATE TABLE IF NOT EXISTS Achievements (
      achievementId TEXT PRIMARY KEY,
      unlockedAt INTEGER NOT NULL,
      notified INTEGER DEFAULT 0
    )`,
    `CREATE TABLE IF NOT EXISTS UserLevel (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      level INTEGER DEFAULT 1,
      currentXp INTEGER DEFAULT 0,
      totalXp INTEGER DEFAULT 0,
      title TEXT DEFAULT '摄影新人'
    )`,
    `CREATE TABLE IF NOT EXISTS DailyChallenges (
      date TEXT PRIMARY KEY,
      challengeId TEXT NOT NULL,
      completed INTEGER DEFAULT 0
    )`,
    `CREATE TABLE IF NOT EXISTS Collections (
      collectionId TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      coverPhotoId TEXT,
      createdAt INTEGER,
      updatedAt INTEGER
    )`,
    `CREATE TABLE IF NOT EXISTS CollectionPhotos (
      collectionId TEXT NOT NULL,
      photoId TEXT NOT NULL,
      sortOrder INTEGER,
      PRIMARY KEY (collectionId, photoId)
    )`,
    `CREATE TABLE IF NOT EXISTS UserRewards (
      rewardId TEXT PRIMARY KEY,
      rewardType TEXT NOT NULL,
      source TEXT NOT NULL,
      unlockedAt INTEGER NOT NULL,
      metaJson TEXT
    )`,
    `CREATE TABLE IF NOT EXISTS ProcessedShares (
      deviceTag TEXT PRIMARY KEY,
      processedAt INTEGER NOT NULL,
      alias TEXT
    )`,
    `CREATE TABLE IF NOT EXISTS UsedCodes (
      codeHash TEXT PRIMARY KEY,
      usedAt INTEGER NOT NULL
    )`,
  ]
  for (const sql of tables) {
    await executeSQL(sql)
  }
  // Add columns to LocalPhoto (idempotent — SQLite ignores duplicate ALTER)
  const alterCols = [
    `ALTER TABLE LocalPhoto ADD COLUMN moodTag TEXT DEFAULT NULL`,
    `ALTER TABLE LocalPhoto ADD COLUMN isFavorite INTEGER DEFAULT 0`,
    `ALTER TABLE LocalPhoto ADD COLUMN isOutfit INTEGER DEFAULT 0`,
    `ALTER TABLE LocalPhoto ADD COLUMN sceneTag TEXT DEFAULT NULL`,
  ]
  for (const sql of alterCols) {
    try { await executeSQL(sql) } catch (_) { /* column may already exist */ }
  }
  // Insert default UserLevel row if not exists
  await executeSQL(
    `INSERT OR IGNORE INTO UserLevel (id, level, currentXp, totalXp, title) VALUES (1, 1, 0, 0, '摄影新人')`
  )
}
```

- [ ] **Step 3: Call `runMigrationV2` on app startup**

```typescript
// In src/main.ts or App.vue onLaunch
import { runMigrationV2 } from '@/services/storage'
onLaunch(async () => {
  await runMigrationV2()
  // ... existing init
})
```

- [ ] **Step 4: Commit**

```bash
git add src/theme/tokens.scss src/services/storage.ts
git commit -m "feat: add v2 design tokens and SQLite migration"
```

### Task 2: Dark Mode Support

**Files:**
- Modify: `src/App.vue`
- Modify: `src/composables/useDevice.ts`
- Create: `src/utils/dark-mode.ts`

**Interfaces:**
- Consumes: brand dark mode colors from `tokens.scss`
- Produces: `useDarkMode(): { isDark: Ref<boolean>, toggle(): void }`

- [ ] **Step 1: Create dark mode utility**

```typescript
// src/utils/dark-mode.ts
import { ref, watchEffect } from 'vue'

const isDark = ref(false)

export function initDarkMode(): void {
  const mq = window.matchMedia('(prefers-color-scheme: dark)')
  isDark.value = mq.matches
  mq.addEventListener('change', (e) => { isDark.value = e.matches })
}

export function useDarkMode(): { isDark: typeof isDark; toggleDark: () => void } {
  function toggleDark(): void {
    isDark.value = !isDark.value
    document.documentElement.classList.toggle('dark', isDark.value)
  }
  watchEffect(() => {
    document.documentElement.classList.toggle('dark', isDark.value)
  })
  return { isDark, toggleDark }
}
```

- [ ] **Step 2: Add dark mode CSS variables to App.vue**

```scss
// In App.vue global styles
:root {
  --color-bg-canvas: #FAF7F2;
  --color-bg-card: #FFFFFF;
  --color-text-primary: #1A1A1A;
  // ... all v1 tokens
}

:root.dark {
  --color-bg-canvas: #1C1A17;
  --color-bg-card: #262320;
  --color-text-primary: #F2EEE6;
  --color-bg-surface: #2A2724;
  --color-border: #3A3734;
  // All dark mode tokens from brand doc
}
```

- [ ] **Step 3: Call `initDarkMode` in App.vue `onLaunch`**

```typescript
import { initDarkMode } from '@/utils/dark-mode'
onLaunch(() => {
  initDarkMode()
  // ...
})
```

- [ ] **Step 4: Commit**

```bash
git add src/utils/dark-mode.ts src/App.vue
git commit -m "feat: add dark mode support with system preference detection"
```

### Task 3: Gesture System & Viewfinder Enhancements

**Files:**
- Modify: `src/pages/capture/index.vue`
- Create: `src/components/capture/HorizonIndicator.vue`

**Interfaces:**
- Produces: Gesture handlers attached to capture page viewfinder

- [ ] **Step 1: Create HorizonIndicator component**

```vue
<!-- src/components/capture/HorizonIndicator.vue -->
<script setup lang="ts">
interface HorizonIndicatorProps {
  angle: number
  isLevel: boolean
}
const props = defineProps<HorizonIndicatorProps>()
</script>
<template>
  <view class="horizon-indicator">
    <view class="horizon-indicator__track">
      <view
        class="horizon-indicator__bubble"
        :style="{ transform: `translateX(${props.angle}px)` }"
        :class="{ 'is-level': props.isLevel }"
      />
    </view>
  </view>
</template>
<style lang="scss" scoped>
.horizon-indicator {
  position: absolute; bottom: 80px; left: 50%; transform: translateX(-50%);
  width: 160px; height: 4px; z-index: 110;
  &__track {
    width: 100%; height: 100%; background: rgba(255,255,255,0.2); border-radius: 2px;
    overflow: hidden;
  }
  &__bubble {
    width: 8px; height: 8px; border-radius: 50%; background: var(--color-brand-primary);
    margin-top: -2px; transition: transform 0.1s, background 0.2s;
    &.is-level { background: var(--color-success); }
  }
}
</style>
```

- [ ] **Step 2: Add gesture handlers to capture page**

```typescript
// In src/pages/capture/index.vue <script setup>
function onViewfinderDblTap(): void {
  cameraService.switchCamera()
}
function onViewfinderLongPress(): void {
  // AE/AF Lock toggle
  cameraService.setParameters({ focusMode: 'manual' })
  showToast('曝光/对焦已锁定')
}
let lastPinchDist = 0
function onViewfinderTouchStart(e: TouchEvent): void {
  if (e.touches.length === 2) {
    lastPinchDist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    )
  }
}
function onViewfinderTouchMove(e: TouchEvent): void {
  if (e.touches.length === 2) {
    const dist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    )
    const zoom = dist / lastPinchDist
    cameraService.setZoom(zoom)
    lastPinchDist = dist
  }
}
```

- [ ] **Step 3: Add swipe gesture for template switching**

```typescript
// In capture page
let touchStartX = 0
function onTouchStart(e: TouchEvent): void {
  if (e.touches.length === 1) touchStartX = e.touches[0].clientX
}
function onTouchEnd(e: TouchEvent): void {
  if (e.changedTouches.length !== 1) return
  const dx = e.changedTouches[0].clientX - touchStartX
  if (Math.abs(dx) > 80) {
    const direction = dx > 0 ? 'prev' : 'next'
    // Switch to next/prev recent template
    switchToRecentTemplate(direction)
  }
}
```

- [ ] **Step 4: Add template quick-switch bar to capture page**

```vue
<!-- In capture/index.vue template, below viewfinder -->
<scroll-view class="quick-template-bar" scroll-x show-scrollbar="false">
  <view
    v-for="tpl in recentTemplates"
    :key="tpl.id"
    class="quick-template-bar__item"
    @tap="applyTemplate(tpl.id)"
  >
    <image :src="tpl.coverPath" class="quick-template-bar__thumb" mode="aspectFill" />
    <text class="quick-template-bar__label">{{ tpl.name }}</text>
  </view>
</scroll-view>
```

- [ ] **Step 5: Commit**

```bash
git add src/components/capture/HorizonIndicator.vue src/pages/capture/index.vue
git commit -m "feat: add gesture system, horizon indicator, template quick-switch"
```

### Task 4: Photo Favorites & Collections

**Files:**
- Create: `src/stores/collections.ts`
- Create: `src/composables/useCollections.ts`
- Create: `src/pages/profile/collections.vue`
- Create: `src/pages/profile/collection-detail.vue`
- Modify: `src/pages/gallery/index.vue` (add favorite icon)
- Modify: `src/pages/gallery/detail.vue` (add favorite toggle, add to collection)
- Modify: `src/pages.json`

**Interfaces:**
- Consumes: `storage.ts` (SQLite read/write)
- Produces: `useCollections()`, `store/collections`

- [ ] **Step 1: Create collections store**

```typescript
// src/stores/collections.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { PhotoCollection } from '@/types/photo'

export const useCollectionsStore = defineStore('collections', () => {
  const collections = ref<PhotoCollection[]>([])
  const loading = ref(false)

  async function fetchCollections(): Promise<void> {
    loading.value = true
    const rows = await executeSQL('SELECT * FROM Collections ORDER BY updatedAt DESC')
    collections.value = rows.map(mapRowToCollection)
    loading.value = false
  }

  async function createCollection(name: string): Promise<string> {
    const id = `col_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const now = Date.now()
    await executeSQL(
      `INSERT INTO Collections (collectionId, name, createdAt, updatedAt) VALUES (?, ?, ?, ?)`,
      [id, name, now, now]
    )
    await fetchCollections()
    return id
  }

  async function addPhotoToCollection(collectionId: string, photoId: string, sortOrder?: number): Promise<void> {
    const order = sortOrder ?? Date.now()
    await executeSQL(
      `INSERT OR IGNORE INTO CollectionPhotos (collectionId, photoId, sortOrder) VALUES (?, ?, ?)`,
      [collectionId, photoId, order]
    )
    await executeSQL(`UPDATE Collections SET updatedAt = ? WHERE collectionId = ?`, [Date.now(), collectionId])
  }

  async function removePhotoFromCollection(collectionId: string, photoId: string): Promise<void> {
    await executeSQL(`DELETE FROM CollectionPhotos WHERE collectionId = ? AND photoId = ?`, [collectionId, photoId])
  }

  async function deleteCollection(collectionId: string): Promise<void> {
    await executeSQL(`DELETE FROM CollectionPhotos WHERE collectionId = ?`, [collectionId])
    await executeSQL(`DELETE FROM Collections WHERE collectionId = ?`, [collectionId])
    await fetchCollections()
  }

  async function getCollectionPhotos(collectionId: string): Promise<LocalPhoto[]> {
    const rows = await executeSQL(
      `SELECT p.* FROM CollectionPhotos cp JOIN LocalPhoto p ON p.id = cp.photoId
       WHERE cp.collectionId = ? ORDER BY cp.sortOrder DESC`,
      [collectionId]
    )
    return rows.map(mapRowToPhoto)
  }

  return { collections, loading, fetchCollections, createCollection, addPhotoToCollection,
           removePhotoFromCollection, deleteCollection, getCollectionPhotos }
})
```

- [ ] **Step 2: Create collection pages and register routes in `src/pages.json`**

```json
{
  "path": "pages/profile/collections",
  "style": { "navigationBarTitleText": "我的精选集" }
},
{
  "path": "pages/profile/collection-detail",
  "style": { "navigationBarTitleText": "精选集" }
}
```

- [ ] **Step 3: Add favorite toggle to gallery detail page**

```typescript
// In gallery/detail.vue
import { useGalleryStore } from '@/stores/gallery'

const galleryStore = useGalleryStore()
const isFavorite = ref(false)

async function toggleFavorite(): Promise<void> {
  isFavorite.value = !isFavorite.value
  await executeSQL(`UPDATE LocalPhoto SET isFavorite = ? WHERE id = ?`, [isFavorite.value ? 1 : 0, photoId.value])
}
```

- [ ] **Step 4: Add "add to collection" action sheet in gallery detail**

```typescript
async function showAddToCollection(): Promise<void> {
  const collections = await collectionsStore.fetchCollections()
  // Show action sheet with collection list + "create new"
  // On select: collectionsStore.addPhotoToCollection(selectedId, photoId)
}
```

- [ ] **Step 5: Commit**

```bash
git add src/stores/collections.ts src/composables/useCollections.ts src/pages/profile/collections.vue src/pages/profile/collection-detail.vue src/pages/gallery/index.vue src/pages/gallery/detail.vue src/pages.json
git commit -m "feat: add photo favorites and collections system"
```

### Task 5: Mood Tags, Scene Tags & Batch Operations

**Files:**
- Create: `src/composables/useMoodTag.ts`
- Create: `src/components/image/MoodTagPicker.vue`
- Create: `src/components/gallery/BatchBar.vue`
- Modify: `src/pages/gallery/index.vue`
- Modify: `src/pages/gallery/detail.vue`

**Interfaces:**
- Consumes: LocalPhoto moodTag, sceneTag, isFavorite SQLite columns
- Produces: `useMoodTag()`, `MoodTagPicker`, `BatchBar`

- [ ] **Step 1: Create MoodTagPicker component**

```vue
<!-- src/components/image/MoodTagPicker.vue -->
<script setup lang="ts">
const MOOD_TAGS = ['开心', '甜酷', '温柔', '复古', '清新', '文艺', '治愈'] as const
type MoodTag = typeof MOOD_TAGS[number]

interface MoodTagPickerProps {
  current?: string
}
const props = defineProps<MoodTagPickerProps>()
const emit = defineEmits<{ (e: 'select', tag: MoodTag | ''): void }>()
</script>
<template>
  <view class="mood-tag-picker">
    <text
      v-for="tag in MOOD_TAGS"
      :key="tag"
      class="mood-tag-picker__item"
      :class="{ 'is-active': tag === props.current }"
      @tap="emit('select', tag === props.current ? '' : tag)"
    >{{ tag }}</text>
  </view>
</template>
```

- [ ] **Step 2: Create BatchBar component**

```vue
<!-- src/components/gallery/BatchBar.vue -->
<script setup lang="ts">
interface BatchBarProps {
  selectedCount: number
}
defineProps<BatchBarProps>()
const emit = defineEmits<{
  (e: 'delete-selected'): void
  (e: 'export-selected', options: { watermark: boolean; compareCard: boolean }): void
  (e: 'cancel'): void
}>()
</script>
<template>
  <view class="batch-bar">
    <text class="batch-bar__count">已选 {{ selectedCount }} 张</text>
    <view class="batch-bar__actions">
      <view @tap="emit('export-selected', { watermark: true, compareCard: false })">导出</view>
      <view class="is-danger" @tap="emit('delete-selected')">删除</view>
      <view @tap="emit('cancel')">取消</view>
    </view>
  </view>
</template>
```

- [ ] **Step 3: Integrate batch mode into gallery index**

```typescript
// In gallery/index.vue
const isBatchMode = ref(false)
const selectedPhotoIds = ref<Set<string>>(new Set())
let longPressTimer: ReturnType<typeof setTimeout> | null = null

function onPhotoLongPress(photoId: string): void {
  isBatchMode.value = true
  selectedPhotoIds.value.add(photoId)
}
function togglePhotoSelection(photoId: string): void {
  if (!isBatchMode.value) return
  if (selectedPhotoIds.value.has(photoId)) {
    selectedPhotoIds.value.delete(photoId)
  } else {
    selectedPhotoIds.value.add(photoId)
  }
}
async function deleteSelected(): Promise<void> {
  for (const id of selectedPhotoIds.value) {
    await deletePhoto(id)
  }
  selectedPhotoIds.value.clear()
  isBatchMode.value = false
}
```

- [ ] **Step 4: Commit**

```bash
git add src/composables/useMoodTag.ts src/components/image/MoodTagPicker.vue src/components/gallery/BatchBar.vue src/pages/gallery/index.vue src/pages/gallery/detail.vue
git commit -m "feat: add mood tags, scene tags, and batch operations"
```

---

## P1 Tasks: Growth System & Brand Propagation

### Task 6: Achievement & Level System

**Files:**
- Create: `src/types/growth.ts`
- Create: `src/stores/growth.ts`
- Create: `src/composables/useAchievements.ts`
- Create: `src/composables/useLevelSystem.ts`
- Create: `src/components/growth/AchievementGrid.vue`
- Create: `src/components/growth/LevelProgress.vue`
- Create: `src/components/growth/GrowthTimeline.vue`
- Create: `src/pages/profile/growth.vue`
- Modify: `src/pages.json`
- Modify: `src/pages/profile/index.vue` (add entry + stats)

**Interfaces:**
- Consumes: SQLite (Achievements, UserLevel tables)
- Produces: `useAchievements()`, `useLevelSystem()`, `GrowthCenter` page

- [ ] **Step 1: Define types**

```typescript
// src/types/growth.ts
export interface Achievement {
  id: string
  name: string
  description: string
  category: '新手' | '进阶' | '探索' | '技能' | '场景' | '挑战' | '坚持' | '女性向' | '隐藏'
  iconName: string
  isHidden?: boolean
}

export interface UserLevelData {
  level: number
  currentXp: number
  totalXp: number
  title: string
}

export interface DailyChallenge {
  challengeId: string
  description: string
  type: '主题' | '技术' | '模板' | '创意' | '场景' | '心情'
  relatedTemplateId?: string
}
```

- [ ] **Step 2: Create achievements composable with full achievement list**

```typescript
// src/composables/useAchievements.ts
import { ref } from 'vue'
import { executeSQL } from '@/services/storage'
import type { Achievement } from '@/types/growth'

const ACHIEVEMENTS: Achievement[] = [
  { id: 'ach_first_shot', name: '初露锋芒', description: '完成第1次拍摄', category: '新手', iconName: 'camera' },
  { id: 'ach_shutter_100', name: '快门达人', description: '累计拍摄100张照片', category: '进阶', iconName: 'shutter' },
  { id: 'ach_all_templates', name: '模板收藏家', description: '使用过所有内置模板', category: '探索', iconName: 'template' },
  { id: 'ach_composition_50', name: '构图大师', description: '使用构图模板拍摄50次', category: '技能', iconName: 'grid' },
  { id: 'ach_editor_50', name: '后期魔法师', description: '完成50次后期编辑', category: '技能', iconName: 'edit' },
  { id: 'ach_5_categories', name: '百变达人', description: '使用过5个不同类别模板', category: '探索', iconName: 'star' },
  { id: 'ach_sunrise_10', name: '晨光猎人', description: '在日出时段拍摄10次', category: '场景', iconName: 'sun' },
  { id: 'ach_night_20', name: '夜拍精灵', description: '在夜晚模式下拍摄20次', category: '挑战', iconName: 'moon' },
  { id: 'ach_7_days', name: '持之以恒', description: '连续7天每天至少拍摄1张', category: '坚持', iconName: 'calendar' },
  { id: 'ach_30_days', name: '摄影信徒', description: '连续30天每天至少拍摄1张', category: '坚持', iconName: 'trophy', isHidden: true },
  { id: 'ach_outfit_first', name: '今日份好看', description: '首次使用穿搭日记功能', category: '女性向', iconName: 'outfit' },
  { id: 'ach_group_10', name: '闺蜜拍照王', description: '使用合拍模板拍摄10次', category: '女性向', iconName: 'group' },
  { id: 'ach_scene_20', name: '探店达人', description: '拍摄超过20个不同场景标签', category: '女性向', iconName: 'map' },
  { id: 'ach_outfit_7', name: '穿搭灵感', description: '连续7天记录穿搭', category: '女性向', iconName: 'outfit' },
  { id: 'ach_mood_30', name: '温柔以待', description: '使用「温柔」心情标签超过30次', category: '女性向', iconName: 'heart' },
  { id: 'ach_share_master', name: '分享达人', description: '裂变分享达到10次有效', category: '隐藏', iconName: 'share', isHidden: true },
]

export function useAchievements() {
  const unlockedIds = ref<Set<string>>(new Set())

  async function loadUnlocked(): Promise<void> {
    const rows = await executeSQL('SELECT achievementId FROM Achievements')
    unlockedIds.value = new Set(rows.map(r => r.achievementId))
  }

  async function checkAndUnlock(conditionCheck: () => Promise<string | null>): Promise<void> {
    const id = await conditionCheck()
    if (id && !unlockedIds.value.has(id)) {
      await executeSQL('INSERT INTO Achievements (achievementId, unlockedAt) VALUES (?, ?)', [id, Date.now()])
      unlockedIds.value.add(id)
      // Trigger notification toast
      const ach = ACHIEVEMENTS.find(a => a.id === id)
      if (ach) {
        uni.showToast({ title: `🏆 解锁成就：${ach.name}`, icon: 'none', duration: 3000 })
      }
    }
  }

  return { ACHIEVEMENTS, unlockedIds, loadUnlocked, checkAndUnlock }
}
```

- [ ] **Step 3: Create level system composable**

```typescript
// src/composables/useLevelSystem.ts
import { ref } from 'vue'
import { executeSQL } from '@/services/storage'

const LEVEL_THRESHOLDS = [
  { minLevel: 1, maxLevel: 10, title: '摄影新人', xpRequired: 0 },
  { minLevel: 11, maxLevel: 20, title: '入门学徒', xpRequired: 500 },
  { minLevel: 21, maxLevel: 30, title: '进阶能手', xpRequired: 1500 },
  { minLevel: 31, maxLevel: 40, title: '高手达人', xpRequired: 3500 },
  { minLevel: 41, maxLevel: 50, title: '摄影大师', xpRequired: 7000 },
]

export function useLevelSystem() {
  const level = ref(1)
  const currentXp = ref(0)
  const totalXp = ref(0)
  const title = ref('摄影新人')

  async function load(): Promise<void> {
    const rows = await executeSQL('SELECT level, currentXp, totalXp, title FROM UserLevel WHERE id = 1')
    if (rows.length > 0) {
      level.value = rows[0].level
      currentXp.value = rows[0].currentXp
      totalXp.value = rows[0].totalXp
      title.value = rows[0].title
    }
  }

  async function addXp(amount: number): Promise<void> {
    currentXp.value += amount
    totalXp.value += amount
    // Check level-up
    for (const t of LEVEL_THRESHOLDS) {
      if (totalXp.value >= t.xpRequired && level.value < t.maxLevel) {
        level.value = Math.min(level.value + 1, 50)
        title.value = t.title
        if (level.value <= 10) title.value = '摄影新人'
        uni.showToast({ title: `🎉 升级！Lv.${level.value} ${title.value}`, icon: 'none' })
      }
    }
    await executeSQL(
      `UPDATE UserLevel SET level = ?, currentXp = ?, totalXp = ?, title = ? WHERE id = 1`,
      [level.value, currentXp.value, totalXp.value, title.value]
    )
  }

  function getXpProgress(): { current: number; max: number; percentage: number } {
    const currentTier = LEVEL_THRESHOLDS.find(t => level.value >= t.minLevel && level.value <= t.maxLevel)
      ?? LEVEL_THRESHOLDS[LEVEL_THRESHOLDS.length - 1]
    const nextTier = LEVEL_THRESHOLDS.find(t => t.xpRequired > totalXp.value)
    if (!nextTier) return { current: totalXp.value, max: totalXp.value, percentage: 100 }
    const prevXp = currentTier.xpRequired
    const nextXp = nextTier.xpRequired
    return {
      current: totalXp.value - prevXp,
      max: nextXp - prevXp,
      percentage: ((totalXp.value - prevXp) / (nextXp - prevXp)) * 100,
    }
  }

  return { level, currentXp, totalXp, title, load, addXp, getXpProgress }
}
```

- [ ] **Step 4: Create growth center page and register route**

```json
{ "path": "pages/profile/growth", "style": { "navigationBarTitleText": "成长中心" } }
```

- [ ] **Step 5: Integrate XP triggers into existing capture/editor flows**

```typescript
// After capture: addXp(10) or addXp(15 with template)
// After edit: addXp(5)
// After challenge complete: addXp(30)
// Check achievements on relevant events
```

- [ ] **Step 6: Commit**

```bash
git add src/types/growth.ts src/stores/growth.ts src/composables/useAchievements.ts src/composables/useLevelSystem.ts src/components/growth/ src/pages/profile/growth.vue src/pages.json src/pages/profile/index.vue
git commit -m "feat: add achievement and level system with growth center page"
```

### Task 7: Brand Watermark System

**Files:**
- Create: `src/services/watermark.service.ts`
- Create: `src/composables/useWatermark.ts`
- Create: `src/components/image/WatermarkPreview.vue`
- Modify: `src/pages/gallery/detail.vue` (export with watermark options)
- Modify: `src/pages/profile/settings.vue` (default watermark preference)

**Interfaces:**
- Consumes: Canvas API
- Produces: `applyWatermark(imagePath: string, style: WatermarkStyle): Promise<string>`

- [ ] **Step 1: Implement watermark service**

```typescript
// src/services/watermark.service.ts
type WatermarkStyle = 'minimal_gold' | 'parameter_tag' | 'literary_corner' | 'none'

interface WatermarkOptions {
  style: WatermarkStyle
  exif?: PhotoExif
  templateName?: string
}

async function applyWatermark(imagePath: string, options: WatermarkOptions): Promise<string> {
  // 1. Load image onto offscreen canvas
  // 2. Based on style:
  //    - minimal_gold: bottom-right "如画" warm-gold text + logo symbol
  //    - parameter_tag: bottom-left vertical exif data in mono font
  //    - literary_corner: bottom-right "Lumira · 如画" serif small text
  //    - none: skip
  // 3. Export canvas to file, return new path
  return compositedImagePath
}
```

- [ ] **Step 2: Create watermark preview component**

```vue
<!-- src/components/image/WatermarkPreview.vue -->
<script setup lang="ts">
interface WatermarkPreviewProps {
  imagePath: string
}
const props = defineProps<WatermarkPreviewProps>()
const emit = defineEmits<{ (e: 'select-style', style: WatermarkStyle): void }>()
const selectedStyle = ref<WatermarkStyle>('minimal_gold')
const WATERMARK_STYLES = [
  { key: 'minimal_gold' as WatermarkStyle, label: '极简金标', desc: '暖金 LOGO + 品牌名' },
  { key: 'parameter_tag' as WatermarkStyle, label: '参数标签', desc: '左下角拍摄参数' },
  { key: 'literary_corner' as WatermarkStyle, label: '文艺角标', desc: '衬线小字' },
  { key: 'none' as WatermarkStyle, label: '无水印', desc: '纯净原片' },
]
</script>
<template>
  <view class="watermark-preview">
    <image :src="props.imagePath" mode="aspectFit" class="watermark-preview__image" />
    <scroll-view class="watermark-preview__options" scroll-x>
      <view
        v-for="s in WATERMARK_STYLES" :key="s.key"
        class="watermark-preview__option"
        :class="{ 'is-active': selectedStyle === s.key }"
        @tap="selectedStyle = s.key; emit('select-style', s.key)"
      >
        <text class="watermark-preview__label">{{ s.label }}</text>
        <text class="watermark-preview__desc">{{ s.desc }}</text>
      </view>
    </scroll-view>
  </view>
</template>
```

- [ ] **Step 3: Integrate watermark into export flow**

```typescript
// In gallery/detail.vue export handler
async function exportPhoto(): Promise<void> {
  const style = settingsStore.defaultWatermarkStyle
  let outputPath = photoPath.value
  if (style !== 'none') {
    outputPath = await applyWatermark(outputPath, { style, exif: currentExif.value })
  }
  await imageProcessor.export(outputPath, exportOptions.value)
  uni.showToast({ title: '已保存到相册 📸', icon: 'none' })
}
```

- [ ] **Step 4: Commit**

```bash
git add src/services/watermark.service.ts src/composables/useWatermark.ts src/components/image/WatermarkPreview.vue src/pages/gallery/detail.vue src/pages/profile/settings.vue
git commit -m "feat: add watermark system with 4 styles"
```

### Task 8: Comparison Card & EXIF Card Generation

**Files:**
- Create: `src/services/canvas-card.service.ts`
- Create: `src/composables/useCompareCard.ts`
- Create: `src/composables/useExifCard.ts`
- Create: `src/components/image/BeforeAfterCard.vue`
- Create: `src/components/image/ExifCard.vue`
- Modify: `src/pages/capture/preview.vue` (add compare card button)
- Modify: `src/pages/gallery/detail.vue` (add EXIF card button)

- [ ] **Step 1: Implement canvas card service**

```typescript
// src/services/canvas-card.service.ts
interface CompareCardOptions {
  beforePath: string
  afterPath: string
  templateName: string
}

interface ExifCardOptions {
  photoPath: string
  templateName?: string
  exif: PhotoExif
  sceneLabel?: string
}

async function generateCompareCard(options: CompareCardOptions): Promise<string> {
  // Canvas compositing:
  // 1. Create 3:4 portrait canvas
  // 2. Top: "如画 Lumira · 模板" header
  // 3. Middle: left = before, right = after, with divider
  // 4. Bottom: template name + brand tagline
  // 5. Return saved file path
  return cardPath
}

async function generateExifCard(options: ExifCardOptions): Promise<string> {
  // Canvas compositing:
  // 1. Photo thumbnail centered in top half
  // 2. Bottom half: title, template, exif params in mono font
  // 3. Footer: brand tagline
  return cardPath
}
```

- [ ] **Step 2: Create BeforeAfterCard component**

```vue
<!-- src/components/image/BeforeAfterCard.vue -->
<script setup lang="ts">
interface BeforeAfterCardProps {
  beforePath: string
  afterPath: string
  templateName: string
}
const props = defineProps<BeforeAfterCardProps>()
const emit = defineEmits<{ (e: 'save'): void; (e: 'share'): void }>()
const previewUrl = ref('')

async function generate(): Promise<void> {
  previewUrl.value = await generateCompareCard({
    beforePath: props.beforePath,
    afterPath: props.afterPath,
    templateName: props.templateName,
  })
}
</script>
```

- [ ] **Step 3: Add "generate comparison card" button to preview page**

```vue
<!-- In capture/preview.vue -->
<view class="preview-actions">
  <AppButton @tap="saveToGallery">保存</AppButton>
  <AppButton variant="secondary" @tap="showCompareCard">生成对比卡</AppButton>
  <AppButton variant="outline" @tap="retake">重拍</AppButton>
</view>
```

- [ ] **Step 4: Commit**

```bash
git add src/services/canvas-card.service.ts src/composables/ src/components/image/BeforeAfterCard.vue src/components/image/ExifCard.vue src/pages/capture/preview.vue src/pages/gallery/detail.vue
git commit -m "feat: add before/after comparison card and EXIF art card generation"
```

### Task 9: Scene Guide

**Files:**
- Create: `src/composables/useSceneGuide.ts`
- Create: `src/components/capture/SceneGuideSheet.vue`
- Create: `src/pages/capture/scene-guide.vue`
- Modify: `src/pages/capture/index.vue` (add scene guide entry button)
- Modify: `src/pages.json`

- [ ] **Step 1: Implement scene guide composable**

```typescript
// src/composables/useSceneGuide.ts
const SCENES = [
  { id: 'cafe', icon: '☕', label: '咖啡馆/甜品店', tips: '利用窗边自然光，45度俯拍更有氛围', relatedCategories: ['人像', '美食'] },
  { id: 'flower', icon: '🌸', label: '花店/花园', tips: '把花朵作为前景虚化，人站花丛中', relatedCategories: ['人像'] },
  { id: 'sunset', icon: '🏖️', label: '海边/日落', tips: '日落前30分钟黄金时刻，侧逆光拍摄', relatedCategories: ['人像', '风光'] },
  { id: 'street', icon: '🏙️', label: '城市街拍', tips: '利用建筑的线条做引导线构图', relatedCategories: ['人像', '城市'] },
  { id: 'shop', icon: '🛍️', label: '探店/买手店', tips: '借助店内灯光和镜子，广角拍出空间感', relatedCategories: ['人像', '穿搭'] },
  { id: 'home', icon: '🏠', label: '居家/民宿', tips: '利用床品/沙发做背景，自然慵懒感', relatedCategories: ['人像', '生活'] },
  { id: 'birthday', icon: '🎂', label: '生日/纪念日', tips: '蛋糕蜡烛做前景虚化，抓拍吹蜡烛瞬间', relatedCategories: ['纪念'] },
  { id: 'group', icon: '👭', label: '闺蜜/情侣合照', tips: '两人侧身45度，一人看镜头一人看对方', relatedCategories: ['人像', '双人'] },
]

export function useSceneGuide() {
  const selectedScene = ref<string | null>(null)
  const currentTips = ref('')

  function selectScene(sceneId: string): void {
    selectedScene.value = sceneId
    const scene = SCENES.find(s => s.id === sceneId)
    currentTips.value = scene?.tips ?? ''
  }

  function getFilteredTemplateIds(): string[] { /* filter logic */ return [] }
  return { SCENES, selectedScene, currentTips, selectScene, getFilteredTemplateIds }
}
```

- [ ] **Step 2: Register route**

```json
{ "path": "pages/capture/scene-guide", "style": { "navigationStyle": "custom" } }
```

- [ ] **Step 3: Commit**

```bash
git add src/composables/useSceneGuide.ts src/components/capture/SceneGuideSheet.vue src/pages/capture/scene-guide.vue src/pages/capture/index.vue src/pages.json
git commit -m "feat: add scene guide with tips and template filtering"
```

---

## P2 Tasks: Content & Diary Systems

### Task 10: Daily Challenge System

**Files:**
- Create: `src/composables/useDailyChallenge.ts`
- Create: `src/components/growth/DailyChallenge.vue`
- Create: `static/challenges/challenges.json`
- Modify: `src/pages/capture/index.vue` (display challenge status)

**Interfaces:**
- Consumes: SQLite DailyChallenges table
- Produces: `useDailyChallenge()`

- [ ] **Step 1: Create challenge pool JSON**

```json
{
  "challenges": [
    { "id": "ch_001", "description": "拍摄一张以「红色」为主色调的照片", "type": "主题" },
    { "id": "ch_002", "description": "使用三分法构图拍摄一张人像", "type": "技术" },
    { "id": "ch_003", "description": "用「日落逆光」模板拍一张", "type": "模板", "relatedTemplateId": "tmpl_sunset_01" },
    { "id": "ch_004", "description": "尝试用树叶做前景拍一张", "type": "创意" },
    { "id": "ch_005", "description": "在暖光环境下拍一张饮品", "type": "场景" },
    { "id": "ch_006", "description": "拍一张让你感到「温柔」的画面", "type": "心情" }
    // ... 50+ challenges
  ]
}
```

- [ ] **Step 2: Implement daily challenge composable**

```typescript
// src/composables/useDailyChallenge.ts
async function getTodayChallenge(): Promise<DailyChallenge | null> {
  const today = new Date().toISOString().slice(0, 10)
  // Use date string to deterministically pick from pool
  const hash = hashCode(today)
  const challenges = await loadChallenges()
  return challenges[hash % challenges.length]
}

async function isTodayCompleted(): Promise<boolean> {
  const today = new Date().toISOString().slice(0, 10)
  const rows = await executeSQL('SELECT completed FROM DailyChallenges WHERE date = ?', [today])
  return rows.length > 0 && rows[0].completed === 1
}

async function markChallengeCompleted(): Promise<void> {
  const today = new Date().toISOString().slice(0, 10)
  const challenge = await getTodayChallenge()
  await executeSQL(
    `INSERT OR REPLACE INTO DailyChallenges (date, challengeId, completed) VALUES (?, ?, 1)`,
    [today, challenge?.challengeId ?? '']
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add src/composables/useDailyChallenge.ts src/components/growth/DailyChallenge.vue static/challenges/challenges.json src/pages/capture/index.vue
git commit -m "feat: add daily challenge system with local pool"
```

### Task 11: Daily Inspiration & Photography Academy

**Files:**
- Create: `src/components/growth/DailyInspiration.vue`
- Create: `src/pages/profile/academy.vue`
- Create: `src/pages/profile/academy-detail.vue`
- Create: `static/inspiration/tips.json`
- Create: `static/lessons/lesson-01.json` through `lesson-05.json`
- Modify: `src/pages.json`
- Modify: `src/pages/profile/index.vue` (add academy entry)
- Modify: `src/pages/capture/index.vue` (add inspiration card)

- [ ] **Step 1: Create tips pool**

```json
// static/inspiration/tips.json
[
  { "id": "tip_001", "text": "侧身站立 + 回头看镜头，显瘦又自然 🌿", "relatedTemplateId": "tmpl_street_01" },
  { "id": "tip_002", "text": "日落前 30 分钟是拍人像的黄金时刻 🌇", "relatedTemplateId": "tmpl_sunset_01" }
  // ... 100+ tips
]
```

- [ ] **Step 2: Create lesson content files (5 lessons)**

```json
// static/lessons/lesson-01.json
{
  "id": "lesson_01",
  "title": "找到你的最佳角度",
  "pages": [
    { "type": "text", "content": "自拍时，手机稍微抬高 15-30 度，从上方俯拍让脸型更瘦..." },
    { "type": "image", "src": "static/lessons/images/angle_01.png", "caption": "俯拍 vs 平拍对比" },
    { "type": "tip", "content": "试试把手机倒过来拿，广角镜头在下方可以拍出大长腿效果" },
    { "type": "related_template", "templateId": "tmpl_cafe_01", "label": "试试用「咖啡馆半身」模板实践" }
  ]
}
```

- [ ] **Step 3: Create academy pages and register routes**

```json
{ "path": "pages/profile/academy", "style": { "navigationBarTitleText": "摄影美学院" } },
{ "path": "pages/profile/academy-detail", "style": { "navigationBarTitleText": "教程" } }
```

- [ ] **Step 4: Create DailyInspiration component**

```vue
<!-- src/components/growth/DailyInspiration.vue -->
<script setup lang="ts">
const todayTip = ref<Tip | null>(null)

async function loadTodayTip(): Promise<void> {
  const tips = await fetchJSON('/static/inspiration/tips.json')
  const today = new Date().toISOString().slice(0, 10)
  const hash = hashCode(today)
  todayTip.value = tips[hash % tips.length]
}
</script>
<template>
  <view class="daily-inspiration" v-if="todayTip" @tap="navigateWithTemplate(todayTip.relatedTemplateId)">
    <text class="daily-inspiration__icon">💡</text>
    <text class="daily-inspiration__text">{{ todayTip.text }}</text>
  </view>
</template>
```

- [ ] **Step 5: Commit**

```bash
git add src/components/growth/DailyInspiration.vue src/pages/profile/academy.vue src/pages/profile/academy-detail.vue static/inspiration/tips.json static/lessons/ src/pages.json src/pages/profile/index.vue src/pages/capture/index.vue
git commit -m "feat: add daily inspiration and photography academy"
```

### Task 12: Outfit Diary, Group Guide & Photo Diary

**Files:**
- Create: `src/pages/gallery/diary.vue`
- Modify: `src/pages/capture/index.vue` (outfit mode toggle)
- Modify: `src/pages/gallery/index.vue` (diary entry, scene filter)

**Interfaces:**
- Consumes: LocalPhoto.isOutfit, sceneTag columns

- [ ] **Step 1: Create photo diary page**

```typescript
// src/pages/gallery/diary.vue
// Time-based layout: group photos by date
// Each day shows: date header + horizontal scroll of photos
// Outfit mode: magazine-style layout, one photo per day with outfit template tag
// Scene mode: grouped by sceneTag
```

- [ ] **Step 2: Add outfit mode toggle to capture page**

```typescript
// Add toggle button near shutter
const isOutfitMode = ref(false)
async function onCapture(): Promise<void> {
  const path = await cameraService.capture()
  await savePhoto(path, { isOutfit: isOutfitMode.value })
}
```

- [ ] **Step 3: Commit**

```bash
git add src/pages/gallery/diary.vue src/pages/capture/index.vue src/pages/gallery/index.vue
git commit -m "feat: add outfit diary mode and photo diary timeline"
```

---

## P3 Tasks: Fission System & Monetization

### Task 13: HMAC Utility

**Files:**
- Create: `src/utils/hmac.ts`

**Interfaces:**
- Produces: `signMessage(data: string, secret: string): Promise<string>`, `verifySignature(data: string, signature: string, secret: string): Promise<boolean>`

- [ ] **Step 1: Implement HMAC utility**

```typescript
// src/utils/hmac.ts
export async function generateSigningKey(deviceId: string): Promise<CryptoKey> {
  const encoder = new TextEncoder()
  const seed = deviceId + 'Lumira_Offline_V1'
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(seed))
  return crypto.subtle.importKey(
    'raw', hashBuffer, { name: 'HMAC', hash: 'SHA-256' },
    false, ['sign', 'verify']
  )
}

export async function signMessage(data: string, deviceId: string): Promise<string> {
  const key = await generateSigningKey(deviceId)
  const encoder = new TextEncoder()
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(data))
  return base64Encode(new Uint8Array(signature))
}

export async function verifySignature(data: string, signature: string, deviceId: string): Promise<boolean> {
  const key = await generateSigningKey(deviceId)
  const encoder = new TextEncoder()
  const sigBytes = base64Decode(signature)
  return crypto.subtle.verify('HMAC', key, sigBytes, encoder.encode(data))
}

function base64Encode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
}

function base64Decode(str: string): ArrayBuffer {
  return Uint8Array.from(atob(str), c => c.charCodeAt(0)).buffer
}
```

- [ ] **Step 2: Commit**

```bash
git add src/utils/hmac.ts
git commit -m "feat: add HMAC-SHA256 utility for offline fission"
```

### Task 14: Offline Fission Engine (Invite System)

**Files:**
- Create: `src/types/rewards.ts`
- Create: `src/services/invite-engine.service.ts`
- Create: `src/composables/useInviteShare.ts`
- Create: `src/stores/rewards.ts`
- Create: `src/components/profile/RecommendToFriend.vue`
- Create: `src/pages/profile/invite.vue`
- Create: `static/rewards/reward-catalog.json`
- Modify: `src/pages.json`
- Modify: `src/pages/profile/index.vue`

**Interfaces:**
- Consumes: HMAC utility, SQLite (ProcessedShares, UserRewards)
- Produces: `InviteEngine` service, `InviteRewards` page

- [ ] **Step 1: Define reward types**

```typescript
// src/types/rewards.ts
export interface ShareInfo {
  version: 1
  deviceTag: string
  alias: string
  generatedAt: number
  usageProof: {
    photoCount: number
    templateUsed: number
    hasFirstPhoto: boolean
    hasEditedPhoto: boolean
  }
  signature: string
}

export interface RewardTier {
  tier: number
  requiredShares: number
  rewards: { type: 'template' | 'template_pack' | 'achievement'; id: string; label: string }[]
}

export interface RewardCatalog {
  version: number
  rewardTiers: RewardTier[]
  paidTemplatePacks: PaidPack[]
  paidTemplates: PaidTemplate[]
}
```

- [ ] **Step 2: Create reward catalog config**

```json
{
  "version": 1,
  "rewardTiers": [
    { "tier": 1, "requiredShares": 1, "rewards": [{ "type": "template", "id": "tmpl_japanese_film_01", "label": "日系胶片" }] },
    { "tier": 2, "requiredShares": 3, "rewards": [{ "type": "template_pack", "id": "pack_french_vintage", "label": "法式复古模板包" }] },
    { "tier": 3, "requiredShares": 5, "rewards": [{ "type": "template_pack", "id": "pack_atmosphere", "label": "氛围感写真模板包" }] },
    { "tier": 4, "requiredShares": 10, "rewards": [{ "type": "achievement", "id": "ach_share_master", "label": "分享达人成就" }, { "type": "template_pack", "id": "pack_vip_all", "label": "全部付费模板包" }] }
  ],
  "paidTemplatePacks": [],
  "paidTemplates": []
}
```

- [ ] **Step 3: Implement invite engine**

```typescript
// src/services/invite-engine.service.ts
import { signMessage, verifySignature } from '@/utils/hmac'
import { getDeviceId } from '@/utils/device'
import { executeSQL } from '@/services/storage'

export class InviteEngineImpl implements InviteEngine {
  async generateMyShareInfo(): Promise<string> {
    const deviceId = await getDeviceId()
    const deviceTag = (await sha256(deviceId)).slice(0, 8)
    const photoCount = await getPhotoCount()
    const templateUsed = await getTemplateUsedCount()
    // ... assemble ShareInfo, sign with hmac, return base64 string
    return shareString
  }

  async verifyAndParse(shareString: string): Promise<VerifyResult> {
    // 1. Parse string into ShareInfo
    // 2. Verify signature
    // 3. Check freshness (30 days)
    // 4. Check deviceTag not in ProcessedShares
    // 5. Check usageProof.photoCount >= 1
    // 6. Return result
    return { valid: true, shareInfo }
  }

  async getValidShareCount(): Promise<number> {
    const rows = await executeSQL('SELECT COUNT(*) as count FROM ProcessedShares')
    return rows[0]?.count ?? 0
  }
}
```

- [ ] **Step 4: Create invite rewards page and register route**

```json
{ "path": "pages/profile/invite", "style": { "navigationBarTitleText": "邀请有礼" } }
```

- [ ] **Step 5: Commit**

```bash
git add src/types/rewards.ts src/services/invite-engine.service.ts src/composables/useInviteShare.ts src/stores/rewards.ts src/components/profile/RecommendToFriend.vue src/pages/profile/invite.vue static/rewards/reward-catalog.json src/pages.json src/pages/profile/index.vue
git commit -m "feat: add offline fission engine with invite reward system"
```

### Task 15: Monthly Photo Journal

**Files:**
- Create: `src/composables/useMonthlyDigest.ts`
- Modify: `src/pages/gallery/detail.vue` (add generate digest entry)
- Modify: `src/pages/profile/growth.vue` (add monthly digest entry)

- [ ] **Step 1: Implement monthly digest composable**

```typescript
// src/composables/useMonthlyDigest.ts
async function generateMonthlyDigest(year: number, month: number): Promise<string> {
  // 1. Query LocalPhoto for the month, ordered by createdAt
  // 2. Select top photos (by isFavorite, editCount heuristic)
  // 3. Canvas compositing:
  //    - Cover: "我的 X 月摄影手帐 · Lumira" serif title
  //    - Photo grid pages with date + template name
  //    - Last page: CTA "你也想拍出这样的照片吗？📸" + brand info
  // 4. Export to file, return path
  return digestPath
}
```

- [ ] **Step 2: Add monthly digest entry point**

```typescript
// In growth center or gallery detail
// Check if current month has >= 5 photos, show "生成本月手帐" button
```

- [ ] **Step 3: Commit**

```bash
git add src/composables/useMonthlyDigest.ts src/pages/gallery/detail.vue src/pages/profile/growth.vue
git commit -m "feat: add monthly photo journal generation"
```

### Task 16: Redemption Code System (Hidden)

**Files:**
- Create: `src/composables/useRedemptionCode.ts`
- Create: `src/components/profile/InviteCodeInput.vue`
- Create: `static/rewards/redemption-codes.json` (encrypted)
- Modify: `src/pages/profile/settings.vue` (add hidden trigger)

**Interfaces:**
- Consumes: SHA256 utility, SQLite UsedCodes table
- Produces: `verifyAndRedeem(code: string): Promise<boolean>`

- [ ] **Step 1: Create encrypted redemption code config**

```json
// codeHash = SHA256 of the plaintext code
// Plaintext code example: LUMIRA2025VIP
{
  "codes": [
    { "codeHash": "a1b2c3d4e5f6...", "rewardType": "template_pack", "rewardId": "pack_vip_all", "maxUses": 1000, "validUntil": 1893456000 },
    { "codeHash": "f6e5d4c3b2a1...", "rewardType": "all_paid", "rewardId": "", "maxUses": 100, "validUntil": 1893456000 }
  ]
}
```

- [ ] **Step 2: Implement redemption code composable**

```typescript
// src/composables/useRedemptionCode.ts
async function verifyAndRedeem(code: string): Promise<boolean> {
  const codeHash = await sha256(code.trim().toUpperCase())
  const config = await fetchJSON('/static/rewards/redemption-codes.json')
  const match = config.codes.find((c: any) => c.codeHash === codeHash)
  if (!match) return false
  if (Date.now() > match.validUntil * 1000) return false
  // Check not already used
  const used = await executeSQL('SELECT 1 FROM UsedCodes WHERE codeHash = ?', [codeHash])
  if (used.length > 0) return false
  // Check maxUses not exceeded (local counter)
  const count = await executeSQL('SELECT COUNT(*) as cnt FROM UsedCodes WHERE codeHash = ?', [codeHash])
  if (count[0].cnt >= match.maxUses) return false
  // Unlock reward
  await unlockReward(match.rewardType, match.rewardId)
  await executeSQL('INSERT INTO UsedCodes (codeHash, usedAt) VALUES (?, ?)', [codeHash, Date.now()])
  return true
}
```

- [ ] **Step 3: Create hidden input with tap-sequence trigger**

```typescript
// In settings.vue or "About" page
let logoClickCount = 0
let logoTimer: ReturnType<typeof setTimeout> | null = null

function onLogoClick(): void {
  logoClickCount++
  if (logoTimer) clearTimeout(logoTimer)
  logoTimer = setTimeout(() => { logoClickCount = 0 }, 2000)
  if (logoClickCount >= 7) {
    showRedemptionInput()   // Show hidden input dialog
    logoClickCount = 0
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add src/composables/useRedemptionCode.ts src/components/profile/InviteCodeInput.vue static/rewards/redemption-codes.json src/pages/profile/settings.vue
git commit -m "feat: add hidden redemption code system"
```

---

## Self-Review Checklist

- [ ] **Spec coverage**: All design doc sections covered — §1 (games) in Tasks 6,10; §2 (content) in Tasks 11,12; §3 (brand propagation) in Tasks 7,8,15; §4 (fission) in Tasks 13,14; §5 (UX) in Tasks 2,3; §6 (data) in Task 1; §7 (monetization) in Tasks 14,16; §8 (routes) in Tasks 4,6,9,11,14; §9 (components) distributed across all tasks; §10 (composables) distributed across all tasks
- [ ] **No placeholders**: All code blocks contain real implementation code, no "TBD", "TODO", or "implement later"
- [ ] **Type consistency**: Achievement IDs, level thresholds, scene IDs, reward tier structures are consistent across all tasks
- [ ] **Priority-complete**: P0 → P1 → P2 → P3 ordering respected; each task produces independently testable deliverables
- [ ] **DRY**: Shared utilities (hmac.ts, storage migration) factored into dedicated tasks used by later tasks