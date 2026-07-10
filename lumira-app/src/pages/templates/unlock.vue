<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-x close-icon"></text>
      </view>
      <text class="lumira-nav-title">解锁模板</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Content -->
    <view class="content-pad">
      <!-- Template Preview Card -->
      <view class="preview-card fade-up">
        <view class="preview-img-wrap">
          <image class="preview-img" src="https://picsum.photos/seed/1499327/800/600" mode="aspectFill" />
          <view class="lock-badge" :class="{ 'lock-badge-unlocked': unlocked }">
            <text class="ph" :class="unlocked ? 'ph-lock-open' : 'ph-lock'"></text>
          </view>
        </view>
        <view class="preview-body">
          <view class="preview-title-row">
            <text class="ph ph-star star-icon"></text>
            <text class="preview-title">日系胶片 · 精选模板</text>
          </view>
          <text class="preview-desc">包含 12 级胶片颗粒 · 暖调偏移 · 柔光晕影</text>
          <view class="preview-tags">
            <text class="lumira-tag lumira-tag-gold">胶片</text>
            <text class="lumira-tag lumira-tag-green">日系</text>
            <text class="lumira-tag tag-neutral">人像</text>
          </view>
        </view>
      </view>

      <!-- Unlock Subtitle -->
      <view v-if="!unlocked" class="subtitle-wrap fade-up fade-up-d1">
        <text class="subtitle">解锁方式任选其一</text>
        <text class="subtitle-desc">完成任意一项即可永久解锁</text>
      </view>

      <!-- Unlock Options -->
      <view v-if="!unlocked" class="options-list">
        <!-- Option 1: Watch Ad -->
        <view class="option-card fade-up fade-up-d1">
          <view class="option-row">
            <view class="option-left">
              <view class="list-icon">
                <text class="ph ph-monitor-play"></text>
              </view>
              <view class="option-text">
                <text class="list-title">看广告解锁（30秒）</text>
                <text class="list-desc">观看一段短视频广告即可解锁</text>
              </view>
            </view>
            <view class="btn-brand-sm" @click="onWatchAd">立即观看</view>
          </view>
        </view>

        <!-- Option 2: Share to Friends -->
        <view class="option-card fade-up fade-up-d2">
          <view class="option-head">
            <view class="list-icon">
              <text class="ph ph-paper-plane-tilt"></text>
            </view>
            <view class="option-text">
              <text class="list-title">分享给好友（2/3）</text>
              <text class="list-desc">累计分享 3 位好友即可解锁</text>
            </view>
          </view>
          <view class="lumira-progress progress-row">
            <view class="lumira-progress-fill" style="width: 67%;"></view>
          </view>
          <view class="btn-outline-sm" @click="onShare">继续分享</view>
        </view>

        <!-- Option 3: Take Photos -->
        <view class="option-card fade-up fade-up-d3">
          <view class="option-head">
            <view class="list-icon">
              <text class="ph ph-target"></text>
            </view>
            <view class="option-text">
              <text class="list-title">拍摄 5 张照片（3/5）</text>
              <text class="list-desc">完成 5 张拍摄任务即可解锁</text>
            </view>
          </view>
          <view class="lumira-progress progress-row">
            <view class="lumira-progress-fill" style="width: 60%;"></view>
          </view>
          <view class="btn-outline-sm" @click="onGoCapture">去拍摄</view>
        </view>

        <!-- Option 4: Redemption Code -->
        <view class="option-card fade-up fade-up-d4">
          <view class="option-row">
            <view class="option-left">
              <view class="list-icon">
                <text class="ph ph-key"></text>
              </view>
              <view class="option-text">
                <text class="list-title">输入兑换码</text>
                <text class="list-desc">使用兑换码直接解锁模板</text>
              </view>
            </view>
            <view class="btn-outline-sm" style="padding: 16rpx 40rpx;" @click="onInputCode">输入</view>
          </view>
        </view>

        <!-- Option 5: Direct Purchase -->
        <view class="option-card option-card-brand fade-up fade-up-d5">
          <view class="option-row">
            <view class="option-left">
              <view class="list-icon list-icon-gold">
                <text class="ph ph-diamond"></text>
              </view>
              <view class="option-text">
                <text class="list-title list-title-strong">¥3.00 直接购买</text>
                <text class="list-desc">一次购买，永久使用</text>
              </view>
            </view>
            <view class="neu-btn-brand" style="width: auto; padding: 16rpx 40rpx; flex-shrink: 0;" @click="onPurchase">购买</view>
          </view>
        </view>
      </view>

      <!-- Bottom Note -->
      <view v-if="!unlocked" class="bottom-note fade-in">
        <text class="ph ph-lock-open note-icon"></text>
        <text class="note-text">解锁后永久使用</text>
      </view>

      <!-- Unlock Success -->
      <view v-if="unlocked" class="success-card fade-up">
        <view class="success-icon-wrap">
          <text class="ph ph-check-circle success-icon"></text>
        </view>
        <text class="success-title">解锁成功</text>
        <text class="success-desc">日系胶片 · 精选模板已永久解锁</text>
        <view class="lumira-btn-brand success-btn" @click="onStartUse">开始使用</view>
      </view>
    </view>

    <!-- Pay Popup -->
    <view v-if="showPayPopup" class="pay-popup-mask" @click="onCancelPay">
      <view class="pay-popup" @click.stop>
        <text class="pay-popup-title">确认支付</text>
        <view class="pay-popup-price-row">
          <text class="pay-popup-price">¥3.00</text>
          <text class="pay-popup-desc">日系胶片 · 精选模板 · 永久使用</text>
        </view>
        <view class="pay-popup-actions">
          <view class="pay-popup-cancel" @click="onCancelPay">取消</view>
          <view class="neu-btn-brand pay-popup-confirm" @click="onConfirmPay">确认支付</view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const unlocked = ref(false)
