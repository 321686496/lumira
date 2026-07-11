<template>
  <view class="lumira-container no-tabbar">
    <!-- 1. 标题栏（透明背景 + 滚动感知毛玻璃） -->
    <view class="lumira-nav" :class="{ scrolled: isScrolled }">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">我的模板</text>
      <view class="lumira-nav-right">
        <text class="ph ph-download-simple nav-icon" @click="onImport"></text>
      </view>
    </view>

    <!-- 2. 统计栏 -->
    <view class="stats-bar fade-up">
      <view class="stat-item">
        <text class="stat-num">{{ customTemplates.length }}</text>
        <text class="stat-label">自定义模板</text>
      </view>
      <view class="stat-divider"></view>
      <view class="stat-item">
        <text class="stat-num">{{ totalUsage }}</text>
        <text class="stat-label">使用次数</text>
      </view>
      <view class="stat-divider"></view>
      <view class="stat-item">
        <text class="stat-num">{{ favoriteCount }}</text>
        <text class="stat-label">收藏</text>
      </view>
    </view>

    <!-- 3. 操作栏 -->
    <view class="action-bar fade-up fade-up-d1">
      <view class="lumira-btn-primary action-btn" @click="onCreate">
        <text class="ph ph-plus"></text>
        <text>新建模板</text>
      </view>
      <view class="lumira-btn-ghost action-btn" @click="onImport">
        <text class="ph ph-download-simple"></text>
        <text>导入模板</text>
      </view>
    </view>

    <!-- 4. 筛选栏 -->
    <view class="filter-bar fade-up fade-up-d2">
      <view class="filter-pill" :class="{ active: activeFilter === 'all' }" @click="activeFilter = 'all'">
        <text>全部</text>
      </view>
      <view class="filter-pill" :class="{ active: activeFilter === 'portrait' }" @click="activeFilter = 'portrait'">
        <text>人像</text>
      </view>
      <view class="filter-pill" :class="{ active: activeFilter === 'landscape' }" @click="activeFilter = 'landscape'">
        <text>风光</text>
      </view>
      <view class="filter-pill" :class="{ active: activeFilter === 'food' }" @click="activeFilter = 'food'">
        <text>美食</text>
      </view>
      <view class="filter-pill" :class="{ active: activeFilter === 'other' }" @click="activeFilter = 'other'">
        <text>其他</text>
      </view>
    </view>

    <!-- 5. 列表 -->
    <view class="tpl-list fade-up fade-up-d3" v-if="filteredTemplates.length > 0">
      <view
        class="tpl-row"
        v-for="tpl in filteredTemplates"
        :key="tpl.meta.id"
        @click="onEdit(tpl.meta.id)"
        @longpress="onLongPress(tpl)"
      >
        <view class="tpl-cover-wrap">
          <image class="tpl-cover" :src="coverUrl(tpl)" mode="aspectFill" />
          <view class="tpl-cat-tag">
            <text>{{ categoryLabel(tpl.meta.category) }}</text>
          </view>
        </view>
        <view class="tpl-content">
          <text class="tpl-name">{{ tpl.meta.name }}</text>
          <view class="tpl-tags" v-if="tpl.meta.tags.length > 0">
            <text class="tpl-tag" v-for="tag in tpl.meta.tags.slice(0, 3)" :key="tag">{{ tag }}</text>
          </view>
          <view class="tpl-param-summary">
            <text class="param-item">{{ tpl.camera.exposureCompensation > 0 ? '+' : '' }}{{ tpl.camera.exposureCompensation }} EV</text>
            <text class="param-item">{{ tpl.camera.iso }} ISO</text>
            <text class="param-item">{{ tpl.camera.shutterSpeed }}</text>
          </view>
          <view class="tpl-actions">
            <view class="tpl-action-btn apply-btn" @click.stop="onApply(tpl.meta.id)">
              <text class="ph ph-camera"></text>
              <text>拍摄</text>
            </view>
            <view class="tpl-action-btn edit-btn" @click.stop="onEdit(tpl.meta.id)">
              <text class="ph ph-pencil-simple"></text>
              <text>编辑</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 6. 空状态 -->
    <view class="empty-state fade-up fade-up-d3" v-else>
      <text class="ph ph-stack empty-icon"></text>
      <text class="empty-title">还没有自定义模板</text>
      <text class="empty-desc">创建你的第一个模板，或从 .pptpl 文件导入</text>
      <view class="lumira-btn-primary empty-btn" @click="onCreate">
        <text class="ph ph-plus"></text>
        <text>创建模板</text>
      </view>
    </view>

    <!-- 7. 长按操作面板（底部弹出） -->
    <view class="action-sheet-mask" v-if="actionSheetVisible" @click="actionSheetVisible = false"></view>
    <view class="action-sheet" :class="{ visible: actionSheetVisible }">
      <view class="action-sheet-header">
        <text class="action-sheet-title">{{ actionSheetTemplate?.meta.name }}</text>
      </view>
      <view class="action-sheet-item" @click="onSheetAction('edit')">
        <text class="ph ph-pencil-simple"></text>
        <text>编辑模板</text>
      </view>
      <view class="action-sheet-item" @click="onSheetAction('apply')">
        <text class="ph ph-camera"></text>
        <text>套用拍摄</text>
      </view>
      <view class="action-sheet-item" @click="onSheetAction('duplicate')">
        <text class="ph ph-copy"></text>
        <text>复制模板</text>
      </view>
      <view class="action-sheet-item" @click="onSheetAction('export')">
        <text class="ph ph-upload-simple"></text>
        <text>导出 .pptpl</text>
      </view>
      <view class="action-sheet-item action-sheet-danger" @click="onSheetAction('delete')">
        <text class="ph ph-trash"></text>
        <text>删除模板</text>
      </view>
      <view class="action-sheet-cancel" @click="actionSheetVisible = false">
        <text>取消</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow, onPageScroll } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { useTemplateIO } from '@/composables/useTemplateIO'
