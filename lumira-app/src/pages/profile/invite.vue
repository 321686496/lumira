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
        <text class="hero-desc">邀请好友一起记录美好，解锁专属模板</text>
        <!-- 我的邀请码 -->
        <view class="my-code-wrap">
          <text class="my-code-label">我的邀请码</text>
          <view class="my-code-row">
            <text class="my-code-value">{{ myCode }}</text>
            <view class="my-code-copy" @click="copyCode">
              <text class="ph ph-copy"></text>
              <text class="my-code-copy-text">复制</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 奖励阶梯 -->
      <view class="lumira-card reward-card fade-up fade-up-d1">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">奖励阶梯</text>
        </view>
        <view class="reward-list">
          <view
            class="reward-item"
            :class="{ 'reward-done': r.done, 'reward-locked': r.locked }"
            v-for="(r, i) in rewards"
            :key="i"
          >
            <text class="ph reward-icon" :class="r.icon"></text>
            <view class="reward-body">
              <text class="reward-count">{{ r.count }} 人</text>
              <text class="reward-name">{{ r.name }}</text>
            </view>
            <text
              class="lumira-tag"
              :class="{ 'lumira-tag-gold': r.done }"
            >
              <text v-if="r.locked" class="ph ph-lock"></text>
              <text v-else>{{ r.status }}</text>
            </text>
          </view>
        </view>
      </view>

      <!-- 当前进度 -->
      <view class="lumira-card progress-card fade-up fade-up-d2">
        <view class="progress-head">
          <text class="progress-label">当前进度</text>
          <text class="progress-count">已邀请 {{ confirmedCount }} 位</text>
        </view>
        <view class="lumira-progress">
          <view class="lumira-progress-fill" :style="{ width: progressPercent + '%' }"></view>
        </view>
        <text class="progress-tip">{{ progressTip }}</text>
      </view>

      <!-- 生成邀请卡片按钮 -->
      <view class="lumira-btn-brand invite-btn fade-up fade-up-d3" @click="genInviteCard">
        <text class="ph ph-paint-brush"></text>
        <text>生成邀请卡片</text>
      </view>

      <!-- 输入好友邀请码 -->
      <view class="lumira-card code-card fade-up fade-up-d4">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">输入好友邀请码</text>
          <text v-if="boundCode" class="bound-code-text">已绑定：{{ boundCode }}</text>
        </view>
        <input
          v-if="!boundCode"
          class="code-input"
          v-model="inviteCodeInput"
          placeholder="粘贴好友的邀请码..."
          placeholder-class="code-placeholder"
        />
        <view v-if="!boundCode" class="lumira-btn-outline code-btn" @click="handleBindCode">
          <text>确认绑定</text>
        </view>
        <text v-else class="bound-tip">邀请码绑定后不可更换</text>
      </view>

      <!-- 邀请记录 -->
      <view class="lumira-card record-card fade-up fade-up-d5">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">邀请记录</text>
        </view>
        <view v-if="records.length > 0" class="record-list">
          <view
            class="record-item"
            :class="{ 'record-last': i === records.length - 1 }"
            v-for="(r, i) in records"
            :key="i"
          >
            <view class="record-avatar" :class="{ 'record-avatar-pending': r.status === 'pending' }">
              <text class="ph" :class="r.avatar"></text>
            </view>
            <view class="record-body">
              <text class="record-name">{{ r.name }}</text>
              <text class="record-date">{{ r.date }}</text>
            </view>
            <text
              class="lumira-tag"
              :class="{ 'lumira-tag-green': r.status === 'confirmed', 'record-tag-pending': r.status === 'pending' }"
            >{{ r.status === 'confirmed' ? '已确认' : '待确认' }}</text>
          </view>
        </view>
        <view v-else class="empty-records">
          <text class="ph ph-users empty-records-icon"></text>
          <text class="empty-records-text">还没有邀请记录</text>
          <text class="empty-records-sub">分享邀请码给好友开始吧</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useInvite } from '@/composables/useInvite'

