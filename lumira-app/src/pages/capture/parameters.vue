<template>
  <view class="param-page">
    <view class="backdrop" @tap="onBack"></view>
    <view class="panel">
      <view class="panel-handle"></view>
      <view class="panel-header">
        <text class="panel-title">参数</text>
        <text class="reset-btn" @tap="onReset">重置</text>
      </view>

      <scroll-view class="param-list" scroll-y>
        <view class="param-row">
          <view class="param-label-row">
            <text class="param-label">EV</text>
            <text class="param-value">{{ ev }}</text>
          </view>
          <slider
            class="param-slider"
            :min="-2"
            :max="2"
            :step="0.3"
            :value="ev"
            activeColor="var(--color-brand-primary)"
            @change="onEvChange"
          />
        </view>

        <view class="param-row">
          <view class="param-label-row">
            <text class="param-label">ISO</text>
            <text class="param-value">{{ iso }}</text>
          </view>
          <slider
            class="param-slider"
            :min="50"
            :max="3200"
            :step="50"
            :value="iso"
            activeColor="var(--color-brand-primary)"
            @change="onIsoChange"
          />
        </view>

        <view class="param-row">
          <view class="param-label-row">
            <text class="param-label">WB</text>
            <text class="param-value">{{ wb }}K</text>
          </view>
          <slider
            class="param-slider"
            :min="2500"
            :max="9000"
            :step="100"
            :value="wb"
            activeColor="var(--color-brand-primary)"
            @change="onWbChange"
          />
        </view>

        <view class="param-row">
          <view class="param-label-row">
            <text class="param-label">对焦</text>
            <text class="param-value">{{ focus }}</text>
          </view>
          <slider
            class="param-slider"
            :min="0"
            :max="100"
            :step="1"
            :value="focus"
            activeColor="var(--color-brand-primary)"
            @change="onFocusChange"
          />
        </view>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useCaptureStore } from '@/stores/capture'

const captureStore = useCaptureStore()

const ev = computed(() => captureStore.cameraParameters?.ev ?? 0)
const iso = computed(() => captureStore.cameraParameters?.iso ?? 100)
const wb = computed(() => captureStore.cameraParameters?.wb ?? 5500)
const focus = computed(() => captureStore.cameraParameters?.focus ?? 50)

const onEvChange = (e: any) => {
  captureStore.updateCameraParameters({ ev: e.detail.value })
}

const onIsoChange = (e: any) => {
  captureStore.updateCameraParameters({ iso: e.detail.value })
}

const onWbChange = (e: any) => {
  captureStore.updateCameraParameters({ wb: e.detail.value })
}

const onFocusChange = (e: any) => {
  captureStore.updateCameraParameters({ focus: e.detail.value })
}

const onReset = () => {
  captureStore.resetCameraParameters()
}

const onBack = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.param-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: transparent;
}

.backdrop {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
}

.panel {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 60vh;
  background: var(--color-bg-card);
  border-radius: var(--radius-card) var(--radius-card) 0 0;
  padding: var(--space-3) var(--space-5) var(--space-6);
  display: flex;
  flex-direction: column;
}

.panel-handle {
  width: 40px;
  height: 4px;
  border-radius: 2px;
  background: var(--color-border);
  align-self: center;
  margin-bottom: var(--space-4);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-4);
}

.panel-title {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.reset-btn {
  font-size: var(--font-size-body);
  color: var(--color-brand-primary);
}

.param-list {
  flex: 1;
}

.param-row {
  margin-bottom: var(--space-5);
}

.param-label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-2);
}

.param-label {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.param-value {
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.param-slider {
  width: 100%;
}
</style>
