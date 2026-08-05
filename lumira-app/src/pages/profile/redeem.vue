<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">兑换码</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- Hero 卡片 -->
      <view class="lumira-card hero-card fade-up">
        <view class="hero-icon-wrap">
          <text class="ph ph-key hero-icon"></text>
        </view>
        <text class="hero-title">输入兑换码</text>
        <text class="hero-desc">输入活动兑换码，立即获取积分</text>

        <!-- 当前余额 -->
        <view class="balance-row">
          <text class="balance-label">当前积分</text>
          <text class="balance-value">{{ balanceLoading ? '…' : currentBalance }}</text>
        </view>
      </view>

      <!-- 兑换输入 -->
      <view class="lumira-card redeem-card fade-up fade-up-d1">
        <text class="card-section-title">兑换码</text>
        <input
          class="redeem-input neu-inset"
          v-model="code"
          placeholder="请输入兑换码"
          placeholder-class="redeem-placeholder"
          confirm-type="done"
          maxlength="64"
          @confirm="onRedeem"
        />
        <view
          class="lumira-btn-brand redeem-btn"
          :class="{ 'redeem-btn-loading': submitting }"
          @click="onRedeem"
        >
          <text>{{ submitting ? '兑换中…' : '立即兑换' }}</text>
        </view>
      </view>

      <!-- 兑换结果 -->
      <view v-if="lastResult" class="lumira-card result-card fade-up fade-up-d2">
        <view class="result-icon-wrap">
          <text class="ph ph-check-circle result-icon"></text>
        </view>
        <text class="result-title">兑换成功</text>
        <text class="result-desc">获得 {{ lastResult.rewardPoints }} 积分</text>
        <view class="result-meta">
          <view class="result-meta-row">
            <text class="result-meta-label">活动</text>
            <text class="result-meta-value">{{ lastResult.campaignName }}</text>
          </view>
          <view class="result-meta-row">
            <text class="result-meta-label">批次号</text>
            <text class="result-meta-value result-meta-mono">{{ lastResult.batchId }}</text>
          </view>
          <view class="result-meta-row">
            <text class="result-meta-label">最新余额</text>
            <text class="result-meta-value result-meta-brand">{{ lastResult.balance }} 积分</text>
          </view>
        </view>
      </view>

      <!-- 说明 -->
      <view class="lumira-card tips-card fade-up fade-up-d3">
        <text class="card-section-title">使用说明</text>
        <view class="tips-list">
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">兑换码由官方活动发放，每个兑换码只能使用一次</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">兑换的积分将立即到账，可在积分钱包查看</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">积分可用于解锁精选付费模板</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">如遇兑换码无法使用，请联系客服</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { redeemCode, getPointsBalance, type RedeemResp } from '@/api/points'
import { ApiError } from '@/utils/request'

const code = ref('')
const submitting = ref(false)
const currentBalance = ref(0)
const balanceLoading = ref(true)
const lastResult = ref<RedeemResp | null>(null)

onShow(() => {
  loadBalance()
})

async function loadBalance() {
  balanceLoading.value = true
  try {
    const res = await getPointsBalance()
    currentBalance.value = res.balance
  } catch {
    // 静默
  } finally {
    balanceLoading.value = false
  }
}

async function onRedeem() {
  if (submitting.value) return
  const trimmed = code.value.trim()
  if (!trimmed) {
    uni.showToast({ title: '请输入兑换码', icon: 'none' })
    return
  }
  submitting.value = true
  uni.showLoading({ title: '兑换中…' })
  try {
    const res = await redeemCode(trimmed)
    uni.hideLoading()
    lastResult.value = res
    currentBalance.value = res.balance
    code.value = ''
    uni.showToast({
      title: `获得 ${res.rewardPoints} 积分，余额 ${res.balance}`,
      icon: 'none',
      duration: 2500,
    })
  } catch (err) {
    uni.hideLoading()
    const msg = err instanceof ApiError ? err.message : '兑换失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    submitting.value = false
  }
}

const back = () => uni.navigateBack()
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* Hero */
.hero-card {
  margin-bottom: 32rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.hero-icon-wrap {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
}

.hero-icon {
  font-size: 56rpx;
  color: var(--color-brand);
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.hero-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  margin-bottom: 32rpx;
}

.balance-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 20rpx 32rpx;
  border-radius: 20rpx;
  background: rgba(201, 169, 110, 0.08);
}

.balance-label {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.balance-value {
  font-family: 'Courier New', monospace;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-brand);
}

/* 兑换卡 */
.redeem-card {
  margin-bottom: 32rpx;
}

.card-section-title {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 20rpx;
}

.redeem-input {
  width: 100%;
  padding: 28rpx 32rpx;
  font-size: 30rpx;
  color: var(--color-text-primary);
  box-sizing: border-box;
  border: none;
  font-family: 'Courier New', monospace;
  letter-spacing: 0.04em;
}

.redeem-placeholder {
  color: var(--color-text-tertiary);
  font-size: 28rpx;
  letter-spacing: normal;
}

.redeem-btn {
  margin-top: 28rpx;
}

.redeem-btn-loading {
  opacity: 0.6;
}

/* 结果卡 */
.result-card {
  margin-bottom: 32rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.result-icon-wrap {
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  background-color: var(--color-success-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
}

.result-icon {
  font-size: 56rpx;
  color: var(--color-success);
}

.result-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 36rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.result-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  margin-bottom: 32rpx;
}

.result-meta {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.result-meta-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16rpx 24rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
}

.result-meta-label {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.result-meta-value {
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
}

.result-meta-mono {
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
}

.result-meta-brand {
  color: var(--color-brand);
  font-weight: 600;
}

/* 说明卡 */
.tips-card {
  margin-bottom: 32rpx;
}

.tips-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.tips-item {
  display: flex;
  align-items: flex-start;
  gap: 16rpx;
}

.tips-bullet {
  font-size: 24rpx;
  color: var(--color-brand);
  margin-top: 4rpx;
  flex-shrink: 0;
}

.tips-text {
  flex: 1;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  line-height: 1.5;
}
</style>
