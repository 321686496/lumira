<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'
import { storageService } from '@/services/storage'

onLaunch(async () => {
  console.log('如画 Lumira 启动')
  await storageService.init()
})

onShow(() => {
  console.log('如画 Lumira 显示')
})

onHide(() => {
  console.log('如画 Lumira 后台')
})
</script>

<style lang="scss">
@import '@/theme/tokens.scss';

/* 全局重置 */
page {
  background-color: var(--color-bg-canvas);
  color: var(--color-text-primary);
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  max-width: 100vw;
  overflow-x: hidden;
  box-sizing: border-box;
  -webkit-font-smoothing: antialiased;
}

/* 所有元素 box-sizing */
view, text, image, scroll-view, swiper, swiper-item {
  box-sizing: border-box;
  max-width: 100%;
}

/* 隐藏滚动条 */
::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
  color: transparent;
}

/* uni-app H5 默认 tabBar 容器兜底隐藏 */
uni-tabbar,
.uni-app--showtabbar > uni-view {
  display: none !important;
  height: 0 !important;
}

/* #ifdef H5 */
uni-page-body,
uni-page {
  max-width: 100vw;
  overflow-x: hidden;
}
/* #endif */

/* 页面进入动画 */
.page-enter {
  animation: pageEnter var(--duration-page) var(--ease-default) both;
}

@keyframes pageEnter {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