import type { PhotoTemplate, Target } from '@/types/template'

const { getCustomTemplates, deleteCustomTemplate, duplicateTemplate } = useTemplate()
const { exportTemplate, importTemplate } = useTemplateIO()

const isScrolled = ref(false)
const activeFilter = ref<'all' | Target | 'other'>('all')
const customTemplates = ref<PhotoTemplate[]>([])
const actionSheetVisible = ref(false)
const actionSheetTemplate = ref<PhotoTemplate | null>(null)

const totalUsage = ref(0)
const favoriteCount = ref(0)

onShow(() => {
  customTemplates.value = getCustomTemplates()
})

onPageScroll((e) => {
  isScrolled.value = e.scrollTop > 20
})

const filteredTemplates = computed(() => {
  if (activeFilter.value === 'all') return customTemplates.value
  if (activeFilter.value === 'other') {
    return customTemplates.value.filter(t =>
      !['portrait', 'landscape', 'food'].includes(t.meta.category)
    )
  }
  return customTemplates.value.filter(t => t.meta.category === activeFilter.value)
})

function coverUrl(tpl: PhotoTemplate): string {
  return tpl.meta.cover || `https://picsum.photos/seed/${tpl.meta.id}/400/600`
}

function categoryLabel(cat: Target): string {
  const map: Record<Target, string> = {
    portrait: '人像',
    landscape: '风光',
    food: '美食',
    street: '街拍',
    night: '夜景',
    macro: '微距',
    'still-life': '静物'
  }
  return map[cat] || cat
}

function back() {
  uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/profile/index' }) })
}

function onCreate() {
  uni.navigateTo({ url: '/pages/templates/editor' })
}

function onEdit(id: string) {
  uni.navigateTo({ url: `/pages/templates/editor?templateId=${id}` })
}

function onApply(id: string) {
  uni.navigateTo({ url: `/pages/capture/index?templateId=${id}` })
}

async function onImport() {
  const tpl = await importTemplate()
  if (tpl) {
    customTemplates.value = getCustomTemplates()
  }
}

function onLongPress(tpl: PhotoTemplate) {
  actionSheetTemplate.value = tpl
  actionSheetVisible.value = true
}