const showPayPopup = ref(false)

const back = () => uni.navigateBack()

const onWatchAd = () => {
  uni.showToast({ title: '广告播放中…', icon: 'none' })
  setTimeout(() => {
    unlocked.value = true
    uni.showToast({ title: '解锁成功', icon: 'success' })
  }, 1200)
}

const onShare = () => {
  uni.showToast({ title: '分享成功 +1', icon: 'none' })
}

const onGoCapture = () => {
  uni.navigateTo({ url: '/pages/capture/index' })
}

const onInputCode = () => {
  uni.showModal({
    title: '输入兑换码',
    editable: true,
    placeholderText: '请输入兑换码',
    success: (res) => {
      if (res.confirm && res.content) {
        unlocked.value = true
        uni.showToast({ title: '解锁成功', icon: 'success' })
      }
    }
  })
}

const onPurchase = () => {
  showPayPopup.value = true
}

const onConfirmPay = () => {
  showPayPopup.value = false
  unlocked.value = true
  uni.showToast({ title: '解锁成功', icon: 'success' })
}

const onCancelPay = () => {
  showPayPopup.value = false
}

const onStartUse = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.close-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.content-pad {
  padding: 48rpx 48rpx 0;
}

/* Preview card */
.preview-card {
  border-radius: 28rpx;
  border: 2rpx solid var(--color-divider);
  background: linear-gradient(135deg, var(--color-surface) 0%, var(--color-canvas) 100%);
  box-shadow: var(--shadow-convex);
  overflow: hidden;
}

.preview-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 56.25%;
  overflow: hidden;
}

.preview-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.lock-badge {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: rgba(26, 26, 26, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
}

.lock-badge .ph {
  font-size: 24rpx;
  color: #fff;
}

.lock-badge-unlocked {
  background-color: var(--color-success);
}

.preview-body {
  padding: 40rpx;
}

.preview-title-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
  margin-bottom: 8rpx;
}

.star-icon {
  font-size: 30rpx;
  color: var(--color-brand);
}

.preview-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.preview-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

.preview-tags {
  display: flex;
  gap: 16rpx;
  margin-top: 24rpx;
}

.tag-neutral {
  background-color: var(--color-surface-alt);
  color: var(--color-text-secondary);
}

/* Subtitle */
.subtitle-wrap {
  text-align: center;
  padding: 64rpx 0 40rpx;
}

.subtitle {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.subtitle-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}

/* Options */
.options-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.option-card {
  border-radius: 28rpx;
  border: 2rpx solid var(--color-divider);
  background: linear-gradient(135deg, var(--color-surface) 0%, var(--color-canvas) 100%);
  box-shadow: var(--shadow-convex);
  padding: 32rpx;
}

.option-card-brand {
  border-color: var(--color-brand);
}

.option-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
}

.option-left {
  display: flex;
  align-items: center;
  gap: 24rpx;
  flex: 1;
  min-width: 0;
}

.option-head {
  display: flex;
  align-items: center;
  gap: 24rpx;
  margin-bottom: 24rpx;
}

.list-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.list-icon .ph {
  font-size: 40rpx;
  color: var(--color-brand);
}

.list-icon-gold {
  background-color: var(--color-brand-subtle);
}

.option-text {
  flex: 1;
  min-width: 0;
}

.list-title {
  display: block;
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.list-title-strong {
  font-weight: 600;
}

.list-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
}

.progress-row {
  margin-bottom: 24rpx;
}

/* Buttons */
.btn-brand-sm {
  background-color: var(--color-brand);
  color: var(--color-text-inverse);
  border: none;
  border-radius: 16rpx;
  box-shadow: var(--shadow-convex-brand);
  padding: 16rpx 32rpx;
  font-size: 26rpx;
  font-weight: 500;
  flex-shrink: 0;
  line-height: 1;
}

.btn-outline-sm {
  border: 2rpx solid var(--color-divider);
  color: var(--color-text-primary);
  border-radius: 16rpx;
  padding: 20rpx 48rpx;
  font-size: 26rpx;
  font-weight: 500;
  text-align: center;
  line-height: 1;
}

/* Bottom note */
.bottom-note {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  padding: 64rpx 0 48rpx;
}

.note-icon {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.note-text {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.02em;
}

/* ===== 解锁成功 ===== */
.success-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx 48rpx;
  text-align: center;
}

.success-icon-wrap {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background-color: var(--color-success-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 32rpx;
}

.success-icon {
  font-size: 64rpx;
  color: var(--color-success);
}

.success-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 12rpx;
}

.success-desc {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  margin-bottom: 56rpx;
}

.success-btn {
  width: 100%;
}

/* ===== 付费弹窗 ===== */
.pay-popup-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.pay-popup {
  width: 600rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;
  padding: 48rpx 40rpx 40rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  box-shadow: var(--shadow-float);
}

.pay-popup-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 32rpx;
}

.pay-popup-price-row {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 40rpx;
}

.pay-popup-price {
  font-size: 72rpx;
  font-weight: 700;
  color: var(--color-brand);
  line-height: 1;
  margin-bottom: 12rpx;
}

.pay-popup-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.pay-popup-actions {
  display: flex;
  gap: 24rpx;
  width: 100%;
}

.pay-popup-cancel {
  flex: 1;
  text-align: center;
  padding: 28rpx 0;
  border-radius: 16rpx;
  border: 2rpx solid var(--color-divider);
  color: var(--color-text-secondary);
  font-size: 30rpx;
  font-weight: 500;
  line-height: 1;
}

.pay-popup-confirm {
  flex: 1;
}
</style>
