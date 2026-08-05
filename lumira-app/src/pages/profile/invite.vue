<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="lumira-nav-title">邀请有礼</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- Hero 卡片 -->
      <view class="lumira-card hero-card fade-up">
        <view class="hero-img-wrap">
          <image class="hero-img" src="https://picsum.photos/seed/1926773/400/240" mode="aspectFill" />
        </view>
        <text class="hero-title">邀请好友，获得奖励</text>
        <text class="hero-desc">每邀请一位好友，双方各得 {{ rewardPointsPerInvite }} 积分</text>

        <!-- 我的邀请码 -->
        <view class="my-code-wrap">
          <text class="my-code-label">我的邀请码</text>
          <view class="my-code-row">
            <text class="my-code-value">{{ myCode || '生成中…' }}</text>
            <view v-if="myCode" class="my-code-copy" @click="copyCode">
              <text class="ph ph-copy"></text>
              <text class="my-code-copy-text">复制</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 邀请统计 -->
      <view class="lumira-card stats-card fade-up fade-up-d1">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">邀请统计</text>
        </view>
        <view class="stats-grid">
          <view class="stats-cell">
            <text class="stats-num">{{ statsLoading ? '…' : totalInvites }}</text>
            <text class="stats-label">累计邀请</text>
          </view>
          <view class="stats-cell">
            <text class="stats-num">{{ rewardPointsPerInvite }}</text>
            <text class="stats-label">每次奖励</text>
          </view>
          <view class="stats-cell">
            <text class="stats-num">{{ statsLoading ? '…' : totalEarnedFromInvite }}</text>
            <text class="stats-label">累计获得</text>
          </view>
        </view>
        <view class="balance-row">
          <text class="balance-label">当前积分余额</text>
          <text class="balance-value">{{ statsLoading ? '…' : currentBalance }}</text>
        </view>
      </view>

      <!-- 生成邀请卡片按钮 -->
      <view class="lumira-btn-brand invite-btn fade-up fade-up-d2" @click="genInviteCard">
        <text class="ph ph-paint-brush"></text>
        <text>生成邀请文案</text>
      </view>

      <!-- 输入好友邀请码 -->
      <view class="lumira-card code-card fade-up fade-up-d3">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">输入好友邀请码</text>
          <text v-if="boundCode" class="bound-code-text">已绑定</text>
        </view>
        <input
          v-if="!boundCode"
          class="code-input"
          v-model="inviteCodeInput"
          placeholder="粘贴好友的邀请码..."
          placeholder-class="code-placeholder"
          maxlength="32"
        />
        <view v-if="!boundCode" class="lumira-btn-outline code-btn" @click="handleBindCode">
          <text>{{ activating ? '绑定中…' : '确认绑定' }}</text>
        </view>
        <text v-else class="bound-tip">邀请码绑定后不可更换</text>
      </view>

      <!-- 说明 -->
      <view class="lumira-card tips-card fade-up fade-up-d4">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">活动说明</text>
        </view>
        <view class="tips-list">
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">每成功邀请一位好友注册，双方各得 {{ rewardPointsPerInvite }} 积分</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">每位用户仅能绑定一次好友邀请码，绑定后不可更换</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">邀请奖励积分将立即到账，可在积分钱包查看</text>
          </view>
          <view class="tips-item">
            <text class="ph ph-check tips-bullet"></text>
            <text class="tips-text">积分可用于解锁精选付费模板</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import {
  generateInviteCode,
  getInviteStats,
  activateInviteCode,
} from '@/api/points'
import { ApiError } from '@/utils/request'

const BOUND_KEY = 'lumira_invite_bound'

const myCode = ref('')
const totalInvites = ref(0)
const rewardPointsPerInvite = ref(50)
const totalEarnedFromInvite = ref(0)
const currentBalance = ref(0)
const statsLoading = ref(true)

const inviteCodeInput = ref('')
const boundCode = ref(uni.getStorageSync(BOUND_KEY) === true)
const activating = ref(false)

onShow(() => {
  ensureInviteCode()
  loadStats()
})

async function ensureInviteCode() {
  if (myCode.value) return
  try {
    const res = await generateInviteCode()
    myCode.value = res.inviteCode
  } catch {
    // 静默：未登录或网络异常，不阻塞页面
  }
}

async function loadStats() {
  statsLoading.value = true
  try {
    const res = await getInviteStats()
    totalInvites.value = res.totalInvites
    rewardPointsPerInvite.value = res.rewardPointsPerInvite
    totalEarnedFromInvite.value = res.totalEarnedFromInvite
    currentBalance.value = res.currentBalance
  } catch {
    // 静默
  } finally {
    statsLoading.value = false
  }
}

function copyCode() {
  if (!myCode.value) return
  uni.setClipboardData({
    data: myCode.value,
    success: () => uni.showToast({ title: '邀请码已复制', icon: 'success' }),
  })
}

