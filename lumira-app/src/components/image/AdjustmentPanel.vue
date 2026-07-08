<script setup lang="ts">
import { ref } from 'vue'
import ColorSliders from './ColorSliders.vue'
import LutSelector from './LutSelector.vue'
import SmoothSlider from './SmoothSlider.vue'
import SharpenSlider from './SharpenSlider.vue'
import type { ColorAdjustment } from '@/types/template'

type ToolTab = 'color' | 'lut' | 'smooth' | 'sharpen'

const activeTab = ref<ToolTab>('color')

const tabs: { key: ToolTab; label: string }[] = [
  { key: 'color', label: '调色' },
  { key: 'lut', label: 'LUT' },
  { key: 'smooth', label: '磨皮' },
  { key: 'sharpen', label: '锐化' },
]

const colorParams = ref<ColorAdjustment>({
  brightness: 0,
  contrast: 0,
  saturation: 0,
  temperature: 0,
  tint: 0,
})
const currentLut = ref('')
const smoothValue = ref(0)
const sharpenValue = ref(0)

const lutOptions = [
  { name: '原图', value: '' },
  { name: '暖阳', value: 'warm-sun' },
  { name: '冷调', value: 'cool-tone' },
  { name: '胶片', value: 'film' },
  { name: '日系', value: 'japanese' },
]

const emit = defineEmits<{
  (e: 'on-color-change', params: Partial<ColorAdjustment>): void
  (e: 'on-lut-select', name: string): void
  (e: 'on-smooth-change', value: number): void
  (e: 'on-sharpen-change', value: number): void
}>()

const handleColorChange = (params: Partial<ColorAdjustment>) => {
  colorParams.value = { ...colorParams.value, ...params }
  emit('on-color-change', params)
}
</script>

<template>
  <view class="adjustment-panel">
    <scroll-view scroll-x class="tool-tabs" :show-scrollbar="false">
      <view class="tabs-row">
        <view
          v-for="tab in tabs"
          :key="tab.key"
          class="tab-item"
          :class="{ active: activeTab === tab.key }"
          @click="activeTab = tab.key"
        >
          <text class="tab-text">{{ tab.label }}</text>
        </view>
      </view>
    </scroll-view>

    <view class="tool-content">
      <ColorSliders v-if="activeTab === 'color'" :value="colorParams" @on-change="handleColorChange" />
      <LutSelector v-if="activeTab === 'lut'" :current="currentLut" :options="lutOptions" @on-select="(v: string) => { currentLut = v; emit('on-lut-select', v) }" />
      <SmoothSlider v-if="activeTab === 'smooth'" :value="smoothValue" @on-change="(v: number) => { smoothValue = v; emit('on-smooth-change', v) }" />
      <SharpenSlider v-if="activeTab === 'sharpen'" :value="sharpenValue" @on-change="(v: number) => { sharpenValue = v; emit('on-sharpen-change', v) }" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.adjustment-panel {
  width: 100%;
}

.tool-tabs {
  width: 100%;
  white-space: nowrap;
  margin-bottom: var(--space-4);
  border-bottom: 1px solid var(--color-border);
}

.tabs-row {
  display: inline-flex;
  gap: var(--space-4);
  padding: 0 var(--space-5);
}

.tab-item {
  padding: var(--space-2) 0;
  border-bottom: 2px solid transparent;
  &:active { opacity: 0.7; }
}

.tab-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
}

.tab-item.active {
  border-bottom-color: var(--color-brand-primary);
  .tab-text { color: var(--color-brand-primary); }
}

.tool-content {
  padding: 0 var(--space-5);
}
</style>
