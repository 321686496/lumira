<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">积分钱包</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 余额卡片 -->
      <view class="balance-card fade-up">
        <view class="balance-deco-1"></view>
        <view class="balance-deco-2"></view>
        <text class="balance-label">当前积分</text>
        <text class="balance-value">{{ loading ? '…' : balance }}</text>
        <view class="balance-stats">
          <view class="balance-stat-cell">
            <text class="balance-stat-num">+{{ totalEarned }}</text>
            <text class="balance-stat-label">累计获得</text>
          </view>
          <view class="balance-stat-divider"></view>
          <view class="balance-stat-cell">
            <text class="balance-stat-num">-{{ totalSpent }}</text>
            <text class="balance-stat-label">累计消耗</text>
          </view>
        </view>
      </view>

      <!-- 签到入口 -->
      <view class="lumira-card sign-card fade-up fade-up-d1">
        <view class="sign-info">
          <view class="sign-icon-wrap">
            <text class="ph ph-calendar-check sign-icon"></text>
          </view>
          <view class="sign-text">
            <text class="sign-title">每日签到</text>
            <text class="sign-desc">
              {{ signedToday ? `已连续签到 ${consecutiveDays} 天` : '今日还未签到，签到领积分' }}
            </text>
          </view>
        </view>
        <view
          class="sign-btn"
          :class="{ 'sign-btn-done': signedToday, 'sign-btn-loading': signing }"
          @click="onSignIn"
        >{{ signing ? '签到中…' : (signedToday ? '已签到' : '今日签到') }}</view>
      </view>

      <!-- 快捷入口 -->
      <view class="quick-row fade-up fade-up-d2">
        <view class="lumira-btn-ghost quick-btn" @click="goRedeem">
          <text class="ph ph-key"></text>
          <text>兑换码</text>
        </view>
        <view class="lumira-btn-ghost quick-btn" @click="goInvite">
          <text class="ph ph-gift"></text>
          <text>邀请有礼</text>
        </view>
      </view>

      <!-- 流水标题 -->
      <text class="section-title fade-up fade-up-d3">积分流水</text>

      <!-- 流水列表 -->
      <view class="lumira-card tx-card fade-up fade-up-d3">
        <view v-if="transactions.length > 0" class="tx-list">
          <view
            class="tx-item"
            :class="{ 'tx-item-last': i === transactions.length - 1 }"
            v-for="(tx, i) in transactions"
            :key="tx.id"
          >
            <view class="tx-icon-wrap" :class="tx.delta >= 0 ? 'tx-icon-in' : 'tx-icon-out'">
              <text class="ph" :class="tx.delta >= 0 ? 'ph-arrow-down-left' : 'ph-arrow-up-right'"></text>
            </view>
            <view class="tx-body">
              <text class="tx-title">{{ typeLabel(tx.type) }}</text>
              <text class="tx-time">{{ formatTime(tx.createdAt) }}</text>
            </view>
            <text
              class="tx-delta"
              :class="tx.delta >= 0 ? 'tx-delta-in' : 'tx-delta-out'"
            >{{ tx.delta >= 0 ? `+${tx.delta}` : `${tx.delta}` }}</text>
          </view>
        </view>
        <view v-else class="tx-empty">
          <text class="ph ph-receipt tx-empty-icon"></text>
          <text class="tx-empty-text">暂无积分流水</text>
          <text class="tx-empty-sub">签到、兑换、邀请都会在这里显示</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import {
  getPointsBalance,
  getPointsTransactions,
  signIn,
  getSignInStatus,
  transactionTypeLabel,
  formatTransactionTime,
  type PointsTransaction,
} from '@/api/points'
import { ApiError } from '@/utils/request'

const loading = ref(true)
const balance = ref(0)
const totalEarned = ref(0)
const totalSpent = ref(0)
const transactions = ref<PointsTransaction[]>([])

const signedToday = ref(false)
const consecutiveDays = ref(0)
const signing = ref(false)

onShow(() => {
  loadBalance()
  loadTransactions()
  loadSignInStatus()
})

async function loadBalance() {
  loading.value = true
  try {
    const res = await getPointsBalance()
    balance.value = res.balance
    totalEarned.value = res.totalEarned
    totalSpent.value = res.totalSpent
  } catch {
    // 静默
  } finally {
    loading.value = false
  }
}

async function loadTransactions() {
  try {
    const res = await getPointsTransactions(50, 0)
    transactions.value = res.transactions || []
  } catch {
    transactions.value = []
  }
}

async function loadSignInStatus() {
  try {
    const res = await getSignInStatus()
    signedToday.value = res.signedToday
    consecutiveDays.value = res.consecutiveDays
  } catch {
    // 静默
  }
}

async function onSignIn() {
  if (signedToday.value || signing.value) return
  signing.value = true
  uni.showLoading({ title: '签到中…' })
  try {
    const res = await signIn()
    uni.hideLoading()
    if (res.success) {
      signedToday.value = true
      consecutiveDays.value = res.dayIndex
      balance.value = res.balance
      uni.showToast({
        title: `签到成功，获得 ${res.pointsEarned} 积分`,
        icon: 'none',
        duration: 2500,
      })
      // 刷新流水
      loadTransactions()
      loadBalance()
    } else {
      uni.showToast({ title: '签到失败', icon: 'none' })
    }
  } catch (err) {
    uni.hideLoading()
    const msg = err instanceof ApiError ? err.message : '签到失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    signing.value = false
  }
}

