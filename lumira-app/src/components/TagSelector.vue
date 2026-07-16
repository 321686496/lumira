<template>
  <view class="tag-selector-wrap">
    <scroll-view scroll-x class="tag-selector" :show-scrollbar="false">
      <view class="tag-list-inner">
        <view
          v-for="tag in availableTags"
          :key="tag.id"
          class="tag-pill"
          :class="{ 'tag-pill-active': selectedTagIds.includes(tag.id) }"
          @click="toggleTag(tag.id)"
        >
          <text class="tag-pill-text">{{ tag.name }}</text>
        </view>
        <view class="tag-pill tag-pill-add" @click="onCreateTag">
          <text class="tag-pill-add-text">+</text>
        </view>
      </view>
    </scroll-view>
    <view v-if="availableTags.length === 0" class="tag-empty">
      <text class="tag-empty-text">暂无标签，点击 + 创建</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTagManager } from '@/composables/useTagManager'
import type { UserTag } from '@/types/template'

const props = defineProps<{
  selectedTagIds: string[]
  type: 'scene' | 'template' | 'both'
}>()

const emit = defineEmits<{
  'update:selectedTagIds': [ids: string[]]
  'create-tag': []
}>()

const { getTagsByType } = useTagManager()
const availableTags = computed<UserTag[]>(() => getTagsByType(props.type))

function toggleTag(id: string) {
  if (props.selectedTagIds.includes(id)) {
    emit('update:selectedTagIds', props.selectedTagIds.filter(t => t !== id))
  } else {
    emit('update:selectedTagIds', [...props.selectedTagIds, id])
  }
}

function onCreateTag() {
  emit('create-tag')
}
</script>

<style lang="scss" scoped>
.tag-selector-wrap {
  position: relative;
}

.tag-selector {
  white-space: nowrap;
}

.tag-list-inner {
  display: inline-flex;
  align-items: center;
  gap: 16rpx;
  padding: 0 24rpx;
}

.tag-pill {
  display: inline-flex;
  align-items: center;
  padding: 12rpx 24rpx;
  border-radius: 32rpx;
  background: rgba(0, 0, 0, 0.05);
  flex-shrink: 0;
}

.tag-pill-active {
  background: #C9A876;
}

.tag-pill-text {
  font-size: 24rpx;
  color: #2A2520;
  line-height: 1.2;
}

.tag-pill-active .tag-pill-text {
  color: #FFFFFF;
}

.tag-pill-add {
  background: transparent;
  border: 2rpx dashed #C9A876;
}

.tag-pill-add-text {
  font-size: 28rpx;
  color: #C9A876;
  line-height: 1;
}

.tag-empty {
  padding: 16rpx 24rpx;
}

.tag-empty-text {
  font-size: 22rpx;
  color: #6B635A;
}
</style>
