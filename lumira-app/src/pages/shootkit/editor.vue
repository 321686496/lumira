<template>
  <view class="kit-editor-container">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">{{ isEdit ? '编辑组合' : '新建组合' }}</text>
      <view class="lumira-nav-right" @click="onSave">
        <text class="nav-save-text">保存</text>
      </view>
    </view>

    <scroll-view scroll-y class="form-scroll">
      <view class="form-section">
        <text class="form-label">组合名称</text>
        <input class="form-input" v-model="kitName" placeholder="给这个组合起个名字" />
      </view>

      <view class="form-section">
        <text class="form-label">绑定场景</text>
        <view class="bound-scene">
          <text class="ph bound-icon" :class="boundScene?.icon"></text>
          <text class="bound-name">{{ boundScene?.name || '未选择' }}</text>
        </view>
      </view>

      <view class="form-section">
        <text class="form-label">选择模板</text>
        <view class="template-grid">
          <view
            v-for="tpl in allTemplates"
            :key="tpl.meta.id"
            class="template-item"
            :class="{ active: selectedTemplateId === tpl.meta.id }"
            @click="selectedTemplateId = tpl.meta.id"
          >
            <image :src="tpl.meta.cover || `https://picsum.photos/seed/${tpl.meta.id}/200/200`" class="tpl-img" mode="aspectFill" />
            <text class="tpl-name">{{ tpl.meta.name }}</text>
          </view>
        </view>
      </view>

      <view class="form-section">
        <text class="form-label">参数覆盖（可选）</text>
        <view class="param-row">
          <text class="param-label">EV</text>
          <slider :value="overrides.camera.exposureCompensation" :min="-3" :max="3" :step="0.05" activeColor="#C9A96E" @change="onEvChange" />
          <text class="param-val">{{ evDisplay }}</text>
        </view>
        <view class="param-row">
          <text class="param-label">WB(K)</text>
          <slider :value="overrides.camera.whiteBalanceK" :min="2000" :max="10000" :step="50" activeColor="#C9A96E" @change="onWbChange" />
          <text class="param-val">{{ overrides.camera.whiteBalanceK || 5500 }}</text>
        </view>
        <view class="param-row">
          <text class="param-label">ISO</text>
          <slider :value="overrides.camera.iso" :min="100" :max="6400" :step="50" activeColor="#C9A96E" @change="onIsoChange" />
          <text class="param-val">{{ overrides.camera.iso || 'AUTO' }}</text>
        </view>
      </view>

      <view v-if="selectedTemplate" class="preview-section">
        <text class="form-label">预览</text>
        <image :src="selectedTemplate.meta.cover" class="preview-img" mode="aspectFill" />
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, reactive } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useShootKit } from '@/composables/useShootKit'
import { useSceneManager } from '@/composables/useSceneManager'
import { useTemplate } from '@/composables/useTemplate'
import type { CameraParams, ScenePresetId, CustomSceneId } from '@/types/template'

const { createKit, updateKit, getKitDetail } = useShootKit()
const { allScenes } = useSceneManager()
const { getAllTemplates } = useTemplate()

const kitId = ref('')
const sceneId = ref('')
const kitName = ref('')
const selectedTemplateId = ref('')
const overrides = reactive<{ camera: Partial<CameraParams> }>({
  camera: {}
})

const isEdit = computed(() => !!kitId.value)
const allTemplates = computed(() => getAllTemplates())
const boundScene = computed(() => allScenes.value.find(s => s.id === sceneId.value))
const selectedTemplate = computed(() => allTemplates.value.find(t => t.meta.id === selectedTemplateId.value))

const evDisplay = computed(() => {
  const ev = overrides.camera.exposureCompensation
  if (ev === undefined || ev === 0) return '0.00'
  return (ev > 0 ? '+' : '') + ev.toFixed(2)
})

onLoad((options) => {
  if (options?.sceneId) sceneId.value = options.sceneId
  if (options?.id) {
    kitId.value = options.id
    const detail = getKitDetail(options.id, allTemplates.value)
    if (detail) {
      const kit = detail.kit
      kitName.value = kit.name
      selectedTemplateId.value = kit.templateId
      sceneId.value = kit.sceneId
      overrides.camera = kit.overrides?.camera || {}
    }
  }
})

function onEvChange(e: any) { overrides.camera.exposureCompensation = e.detail.value }
function onWbChange(e: any) { overrides.camera.whiteBalanceK = e.detail.value }
function onIsoChange(e: any) { overrides.camera.iso = e.detail.value }

const back = () => uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/home/index' }) })

function onSave() {
  if (!kitName.value.trim()) {
    uni.showToast({ title: '请填写组合名称', icon: 'none' })
    return
  }
  if (!sceneId.value) {
    uni.showToast({ title: '未绑定场景', icon: 'none' })
    return
  }
  if (!selectedTemplateId.value) {
    uni.showToast({ title: '请选择模板', icon: 'none' })
    return
  }
  const hasOverrides = overrides.camera.exposureCompensation
    || overrides.camera.whiteBalanceK
    || overrides.camera.iso
  const payload = {
    name: kitName.value.trim(),
    sceneId: sceneId.value as ScenePresetId | CustomSceneId,
    templateId: selectedTemplateId.value,
    overrides: hasOverrides ? { camera: overrides.camera } : undefined
  }
  if (isEdit.value) {
    updateKit(kitId.value, payload)
  } else {
    createKit(payload)
  }
  uni.showToast({ title: '保存成功', icon: 'success' })
  setTimeout(() => uni.navigateBack(), 600)
}
</script>

<style lang="scss" scoped>
.kit-editor-container {
  min-height: 100vh;
  background: var(--color-canvas);
  display: flex;
  flex-direction: column;
}

.nav-back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}
.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  flex: 1;
  padding-left: 16rpx;
  text-align: left;
}
.nav-save-text {
  color: var(--color-brand);
  font-size: 28rpx;
  font-weight: 600;
}

.form-scroll {
  flex: 1;
}
.form-section {
  padding: 24rpx;
  border-bottom: 1rpx solid var(--color-divider);
}
.form-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  display: block;
  margin-bottom: 16rpx;
}
.form-input {
  width: 100%;
  padding: 20rpx;
  background: var(--color-surface-alt);
  border-radius: 12rpx;
  font-size: 28rpx;
  color: var(--color-text-primary);
  box-sizing: border-box;
}
.bound-scene {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 16rpx 20rpx;
  background: var(--color-surface-alt);
  border-radius: 12rpx;
}
.bound-icon {
  font-size: 32rpx;
  color: var(--color-brand);
}
.bound-name {
  font-size: 28rpx;
  color: var(--color-text-primary);
}

.template-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}
.template-item {
  background: var(--color-surface);
  border-radius: 12rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}
.template-item.active {
  border-color: var(--color-brand);
}
.tpl-img {
  width: 100%;
  height: 160rpx;
}
.tpl-name {
  font-size: 22rpx;
  color: var(--color-text-primary);
  padding: 8rpx;
  display: block;
  text-align: center;
}

.param-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-top: 16rpx;
}
.param-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  width: 80rpx;
}
.param-val {
  font-size: 26rpx;
  color: var(--color-text-primary);
  width: 100rpx;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.preview-section {
  padding: 24rpx;
}
.preview-img {
  width: 100%;
  height: 400rpx;
  border-radius: 16rpx;
}
</style>