function genInviteCard() {
  if (!myCode.value) {
    uni.showToast({ title: '邀请码生成中，请稍候', icon: 'none' })
    return
  }
  uni.setClipboardData({
    data: `一起来如画 Lumira 记录美好！使用我的邀请码 ${myCode.value} 注册，解锁专属模板。`,
    success: () => uni.showToast({ title: '邀请文案已复制，去分享吧', icon: 'none' }),
  })
}

async function handleBindCode() {
  if (activating.value) return
  const code = inviteCodeInput.value.trim()
  if (!code) {
    uni.showToast({ title: '请输入邀请码', icon: 'none' })
    return
  }
  activating.value = true
  uni.showLoading({ title: '绑定中…' })
  try {
    const res = await activateInviteCode(code)
    uni.hideLoading()
    boundCode.value = true
    uni.setStorageSync(BOUND_KEY, true)
    inviteCodeInput.value = ''
    uni.showToast({
      title: `绑定成功，获得 ${res.rewardPoints} 积分`,
      icon: 'none',
      duration: 2500,
    })
    // 刷新统计
    loadStats()
  } catch (err) {
    uni.hideLoading()
    const msg = err instanceof ApiError ? err.message : '绑定失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    activating.value = false
  }
}

const goBack = () => uni.navigateBack()
</script>

<style lang="scss" scoped>
.nav-back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.page-body {
  padding: 48rpx;
}

/* Hero 卡片 */
.hero-card {
  margin-bottom: 32rpx;
  text-align: center;
  overflow: hidden;
}

.hero-img-wrap {
  width: 100%;
  padding-bottom: 60%;
  position: relative;
  overflow: hidden;
  border-radius: 16rpx;
  margin-bottom: 32rpx;
}

.hero-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 8rpx;
}

.hero-desc {
  display: block;
  font-size: 26rpx;
  color: $color-text-secondary;
}

/* 我的邀请码 */
.my-code-wrap {
  margin-top: 32rpx;
  padding: 24rpx 32rpx;
  border-radius: 20rpx;
  background-color: rgba(201, 169, 110, 0.08);
  border: 2rpx dashed rgba(201, 169, 110, 0.3);
}

.my-code-label {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-bottom: 12rpx;
  letter-spacing: 0.04em;
}

.my-code-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.my-code-value {
  font-family: 'Courier New', monospace;
  font-size: 40rpx;
  font-weight: 700;
  color: $color-brand-primary;
  letter-spacing: 0.12em;
}

.my-code-copy {
  display: inline-flex;
  align-items: center;
  gap: 6rpx;
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  background-color: $color-brand-primary;
}

.my-code-copy .ph {
  font-size: 24rpx;
  color: #fff;
}

.my-code-copy-text {
  font-size: 22rpx;
  color: #fff;
  font-weight: 500;
}

/* 统计卡 */
.stats-card {
  margin-bottom: 32rpx;
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  text-align: center;
  margin-bottom: 24rpx;
}

.stats-cell {
  padding: 16rpx 8rpx;
  position: relative;
}

.stats-cell:not(:last-child)::after {
  content: '';
  position: absolute;
  right: 0;
  top: 24rpx;
  bottom: 24rpx;
  width: 2rpx;
  background: var(--color-divider);
}

.stats-num {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 44rpx;
  font-weight: 600;
  color: $color-text-primary;
  line-height: 1;
}

.stats-label {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 12rpx;
  letter-spacing: 0.04em;
}

.balance-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20rpx 32rpx;
  border-radius: 16rpx;
  background-color: $color-bg-surface;
}

.balance-label {
  font-size: 26rpx;
  color: $color-text-secondary;
}

.balance-value {
  font-family: 'Courier New', monospace;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-brand-primary;
}

/* 区块标题 */
.section-title-row {
  margin-bottom: 32rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

/* 邀请按钮 */
.invite-btn {
  margin-bottom: 32rpx;
}

/* 输入好友邀请码 */
.code-card {
  margin-bottom: 32rpx;
}

.code-input {
  width: 100%;
  padding: 24rpx 32rpx;
  border-radius: 16rpx;
  border: 2rpx solid $color-border;
  font-size: 28rpx;
  background-color: $color-bg-canvas;
  color: $color-text-primary;
  box-sizing: border-box;
}

.code-placeholder {
  color: $color-text-tertiary;
  font-size: 28rpx;
}

.code-btn {
  margin-top: 20rpx;
  padding: 20rpx 40rpx;
  font-size: 26rpx;
  width: auto;
  align-self: flex-start;
}

.bound-code-text {
  font-size: 24rpx;
  color: $color-brand-primary;
  font-weight: 500;
}

.bound-tip {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  margin-top: 8rpx;
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
  color: $color-brand-primary;
  margin-top: 4rpx;
  flex-shrink: 0;
}

.tips-text {
  flex: 1;
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 1.5;
}
</style>
