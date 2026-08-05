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
          <image class="preview-img" :src="coverImage" mode="aspectFill" />
          <view class="lock-badge" :class="{ 'lock-badge-unlocked': unlocked }">
            <text class="ph" :class="unlocked ? 'ph-lock-open' : 'ph-lock'"></text>
          </view>
        </view>
        <view class="preview-body">
          <view class="preview-title-row">
            <text class="ph ph-star star-icon"></text>
            <text class="preview-title">{{ templateName }}</text>
          </view>
          <text class="preview-desc">{{ templateDesc }}</text>
          <view class="preview-tags">
            <text class="lumira-tag lumira-tag-gold">精选</text>
            <text class="lumira-tag tag-neutral">付费</text>
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
                <text class="list-desc">敬请期待</text>
              </view>
            </view>
            <view class="btn-outline-sm btn-disabled">敬请期待</view>
          </view>
        </view>

        <!-- Option 2: Share to Friends -->
        <view class="option-card fade-up fade-up-d2">
          <view class="option-head">
            <view class="list-icon">
              <text class="ph ph-paper-plane-tilt"></text>
            </view>
            <view class="option-text">
              <text class="list-title">分享给好友</text>
              <text class="list-desc">敬请期待</text>
            </view>
          </view>
          <view class="btn-outline-sm btn-disabled">敬请期待</view>
        </view>

        <!-- Option 3: Redemption Code -->
        <view class="option-card fade-up fade-up-d3">
          <view class="option-row">
            <view class="option-left">
              <view class="list-icon">
                <text class="ph ph-key"></text>
              </view>
              <view class="option-text">
                <text class="list-title">输入兑换码</text>
                <text class="list-desc">使用兑换码获取积分后兑换</text>
              </view>
            </view>
            <view class="btn-outline-sm" style="padding: 16rpx 40rpx;" @click="onInputCode">输入</view>
          </view>
        </view>

        <!-- Option 4: Exchange with Points -->
        <view class="option-card option-card-brand fade-up fade-up-d4">
          <view class="option-row">
            <view class="option-left">
              <view class="list-icon list-icon-gold">
                <text class="ph ph-diamond"></text>
              </view>
              <view class="option-text">
                <text class="list-title list-title-strong">{{ priceCredits }} 积分兑换</text>
                <text class="list-desc">当前余额 {{ currentBalance }} 积分 · 永久使用</text>
              </view>
            </view>
            <view
              class="neu-btn-brand"
              :class="{ 'btn-loading': exchanging }"
              style="width: auto; padding: 16rpx 40rpx; flex-shrink: 0;"
              @click="onPurchase"
            >{{ exchanging ? '兑换中…' : '兑换' }}</view>
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
        <text class="success-desc">{{ templateName }} 已永久解锁</text>
        <view class="lumira-btn-brand success-btn" @click="onStartUse">开始使用</view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import {
  exchangeTemplate,
  redeemCode,
  getOwnedTemplates,
  getTemplatePrices,
  getPointsBalance,
} from '@/api/points'
import { ApiError } from '@/utils/request'

const { loadTemplate } = useTemplate()

const templateId = ref('')
const templateName = ref('精选模板')
const templateDesc = ref('付费精选模板，永久解锁')
const coverImage = ref('https://picsum.photos/seed/1499327/800/600')

const unlocked = ref(false)
const priceCredits = ref(100)
const currentBalance = ref(0)
const exchanging = ref(false)

onLoad((options) => {
  const id = options?.templateId
  if (id) {
    templateId.value = id
    const tpl = loadTemplate(id)
    if (tpl) {
      templateName.value = tpl.meta.name
      templateDesc.value = tpl.meta.description || '付费精选模板，永久解锁'
      coverImage.value = tpl.meta.cover || `https://picsum.photos/seed/${id}/800/600`
    }
  }
  // 加载价格、余额、已拥有状态
  loadUnlockInfo()
})

async function loadUnlockInfo() {
  try {
    const [prices, balance, owned] = await Promise.all([
      getTemplatePrices().catch(() => null),
      getPointsBalance().catch(() => null),
      getOwnedTemplates().catch(() => null),
    ])
    if (prices) {
      const p = prices.prices.find(x => x.templateId === templateId.value)
      if (p) priceCredits.value = p.priceCredits
    }
    if (balance) {
      currentBalance.value = balance.balance
    }
    if (owned) {
      if (owned.templateIds.includes(templateId.value)) {
        unlocked.value = true
      }
    }
  } catch {
    // 静默：保持默认值
  }
}

const back = () => uni.navigateBack()

const onInputCode = () => {
  uni.showModal({
    title: '输入兑换码',
    editable: true,
    placeholderText: '请输入兑换码',
    success: async (res) => {
      if (!res.confirm || !res.content) return
      const code = res.content.trim()
      if (!code) return
      uni.showLoading({ title: '兑换中…' })
      try {
        const result = await redeemCode(code)
        uni.hideLoading()
        uni.showToast({
          title: `获得 ${result.rewardPoints} 积分，余额 ${result.balance}`,
          icon: 'none',
          duration: 2500,
        })
        currentBalance.value = result.balance
      } catch (err) {
        uni.hideLoading()
        const msg = err instanceof ApiError ? err.message : '兑换失败'
        uni.showToast({ title: msg, icon: 'none' })
      }
    },
  })
}

const onPurchase = async () => {
  if (exchanging.value || unlocked.value) return
  if (!templateId.value) {
    uni.showToast({ title: '模板信息缺失', icon: 'none' })
    return
  }
  if (currentBalance.value < priceCredits.value) {
    uni.showToast({
      title: `积分不足，还差 ${priceCredits.value - currentBalance.value} 积分`,
      icon: 'none',
      duration: 2500,
    })
    return
  }
  uni.showLoading({ title: '兑换中…' })
  try {
    const result = await exchangeTemplate(templateId.value)
    uni.hideLoading()
    if (result.success) {
      unlocked.value = true
      currentBalance.value = result.balance
      uni.showToast({ title: '解锁成功', icon: 'success' })
    } else {
      uni.showToast({ title: '兑换失败', icon: 'none' })
    }
  } catch (err) {
    uni.hideLoading()
    const msg = err instanceof ApiError ? err.message : '兑换失败'
    uni.showToast({ title: msg, icon: 'none' })
  }
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
  background: var(--color-canvas);
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
  background: var(--color-canvas);
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

/* Buttons */
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

.btn-disabled {
  opacity: 0.5;
  border-style: dashed;
  color: var(--color-text-tertiary);
}

.btn-loading {
  opacity: 0.6;
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
</style>
