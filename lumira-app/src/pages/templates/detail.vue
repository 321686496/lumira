<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import OverlayPreview from '@/components/template/OverlayPreview.vue'
import SceneGuidePanel from '@/components/template/SceneGuidePanel.vue'
import CameraParamsPanel from '@/components/template/CameraParamsPanel.vue'
import ExampleGallery from '@/components/template/ExampleGallery.vue'
import { useTemplatesStore } from '@/stores/templates'
import { useCaptureStore } from '@/stores/capture'
import type { ResolvedTemplate } from '@/types/template'

const templatesStore = useTemplatesStore()
const captureStore = useCaptureStore()

const templateId = ref('')
const resolved = ref<ResolvedTemplate | null>(null)

onLoad(async (query) => {
  if (query?.id) {
    templateId.value = query.id
    templatesStore.setCurrentTemplate(query.id)
    const result = await templatesStore.getResolvedTemplate(query.id)
    resolved.value = result
  }
})

const hasSceneGuide = computed(() => !!resolved.value?.sceneGuide)
const hasCameraParams = computed(() => !!resolved.value?.camera)
const exampleImages = computed(() => {
  if (!resolved.value) return []
  return resolved.value.meta.cover ? [resolved.value.meta.cover] : []
})

const handleApplyTemplate = () => {
  if (templateId.value) {
    captureStore.setActiveTemplate(templateId.value)
  }
  uni.navigateTo({ url: `/pages/capture/index?templateId=${templateId.value}` })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="template-detail-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">模板详情</text>
    </view>

    <scroll-view scroll-y class="detail-scroll" :show-scrollbar="false">
      <view class="detail-content">
        <!-- 叠图预览 -->
        <OverlayPreview
          v-if="resolved"
          :composition="resolved.composition"
          :pose="resolved.pose"
        />

        <!-- 标题与标签 -->
        <view class="template-header" v-if="resolved">
          <text class="template-title">{{ resolved.meta.name }}</text>
          <view class="capability-tags">
            <text v-if="resolved.composition" class="cap-tag">◆构图</text>
            <text v-if="resolved.pose" class="cap-tag">◆姿势</text>
            <text v-if="resolved.camera" class="cap-tag">◆参数</text>
            <text v-if="resolved.postProcess" class="cap-tag">◆后期</text>
          </view>
        </view>

        <!-- 场景指南 -->
        <SceneGuidePanel
          v-if="hasSceneGuide && resolved?.sceneGuide"
          :guide="resolved.sceneGuide"
        />

        <!-- 相机参数建议 -->
        <CameraParamsPanel
          v-if="hasCameraParams && resolved?.camera"
          :params="resolved.camera"
        />

        <!-- 示例作品 -->
        <ExampleGallery v-if="exampleImages.length > 0" :examples="exampleImages" />

        <!-- 套用拍摄 CTA -->
        <view class="cta-area">
          <view class="cta-btn" @click="handleApplyTemplate">
            <text class="cta-text">套用此模板拍摄</text>
          </view>
        </view>
      </view>

      <view class="bottom-spacer" />
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.template-detail-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
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

.detail-scroll {
  flex: 1;
  width: 100%;
}

.detail-content {
  padding: 0 var(--space-5);
}

.template-header {
  margin-bottom: var(--space-5);
}

.template-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
  line-height: var(--line-height-title);
  margin-bottom: var(--space-2);
}

.capability-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.cap-tag {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  color: var(--color-tag-gold-text);
  background: var(--color-tag-gold-bg);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-pill);
  letter-spacing: var(--letter-spacing-tag);
}

.cta-area {
  margin-top: var(--space-7);
  margin-bottom: var(--space-5);
}

.cta-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4) var(--space-6);
  background: var(--color-text-primary);
  border-radius: var(--radius-button);
  transition: transform var(--duration-fast) ease;

  &:active { transform: scale(0.98); }
}

.cta-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}

.bottom-spacer {
  height: var(--space-8);
}
</style>