const goBack = () => uni.navigateBack()

const {
  myCode,
  boundCode,
  records,
  confirmedCount,
  progressPercent,
  rewards,
  nextReward,
  bindCode,
} = useInvite()

const inviteCodeInput = ref('')

const progressTip = computed(() => {
  if (!nextReward.value) return '已达成所有奖励'
  const diff = nextReward.value.count - confirmedCount.value
  return `再邀请 ${diff} 人可解锁「${nextReward.value.name}」`
})

function copyCode() {
  uni.setClipboardData({
    data: myCode.value,
    success: () => uni.showToast({ title: '邀请码已复制', icon: 'success' }),
  })
}

function genInviteCard() {
  uni.setClipboardData({
    data: `一起来如画 Lumira 记录美好！使用我的邀请码 ${myCode.value} 注册，解锁专属模板。`,
    success: () => uni.showToast({ title: '邀请文案已复制，去分享吧', icon: 'none' }),
  })
}

function handleBindCode() {
  const result = bindCode(inviteCodeInput.value)
  uni.showToast({ title: result.message, icon: result.success ? 'success' : 'none' })
  if (result.success) {
    inviteCodeInput.value = ''
  }
}
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

/* 已绑定邀请码提示 */
.bound-code-text {
  font-size: 24rpx;
  color: $color-brand-primary;
  font-family: 'Courier New', monospace;
}

.bound-tip {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  margin-top: 8rpx;
}

/* 空邀请记录 */
.empty-records {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48rpx 32rpx;
  gap: 8rpx;
}

.empty-records-icon {
  font-size: 72rpx;
  color: $color-text-tertiary;
  opacity: 0.4;
  margin-bottom: 8rpx;
}

.empty-records-text {
  font-size: 28rpx;
  color: $color-text-secondary;
}

.empty-records-sub {
  font-size: 24rpx;
  color: $color-text-tertiary;
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

/* 奖励阶梯 */
.reward-card {
  margin-bottom: 32rpx;
}

.reward-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.reward-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 20rpx 24rpx;
  border-radius: 16rpx;
  border: 2rpx solid $color-border;
}

.reward-done {
  background-color: $color-tag-gold-bg;
  border-color: rgba(201, 169, 110, 0.3);
}

.reward-icon {
  font-size: 40rpx;
}

.reward-locked .reward-icon {
  color: $color-text-tertiary;
}

.reward-body {
  flex: 1;
  display: flex;
  align-items: center;
}

.reward-count {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.reward-name {
  font-size: 24rpx;
  color: $color-text-secondary;
  margin-left: 16rpx;
}

/* 当前进度 */
.progress-card {
  margin-bottom: 32rpx;
}

.progress-card .lumira-progress {
  height: 16rpx;
}

.progress-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20rpx;
}

.progress-label {
  font-size: 28rpx;
  color: $color-text-secondary;
}

.progress-count {
  font-family: 'Courier New', monospace;
  font-size: 26rpx;
  color: $color-text-primary;
  letter-spacing: 0.02em;
}

.progress-tip {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  margin-top: 16rpx;
}

/* 生成邀请卡片按钮 */
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

/* 邀请记录 */
.record-card {
  margin-bottom: 32rpx;
}

.record-list {
  display: flex;
  flex-direction: column;
}

.record-item {
  display: flex;
  align-items: center;
  gap: 20rpx;
  padding: 20rpx 0;
  border-bottom: 2rpx solid $color-border;
}

.record-last {
  border-bottom: none;
}

.record-avatar {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background-color: $color-tag-gold-bg;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.record-avatar .ph {
  font-size: 32rpx;
}

.record-avatar-pending {
  background-color: $color-bg-surface;
}

.record-body {
  flex: 1;
}

.record-name {
  display: block;
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.record-date {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 4rpx;
}

.record-tag-pending {
  background-color: $color-bg-surface;
  color: $color-text-tertiary;
}
</style>
