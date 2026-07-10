<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">穿搭日记</text>
      <view class="lumira-nav-right">
        <text class="ph ph-calendar nav-icon"></text>
      </view>
    </view>

    <!-- View Toggle -->
    <view class="toggle-wrap fade-up">
      <view class="toggle-group">
        <view
          class="toggle-item"
          :class="{ active: viewTab === 'outfit' }"
          @click="viewTab = 'outfit'"
        >
          <text class="toggle-text">穿搭日记</text>
        </view>
        <view
          class="toggle-item"
          :class="{ active: viewTab === 'shoot' }"
          @click="viewTab = 'shoot'"
        >
          <text class="toggle-text">拍摄日记</text>
        </view>
      </view>
    </view>

    <!-- Streak Banner -->
    <view class="streak-wrap fade-up fade-up-d1">
      <view class="streak-banner">
        <view class="streak-info">
          <view class="streak-title-row">
            <text class="streak-title">连续打卡 7 </text>
            <text class="ph ph-fire streak-fire-inline"></text>
          </view>
          <text class="streak-sub">继续保持，解锁「周更达人」徽章</text>
        </view>
        <text class="ph ph-fire streak-fire-big"></text>
      </view>
    </view>

    <!-- Timeline View -->
    <view class="timeline-wrap">
      <view class="lumira-section-title timeline-head">
        <text class="section-title-text">时间轴</text>
        <text class="mono-text">5篇</text>
      </view>

      <!-- Entry 循环 -->
      <view
        v-for="(entry, idx) in entries"
        :key="idx"
        class="timeline-entry fade-up"
        :class="delayClass(idx)"
      >
        <!-- 日期 -->
        <view class="entry-date">
          <text class="entry-weekday">{{ entry.weekday }}</text>
          <text class="entry-date-num" :class="{ today: idx === 0 }">{{ entry.date }}</text>
        </view>
        <!-- 双照片 -->
        <view class="entry-photos">
          <view v-for="(p, pi) in entry.photos" :key="pi" class="entry-photo-col">
            <view class="entry-img-wrap">
              <image class="entry-img" :src="p.img" mode="aspectFill" />
            </view>
            <view class="entry-tags">
              <view
                v-for="(tag, ti) in p.tags"
                :key="ti"
                class="lumira-tag"
                :class="tag.cls"
              >
                <text class="ph tag-icon" :class="tag.icon"></text>
                <text class="tag-text">{{ tag.label }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- FAB: Record Today -->
    <view class="fab" @click="goCapture">
      <text class="ph ph-pen fab-icon"></text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const viewTab = ref<'outfit' | 'shoot'>('outfit')

const entries = ref([
  {
    weekday: '周一',
    date: '07/09',
    photos: [
      {
        img: 'https://picsum.photos/seed/1926769/400/600',
        tags: [
          { cls: 'lumira-tag-gold', icon: 'ph-book-open', label: '日常通勤' },
          { cls: 'lumira-tag-green', icon: 'ph-smiley', label: '开心' }
        ]
      },
      {
        img: 'https://picsum.photos/seed/1153245/400/600',
        tags: [
          { cls: 'lumira-tag-red', icon: 'ph-camera', label: '街拍回眸' }
        ]
      }
    ]
  },
  {
    weekday: '周日',
    date: '07/08',
    photos: [
      {
        img: 'https://picsum.photos/seed/1038002/400/600',
        tags: [
          { cls: 'lumira-tag-gold', icon: 'ph-flower', label: '约会' },
          { cls: 'lumira-tag-green', icon: 'ph-heart', label: '甜蜜' }
        ]
      },
      {
        img: 'https://picsum.photos/seed/1239291/400/600',
        tags: [
          { cls: 'lumira-tag-red', icon: 'ph-leaf', label: '清新自然' }
        ]
      }
    ]
  },
  {
    weekday: '周六',
    date: '07/07',
    photos: [
      {
        img: 'https://picsum.photos/seed/774909/400/600',
        tags: [
          { cls: 'lumira-tag-gold', icon: 'ph-coffee', label: '咖啡馆' },
          { cls: 'lumira-tag-green', icon: 'ph-smiley', label: '放松' }
        ]
      },
      {
        img: 'https://picsum.photos/seed/2074130/400/600',
        tags: [
          { cls: 'lumira-tag-red', icon: 'ph-coffee', label: '咖啡日记' }
        ]
      }
    ]
  },
  {
    weekday: '周五',
    date: '07/06',
    photos: [
      {
        img: 'https://picsum.photos/seed/733872/400/600',
        tags: [
          { cls: 'lumira-tag-gold', icon: 'ph-buildings', label: '夜晚出行' },
          { cls: 'lumira-tag-green', icon: 'ph-smiley', label: '自信' }
        ]
      },
      {
        img: 'https://picsum.photos/seed/774095/400/600',
        tags: [
          { cls: 'lumira-tag-red', icon: 'ph-buildings', label: '都市夜景' }
        ]
      }
    ]
  },
  {
    weekday: '周四',
    date: '07/05',
    photos: [
      {
        img: 'https://picsum.photos/seed/414628/400/600',
        tags: [
          { cls: 'lumira-tag-gold', icon: 'ph-person-running', label: '运动装' },
          { cls: 'lumira-tag-green', icon: 'ph-lightning', label: '元气' }
        ]
      },
      {
        img: 'https://picsum.photos/seed/1926773/400/600',
        tags: [
          { cls: 'lumira-tag-red', icon: 'ph-tree', label: '公园随拍' }
        ]
      }
    ]
  }
])

const delayClass = (i: number) => {
  const d = (i % 5) + 1
  const map: Record<number, string> = {
    1: 'fade-up-d1',
    2: 'fade-up-d2',
    3: 'fade-up-d3',
    4: 'fade-up-d4',
    5: 'fade-up-d5'
  }
  return map[d] || 'fade-up-d1'
}

const back = () => uni.navigateBack()
const goCapture = () => uni.navigateTo({ url: '/pages/capture/index' })
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

/* 视图切换 */
.toggle-wrap {
  padding: 32rpx 48rpx 0;
}

.toggle-group {
  display: flex;
  background-color: $color-bg-surface;
  border-radius: 9999rpx;
  padding: 8rpx;
  border: 2rpx solid $color-border;
}

.toggle-item {
  flex: 1;
  padding: 16rpx 0;
  border-radius: 9999rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.toggle-item.active {
  background-color: $color-brand-primary;
}

.toggle-text {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-secondary;
}

.toggle-item.active .toggle-text {
  color: #fff;
}

/* 打卡 Banner */
.streak-wrap {
  padding: 32rpx 48rpx 0;
}

.streak-banner {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  border-radius: 24rpx;
  padding: 32rpx 40rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.streak-info {
  flex: 1;
}

.streak-title-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.streak-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 36rpx;
  font-weight: 600;
  color: #fff;
}

.streak-fire-inline {
  font-size: 36rpx;
  color: #fff;
}

.streak-sub {
  display: block;
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.8);
  margin-top: 8rpx;
}

.streak-fire-big {
  font-size: 72rpx;
  color: #fff;
}

/* 时间轴 */
.timeline-wrap {
  padding: 48rpx 48rpx 0;
}

.timeline-head {
  margin-bottom: 32rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.mono-text {
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: $color-text-secondary;
  letter-spacing: 0.02em;
}

.timeline-entry {
  display: flex;
  gap: 28rpx;
  padding-bottom: 40rpx;
  border-bottom: 2rpx solid $color-border;
  margin-bottom: 40rpx;
}

.timeline-entry:last-child {
  border-bottom: none;
  padding-bottom: 0;
  margin-bottom: 0;
}

/* 日期列 */
.entry-date {
  min-width: 112rpx;
  text-align: center;
}

.entry-weekday {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 22rpx;
  color: $color-text-tertiary;
}

.entry-date-num {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: $color-text-secondary;
  line-height: 1.2;
  margin-top: 4rpx;
}

.entry-date-num.today {
  color: $color-brand-primary;
}

/* 照片区 */
.entry-photos {
  flex: 1;
  display: flex;
  gap: 24rpx;
}

.entry-photo-col {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.entry-img-wrap {
  width: 100%;
  padding-bottom: 133.33%;
  position: relative;
  overflow: hidden;
  border-radius: 16rpx;
  margin-bottom: 16rpx;
}

.entry-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.entry-tags {
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.tag-icon {
  font-size: 24rpx;
}

.tag-text {
  font-size: 22rpx;
}

/* FAB */
.fab {
  position: fixed;
  bottom: 176rpx;
  right: 48rpx;
  width: 112rpx;
  height: 112rpx;
  border-radius: 50%;
  background-color: $color-brand-primary;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 32rpx rgba(201, 169, 110, 0.35);
  z-index: 850;
}

.fab-icon {
  font-size: 48rpx;
  color: #fff;
}
</style>
