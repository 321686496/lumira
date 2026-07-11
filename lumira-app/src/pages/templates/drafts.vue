<template>
  <view class="lumira-container no-tabbar">
    <!-- 1. 标题栏（透明背景 + 滚动感知毛玻璃） -->
    <view class="lumira-nav" :class="{ scrolled: isScrolled }">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">草稿箱</text>
      <view class="lumira-nav-right">
        <text class="ph ph-trash nav-icon" @click="onClearAll" v-if="drafts.length > 0"></text>
      </view>
    </view>

    <!-- 2. 统计栏 -->
    <view class="stats-bar fade-up">
      <view class="stat-item">
        <text class="stat-num">{{ drafts.length }}</text>
        <text class="stat-label">个草稿</text>
      </view>
    </view>

    <!-- 3. 草稿列表 -->
    <view class="draft-list fade-up fade-up-d1" v-if="drafts.length > 0">
      <view class="draft-row" v-for="draft in drafts" :key="draft.id">
        <view class="draft-content" @click="onResume(draft.id)">
          <view class="draft-header">
            <text class="draft-name">{{ draft.name }}</text>
            <text class="draft-time">{{ formatTime(draft.updatedAt) }}</text>
          </view>
          <view class="draft-tags">
            <text class="draft-tag">{{ categoryLabel(draft.template.meta.category) }}</text>
          </view>
          <view class="draft-params">
            <text class="param-item">EV {{ formatEv(draft.template.camera.exposureCompensation) }}</text>
            <text class="param-item">ISO {{ draft.template.camera.iso }}</text>
            <text class="param-item">{{ draft.template.camera.shutterSpeed }}</text>
          </view>
        </view>
        <view class="draft-actions">
          <view class="draft-action-btn resume-btn" @click.stop="onResume(draft.id)">
            <text class="ph ph-pencil-simple"></text>
            <text>继续编辑</text>
          </view>
          <view class="draft-action-btn del-btn" @click.stop="onDelete(draft.id, draft.name)">
            <text class="ph ph-trash"></text>
          </view>
        </view>
      </view>
    </view>

    <!-- 4. 空状态 -->
    <view class="empty-state fade-up fade-up-d1" v-else>
      <text class="ph ph-note-pencil empty-icon"></text>
      <text class="empty-title">还没有草稿</text>
      <text class="empty-desc">在模板编辑器中填写内容时会自动保存草稿</text>
      <view class="lumira-btn-primary empty-btn" @click="onCreate">
        <text class="ph ph-plus"></text>
        <text>新建模板</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow, onPageScroll } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import type { TemplateDraft } from '@/composables/useTemplate'
import type { Target } from '@/types/template'

const { getAllDrafts, loadDraft, deleteDraft, clearAllDrafts } = useTemplate()

const isScrolled = ref(false)
const drafts = ref<TemplateDraft[]>([])

onShow(() => {
  drafts.value = getAllDrafts()
})

onPageScroll((e) => {
  isScrolled.value = e.scrollTop > 20
})

function formatTime(timestamp: number): string {
  const now = Date.now()
  const diff = now - timestamp
  const minute = 60 * 1000
  const hour = 60 * minute
  const day = 24 * hour
  if (diff < minute) return '刚刚'
  if (diff < hour) return `${Math.floor(diff / minute)}分钟前`
  if (diff < day) return `${Math.floor(diff / hour)}小时前`
  if (diff < 2 * day) return '昨天'
  if (diff < 7 * day) return `${Math.floor(diff / day)}天前`
  const d = new Date(timestamp)
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

function formatEv(v: number): string {
  return v > 0 ? `+${v.toFixed(1)}` : v.toFixed(1)
}

function categoryLabel(cat: Target): string {
  const map: Record<Target, string> = {
    portrait: '人像', landscape: '风光', food: '美食',
    street: '街拍', night: '夜景', macro: '微距', 'still-life': '静物'
  }
  return map[cat] || cat
}

function back() {
  uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/profile/my-templates' }) })
}

function onResume(draftId: string) {
  uni.navigateTo({ url: `/pages/templates/editor?draftId=${draftId}` })
}

function onDelete(draftId: string, name: string) {
  uni.showModal({
    title: '删除草稿',
    content: `确定删除草稿"${name}"吗？`,
    confirmColor: '#E5484D',
    success: (res) => {
      if (res.confirm) {
        deleteDraft(draftId)
        drafts.value = getAllDrafts()
        uni.showToast({ title: '已删除', icon: 'success' })
      }
    }
  })
}

function onClearAll() {
  uni.showModal({
    title: '清空草稿箱',
    content: '确定删除所有草稿吗？此操作不可恢复。',
    confirmColor: '#E5484D',
    success: (res) => {
      if (res.confirm) {
        clearAllDrafts()
        drafts.value = []
        uni.showToast({ title: '已清空', icon: 'success' })
      }
    }
  })
}

function onCreate() {
  uni.navigateTo({ url: '/pages/templates/editor' })
}
</script>

<style lang="scss" scoped>
/* ===== 标题栏图标 ===== */
.back-icon,
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-secondary);
  transition: color 0.2s ease;
}

.back-icon:active,
.nav-icon:active {
  color: var(--color-brand);
}

/* ===== 统计栏 ===== */
.stats-bar {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 24rpx 40rpx 0;
  padding: 36rpx 32rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;
  box-shadow: var(--shadow-convex-subtle);
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
}

.stat-num {
  font-family: var(--font-cn-title);
  font-size: 48rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1;
}

.stat-label {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.04em;
}

/* ===== 草稿列表 ===== */
.draft-list {
  padding: 24rpx 40rpx 48rpx;
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.draft-row {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  padding: 28rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;
  box-shadow: var(--shadow-convex-subtle);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.draft-row:active {
  transform: scale(0.98);
  box-shadow: var(--shadow-pressed);
}

.draft-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  min-width: 0;
}

.draft-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
}

.draft-name {
  font-family: var(--font-cn-title);
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
  min-width: 0;
}

.draft-time {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

.draft-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
}

.draft-tag {
  display: inline-block;
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
  font-size: 20rpx;
  line-height: 1.6;
}

.draft-params {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
}

.param-item {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  font-family: 'SF Mono', 'Menlo', monospace;
  letter-spacing: 0.02em;
}

/* ===== 操作按钮 ===== */
.draft-actions {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding-top: 4rpx;
  border-top: 1rpx solid var(--color-divider);
  padding-top: 20rpx;
}

.draft-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  font-size: 24rpx;
  font-weight: 500;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.draft-action-btn:active {
  transform: scale(0.95);
}

.draft-action-btn .ph {
  font-size: 28rpx;
}

.resume-btn {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  box-shadow: var(--shadow-convex-brand);
}

.del-btn {
  margin-left: auto;
  background-color: var(--color-surface-alt);
  color: var(--color-danger);
  box-shadow: var(--shadow-convex-subtle);
  padding: 12rpx 20rpx;
}

/* ===== 空状态 ===== */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx 48rpx;
  gap: 20rpx;
}

.empty-icon {
  font-size: 120rpx;
  color: var(--color-text-tertiary);
  opacity: 0.35;
}

.empty-title {
  font-family: var(--font-cn-title);
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.empty-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  text-align: center;
  line-height: 1.6;
}

.empty-btn {
  margin-top: 16rpx;
  width: auto;
  padding: 24rpx 56rpx;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  box-shadow: var(--shadow-convex-brand);
  gap: 12rpx;
}
</style>
