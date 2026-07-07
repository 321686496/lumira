<script setup lang="ts">
import { ref } from 'vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const importing = ref(false)
const result = ref<{ success: boolean; message: string } | null>(null)

const handleImport = () => {
  uni.chooseFile({
    count: 1,
    extension: ['.pptpl', '.json'],
    success: async (res) => {
      const filePath = res.tempFiles[0].path
      importing.value = true
      result.value = null
      try {
        const fs = uni.getFileSystemManager()
        const content = fs.readFileSync(filePath, 'utf-8') as string
        await templatesStore.importFromJson(content)
        result.value = { success: true, message: '模板导入成功' }
        uni.showToast({ title: '导入成功', icon: 'success' })
      } catch (e) {
        const msg = e instanceof Error ? e.message : '导入失败'
        result.value = { success: false, message: msg }
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        importing.value = false
      }
    },
    fail: () => {
      uni.showToast({ title: '已取消选择', icon: 'none' })
    },
  })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="import-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">导入模板</text>
    </view>

    <view class="import-content">
      <view class="import-card" @click="handleImport">
        <text class="import-icon">＋</text>
        <text class="import-label">选择 .pptpl 文件</text>
        <text class="import-hint">支持 .pptpl 和 .json 格式</text>
      </view>

      <view v-if="importing" class="import-status">
        <text class="status-text">正在导入...</text>
      </view>

      <view v-if="result" class="import-result" :class="{ success: result.success, error: !result.success }">
        <text class="result-text">{{ result.message }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.import-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
}

.page-nav {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
}

.nav-icon {
  font-size: 22px;
  color: var(--color-text-primary);
}

.nav-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.import-content {
  padding: var(--space-5);
}

.import-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-8) var(--space-5);
  background: var(--color-bg-card);
  border: 1px dashed var(--color-brand-primary);
  border-radius: var(--radius-card);
  gap: var(--space-3);
  &:active { opacity: 0.85; }
}

.import-icon {
  font-size: 40px;
  color: var(--color-brand-primary);
}

.import-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.import-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.import-status {
  margin-top: var(--space-4);
  text-align: center;
}

.status-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.import-result {
  margin-top: var(--space-4);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-button);
  text-align: center;

  &.success {
    background: var(--color-tag-green-bg);
  }
  &.error {
    background: var(--color-tag-red-bg);
  }
}

.result-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
}
</style>