function onSheetAction(action: string) {
  const tpl = actionSheetTemplate.value
  if (!tpl) return
  actionSheetVisible.value = false
  switch (action) {
    case 'edit':
      onEdit(tpl.meta.id)
      break
    case 'apply':
      onApply(tpl.meta.id)
      break
    case 'duplicate':
      duplicateTemplate(tpl.meta.id)
      customTemplates.value = getCustomTemplates()
      uni.showToast({ title: '已复制', icon: 'success' })
      break
    case 'export':
      exportTemplate(tpl)
      break
    case 'delete':
      uni.showModal({
        title: '删除模板',
        content: `确定删除"${tpl.meta.name}"吗？此操作不可恢复。`,
        confirmColor: '#E5484D',
        success: (res) => {
          if (res.confirm) {
            deleteCustomTemplate(tpl.meta.id)
            customTemplates.value = getCustomTemplates()
            uni.showToast({ title: '已删除', icon: 'success' })
          }
        }
      })
      break
  }
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
  justify-content: space-around;
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

.stat-divider {
  width: 1rpx;
  height: 56rpx;
  background-color: var(--color-divider);
}

/* ===== 操作栏 ===== */
.action-bar {
  display: flex;
  gap: 20rpx;
  padding: 32rpx 40rpx 0;
}

.action-btn {
  flex: 1;
  justify-content: center;
}

.action-bar .lumira-btn-ghost {
  padding: 28rpx 0;
  font-size: 30rpx;
  font-weight: 500;
  justify-content: center;
  border-radius: 16rpx;
}

.action-bar .lumira-btn-primary {
  gap: 12rpx;
}

.action-bar .lumira-btn-ghost {
  gap: 12rpx;
}

/* ===== 筛选栏 ===== */
.filter-bar {
  display: flex;
  gap: 16rpx;
  padding: 32rpx 40rpx 8rpx;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.filter-pill {
  flex-shrink: 0;
  padding: 14rpx 36rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  box-shadow: var(--shadow-convex-subtle);
  transition: background 0.3s ease, box-shadow 0.3s ease;
}

.filter-pill text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.filter-pill.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  box-shadow: var(--shadow-pressed);
}

.filter-pill.active text {
  color: #fff;
  font-weight: 500;
}

/* ===== 模板列表 ===== */
.tpl-list {
  padding: 24rpx 40rpx 48rpx;
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.tpl-row {
  display: flex;
  gap: 24rpx;
  padding: 24rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;
  box-shadow: var(--shadow-convex-subtle);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.tpl-row:active {
  transform: scale(0.98);
  box-shadow: var(--shadow-pressed);
}

.tpl-cover-wrap {
  position: relative;
  flex-shrink: 0;
  width: 200rpx;
  height: 200rpx;
  border-radius: 20rpx;
  overflow: hidden;
}

.tpl-cover {
  width: 100%;
  height: 100%;
}

.tpl-cat-tag {
  position: absolute;
  left: 12rpx;
  bottom: 12rpx;
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
  background-color: rgba(0, 0, 0, 0.55);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
}

.tpl-cat-tag text {
  font-size: 20rpx;
  color: #fff;
  font-weight: 500;
}

.tpl-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  min-width: 0;
}

.tpl-name {
  font-family: var(--font-cn-title);
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tpl-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
}

.tpl-tag {
  display: inline-block;
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
  font-size: 20rpx;
  line-height: 1.6;
}

.tpl-param-summary {
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

.tpl-actions {
  display: flex;
  gap: 16rpx;
  margin-top: auto;
  padding-top: 4rpx;
}

.tpl-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  font-size: 24rpx;
  font-weight: 500;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.tpl-action-btn:active {
  transform: scale(0.95);
}

.apply-btn {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  box-shadow: var(--shadow-convex-brand);
}

.edit-btn {
  background-color: var(--color-surface-alt);
  color: var(--color-text-secondary);
  box-shadow: var(--shadow-convex-subtle);
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

/* ===== 长按操作面板 ===== */
.action-sheet-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 1000;
  opacity: 0;
  animation: fadeIn 0.25s ease forwards;
}

.action-sheet {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1001;
  background-color: var(--color-surface);
  border-radius: 32rpx 32rpx 0 0;
  padding: 16rpx 0 calc(16rpx + env(safe-area-inset-bottom, 0));
  transform: translateY(100%);
  transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 -8rpx 32rpx rgba(0, 0, 0, 0.08);
}

.action-sheet.visible {
  transform: translateY(0);
}

.action-sheet-header {
  padding: 24rpx 40rpx 16rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.action-sheet-title {
  font-family: var(--font-cn-title);
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.action-sheet-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 28rpx 40rpx;
  transition: background-color 0.15s ease;
}

.action-sheet-item:active {
  background-color: var(--color-surface-alt);
}

.action-sheet-item .ph {
  font-size: 36rpx;
  color: var(--color-text-secondary);
  width: 48rpx;
  text-align: center;
}

.action-sheet-item text:last-child {
  font-size: 30rpx;
  color: var(--color-text-primary);
}

.action-sheet-danger .ph {
  color: var(--color-danger);
}

.action-sheet-danger text:last-child {
  color: var(--color-danger);
}

.action-sheet-cancel {
  margin: 16rpx 24rpx 0;
  padding: 28rpx 0;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
  text-align: center;
  transition: transform 0.15s ease;
}

.action-sheet-cancel:active {
  transform: scale(0.98);
}

.action-sheet-cancel text {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
</style>
