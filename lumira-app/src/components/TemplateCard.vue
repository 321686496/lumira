<script setup lang="ts">
import { computed } from 'vue'

interface Template {
  id: string
  name: string
  cover?: string
  tags?: string[]
  hasComposition: boolean
  hasPose: boolean
  hasCameraParams: boolean
  hasPostProcess: boolean
}

interface Props {
  template: Template
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'on-select', id: string): void
}>()

interface Capability {
  key: string
  label: string
}

const activeCapabilities = computed<Capability[]>(() => {
  const t = props.template
  const all: Capability[] = []
  if (t.hasComposition) all.push({ key: 'composition', label: '构图' })
  if (t.hasPose) all.push({ key: 'pose', label: '姿势' })
  if (t.hasCameraParams) all.push({ key: 'camera', label: '机位' })
  if (t.hasPostProcess) all.push({ key: 'post', label: '后期' })
  return all
})

const handleSelect = () => {
  emit('on-select', props.template.id)
}
</script>

<template>
  <view class="template-card" @click="handleSelect">
    <view class="card-cover">
      <image
        v-if="template.cover"
        class="cover-image"
        :src="template.cover"
        mode="aspectFill"
      />
      <view v-else class="cover-placeholder">
        <text class="placeholder-icon">▦</text>
      </view>
    </view>
    <view class="card-body">
      <text class="card-name">{{ template.name }}</text>
      <view v-if="template.tags && template.tags.length" class="card-tags">
        <view v-for="tag in template.tags" :key="tag" class="card-tag">
          <text class="tag-text">{{ tag }}</text>
        </view>
      </view>
      <view v-if="activeCapabilities.length" class="card-capabilities">
        <view
          v-for="cap in activeCapabilities"
          :key="cap.key"
          class="capability"
        >
          <text class="capability-text">{{ cap.label }}</text>
        </view>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.template-card {
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  border: 1px solid var(--color-border);
  overflow: hidden;
  transition: transform 0.15s ease;

  &:active {
    transform: scale(0.98);
  }
}

.card-cover {
  width: 100%;
  aspect-ratio: 3 / 4;
  background: var(--color-bg-canvas);
  overflow: hidden;
}

.cover-image {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-icon {
  font-size: var(--font-size-title);
  color: var(--color-text-tertiary);
}

.card-body {
  padding: var(--space-3);
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.card-name {
  font-family: 'Source Han Serif', 'Songti SC', serif;
  font-size: var(--font-size-heading);
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1.3;
}

.card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}

.card-tag {
  background: var(--color-tag-gold-bg);
  border-radius: var(--radius-pill);
  padding: 2px var(--space-2);
}

.tag-text {
  font-size: var(--font-size-tag);
  color: var(--color-tag-gold-text);
  line-height: 1.4;
}

.card-capabilities {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}

.capability {
  background: var(--color-tag-gold-bg);
  border-radius: var(--radius-pill);
  padding: 2px var(--space-2);
}

.capability-text {
  font-size: var(--font-size-tag);
  color: var(--color-tag-gold-text);
  line-height: 1.4;
}
</style>
