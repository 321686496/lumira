<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import type { LocalTemplate } from '@/types/template'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const templateId = ref('')
const templateName = ref('')
const isDirty = ref(false)

onLoad((query) => {
  if (query?.id) {
    templateId.value = query.id
    const tmpl = templatesStore.getTemplateById(query.id)
    if (tmpl) {
      templateName.value = tmpl.name
    }
  } else {
    templateName.value = '新建模板'
  }
})

const updateName = (name: string) => {
  templateName.value = name
  isDirty.value = true
}

const saveTemplate = () => {
  if (!templateName.value.trim()) {
    uni.showToast({ title: '请输入模板名称', icon: 'none' })
    return
  }
  uni.showToast({ title: '已保存', icon: 'success' })
  isDirty.value = false
  setTimeout(() => uni.navigateBack(), 500)
}

const goBack = () => {
  if (isDirty.value) {
    uni.showModal({
      title: '未保存更改',
      content: '确定放弃更改？',
      success: (res) => {
        if (res.confirm) uni.navigateBack()
      },
    })
  } else {
    uni.navigateBack()
  }
}
</script>

<template>
  <view class="editor-page">
    <view class="editor-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">编辑模板</text>
      <view class="save-btn" @click="saveTemplate">
        <text class="save-text">保存</text>
      </view>
    </view>

    <scroll-view scroll-y class="editor-scroll" :show-scrollbar="false">
      <view class="editor-content">
        <view class="form-group">
          <text class="form-label">模板名称</text>
          <input
            class="form-input"
            :value="templateName"
            @input="(e: any) => updateName(e.detail.value)"
            placeholder="输入模板名称"
          />
        </view>

        <view class="form-group">
          <text class="form-label">叠图类型</text>
          <view class="option-row">
            <view class="option-pill active">
              <text class="option-text">三分法</text>
            </view>
            <view class="option-pill">
              <text class="option-text">引导线</text>
            </view>
            <view class="option-pill">
              <text class="option-text">姿势</text>
            </view>
          </view>
        </view>

        <view class="form-group">
          <text class="form-label">场景指南</text>
          <input class="form-input" placeholder="光线建议" />
          <input class="form-input" placeholder="拍摄距离" style="margin-top: var(--space-2)" />
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.editor-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.editor-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
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

.save-btn {
  padding: var(--space-2) var(--space-4);
  background: var(--color-brand-primary);
  border-radius: var(--radius-button);
  &:active { opacity: 0.8; }
}

.save-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}

.editor-scroll {
  flex: 1;
  width: 100%;
}

.editor-content {
  padding: var(--space-5);
}

.form-group {
  margin-bottom: var(--space-5);
}

.form-label {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
  margin-bottom: var(--space-2);
}

.form-input {
  width: 100%;
  padding: var(--space-3) var(--space-4);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-button);
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.option-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.option-pill {
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);

  &.active {
    background: var(--color-tag-gold-bg);
    border-color: var(--color-brand-primary);
  }

  &:active { opacity: 0.8; }
}

.option-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);

  .active & {
    color: var(--color-tag-gold-text);
  }
}
</style>