function typeLabel(type: string): string {
  return transactionTypeLabel(type)
}

function formatTime(iso: string): string {
  return formatTransactionTime(iso)
}

const back = () => uni.navigateBack()
const goRedeem = () => uni.navigateTo({ url: '/pages/profile/redeem' })
const goInvite = () => uni.navigateTo({ url: '/pages/profile/invite' })
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* 余额卡片 */
.balance-card {
  position: relative;
  overflow: hidden;
  border-radius: 40rpx;
  padding: 56rpx 40rpx 40rpx;
  text-align: center;
  margin-bottom: 32rpx;
  background: linear-gradient(145deg, #FFF8EE 0%, #F5EDDB 40%, #EDE3D0 100%);
  border: 2rpx solid rgba(201, 169, 110, 0.12);
  box-shadow: 0 8rpx 48rpx rgba(201, 169, 110, 0.08), 0 2rpx 4rpx rgba(0, 0, 0, 0.02);
}

.balance-deco-1 {
  position: absolute;
  top: -80rpx;
  right: -80rpx;
  width: 240rpx;
  height: 240rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.06);
  pointer-events: none;
}

.balance-deco-2 {
  position: absolute;
  bottom: -60rpx;
  left: -40rpx;
  width: 160rpx;
  height: 160rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.04);
  pointer-events: none;
}

.balance-label {
  display: block;
  font-size: 26rpx;
  color: #8C7340;
  letter-spacing: 0.06em;
  margin-bottom: 16rpx;
}

.balance-value {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 96rpx;
  font-weight: 700;
  color: #3D2817;
  line-height: 1;
  margin-bottom: 40rpx;
}

.balance-stats {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
}

.balance-stat-cell {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.balance-stat-divider {
  width: 2rpx;
  height: 56rpx;
  background: rgba(201, 169, 110, 0.2);
}

.balance-stat-num {
  font-family: 'Courier New', monospace;
  font-size: 32rpx;
  font-weight: 600;
  color: #8C7340;
}

.balance-stat-label {
  display: block;
  font-size: 22rpx;
  color: #B89860;
  margin-top: 8rpx;
  letter-spacing: 0.04em;
}

/* 签到卡片 */
.sign-card {
  margin-bottom: 32rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24rpx;
}

.sign-info {
  display: flex;
  align-items: center;
  gap: 24rpx;
  flex: 1;
  min-width: 0;
}

.sign-icon-wrap {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  background: rgba(201, 169, 110, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.sign-icon {
  font-size: 40rpx;
  color: var(--color-brand);
}

.sign-text {
  flex: 1;
  min-width: 0;
}

.sign-title {
  display: block;
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.sign-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
}

.sign-btn {
  padding: 20rpx 36rpx;
  border-radius: 16rpx;
  background-color: var(--color-brand);
  color: var(--color-text-inverse);
  font-size: 26rpx;
  font-weight: 500;
  box-shadow: var(--shadow-convex-brand);
  flex-shrink: 0;
  line-height: 1;
}

.sign-btn:active {
  transform: scale(0.96);
}

.sign-btn-done {
  background-color: var(--color-surface-alt);
  color: var(--color-text-tertiary);
  box-shadow: none;
}

.sign-btn-loading {
  opacity: 0.6;
}

/* 快捷入口 */
.quick-row {
  display: flex;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.quick-btn {
  flex: 1;
  justify-content: center;
}

.quick-btn .ph {
  font-size: 32rpx;
}

/* 区块标题 */
.section-title {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0 8rpx;
  margin-bottom: 16rpx;
}

/* 流水列表 */
.tx-card {
  padding: 16rpx 32rpx;
}

.tx-list {
  display: flex;
  flex-direction: column;
}

.tx-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 28rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.tx-item-last {
  border-bottom: none;
}

.tx-icon-wrap {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.tx-icon-in {
  background-color: var(--color-success-subtle);
}

.tx-icon-out {
  background-color: var(--color-danger-subtle);
}

.tx-icon-wrap .ph {
  font-size: 32rpx;
}

.tx-icon-in .ph {
  color: var(--color-success);
}

.tx-icon-out .ph {
  color: var(--color-danger);
}

.tx-body {
  flex: 1;
  min-width: 0;
}

.tx-title {
  display: block;
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.tx-time {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
  font-family: 'Courier New', monospace;
}

.tx-delta {
  font-family: 'Courier New', monospace;
  font-size: 32rpx;
  font-weight: 600;
  flex-shrink: 0;
}

.tx-delta-in {
  color: var(--color-success);
}

.tx-delta-out {
  color: var(--color-danger);
}

/* 空状态 */
.tx-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 64rpx 32rpx;
  gap: 8rpx;
}

.tx-empty-icon {
  font-size: 80rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
  margin-bottom: 8rpx;
}

.tx-empty-text {
  font-size: 28rpx;
  color: var(--color-text-secondary);
}

.tx-empty-sub {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}
</style>
