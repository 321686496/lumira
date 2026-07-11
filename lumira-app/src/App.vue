<script setup lang="ts">
import { onLaunch } from "@dcloudio/uni-app";
import { useTheme } from "@/composables/useTheme";

const { loadTheme, loadStyle } = useTheme();

onLaunch(() => {
  console.log("如画 Lumira App Launch");
  loadTheme();
  loadStyle();

  // 滚动感知标题栏：滚动超过阈值时添加 .scrolled 类触发毛玻璃效果
  if (typeof window !== "undefined") {
    const updateNavScroll = () => {
      const scrollTop =
        window.scrollY || document.documentElement.scrollTop || 0;
      document.querySelectorAll<HTMLElement>(".lumira-nav").forEach((nav) => {
        nav.classList.toggle("scrolled", scrollTop > 20);
      });
    };
    window.addEventListener("scroll", updateNavScroll, { passive: true });
    window.addEventListener("pageshow", updateNavScroll);
    // 首次执行一次
    updateNavScroll();
  }
});
</script>

<style>
/* ===== 主题 CSS 变量 ===== */
:root {
  /* 暖米白主题（默认） */
  --color-canvas: #FAF7F2;
  --color-canvas-rgb: 250, 247, 242;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F2EEE6;
  --color-canvas-deep: #F5F1EB;
  --color-text-primary: #1A1A1A;
  --color-text-secondary: #5C5852;
  --color-text-tertiary: #9C9690;
  --color-text-inverse: #FAF7F2;
  --color-divider: #EAE5DC;
  --color-brand: #C9A96E;
  --color-brand-deep: #A88550;
  --color-brand-light: #D4B57A;
  --color-brand-subtle: #F5EDDB;
  --color-brand-text: #8C7340;
  --color-brand-rgb: 201, 169, 110;
  --color-danger: #B85450;
  --color-danger-subtle: #F5E3E0;
  --color-success: #7A8B5C;
  --color-success-subtle: #EBEEE2;

  /* 新拟态阴影 */
  --shadow-convex: 6px 6px 14px #D8D4CC, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #E0DCD4, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #B89A5E, -4px -4px 10px #DABB82;
  --shadow-concave: inset 4px 4px 10px #E0DCD4, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #E5E0D8, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E0DCD4, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(26, 26, 26, 0.08);

  /* 风格基础变量（新拟态默认值） */
  --card-border: none;
  --card-radius: 28rpx;
  --surface-alpha: 1;

  /* 字体 */
  --font-cn-title: 'Noto Serif SC', 'Source Han Serif SC', serif;
  --font-cn-body: 'Noto Sans SC', 'PingFang SC', sans-serif;
}

/* 浓墨主题 */
[data-theme="ink"] {
  --color-canvas: #1C1A17;
  --color-canvas-rgb: 28, 26, 23;
  --color-surface: #262320;
  --color-surface-alt: #2E2B27;
  --color-canvas-deep: #151310;
  --color-text-primary: #F2EEE6;
  --color-text-secondary: #A39D94;
  --color-text-tertiary: #6E695F;
  --color-divider: #3A3630;
  --color-brand: #D4B57A;
  --color-brand-deep: #B8985A;
  --color-brand-subtle: #2E2820;
  --color-brand-text: #D4B57A;
  --color-brand-rgb: 212, 181, 122;
  --color-danger: #D4706C;
  --color-danger-subtle: #2E201E;
  --color-success: #8FA06A;
  --color-success-subtle: #22251D;

  --shadow-convex: 6px 6px 14px #13110E, -6px -6px 14px #29251F;
  --shadow-convex-subtle: 3px 3px 6px #1A1714, -3px -3px 6px #2E2B24;
  --shadow-convex-brand: 4px 4px 10px #1A1610, -4px -4px 10px #3E3624;
  --shadow-concave: inset 4px 4px 10px #141210, inset -4px -4px 10px #302C25;
  --shadow-concave-subtle: inset 2px 2px 5px #1A1714, inset -2px -2px 5px #2E2B24;
  --shadow-pressed: inset 3px 3px 8px #141210, inset -3px -3px 8px #302C25;
  --shadow-float: 0 8px 32px rgba(0, 0, 0, 0.3);
}

/* 胶片复古主题 */
[data-theme="retro"] {
  --color-canvas: #F5E6D3;
  --color-canvas-rgb: 245, 230, 211;
  --color-surface: #FFF8F0;
  --color-surface-alt: #EBDAC4;
  --color-canvas-deep: #EBDAC4;
  --color-text-primary: #3D2817;
  --color-text-secondary: #6B4C2F;
  --color-text-tertiary: #9C8060;
  --color-divider: #D9C9B3;
  --color-brand: #C4956A;
  --color-brand-deep: #A67B52;
  --color-brand-subtle: #F0E0C8;
  --color-brand-text: #8C5A30;
  --color-brand-rgb: 196, 149, 106;
  --color-danger: #A04030;
  --color-danger-subtle: #F0D8D0;
  --color-success: #6B7B4C;
  --color-success-subtle: #E8EDDF;

  --shadow-convex: 5px 5px 12px #CFC0AB, -5px -5px 12px #FFFDF7;
  --shadow-convex-subtle: 3px 3px 6px #D5C6B0, -3px -3px 6px #FFFDF7;
  --shadow-concave: inset 4px 4px 8px #D0C1AC, inset -4px -4px 8px #FFFDF7;
  --shadow-concave-subtle: inset 2px 2px 5px #D5C6B0, inset -2px -2px 5px #FFFDF7;
  --shadow-pressed: inset 3px 3px 6px #D0C1AC, inset -3px -3px 6px #FFFDF7;
  --shadow-convex-brand: 4px 4px 10px #B08560, -4px -4px 10px #DAA577;
  --shadow-float: 0 8px 32px rgba(61, 40, 23, 0.1);
}

/* 日系清新主题 */
[data-theme="fresh"] {
  --color-canvas: #F8FAF6;
  --color-canvas-rgb: 248, 250, 246;
  --color-surface: #FFFFFF;
  --color-surface-alt: #EDF2EB;
  --color-canvas-deep: #E8EDE5;
  --color-text-primary: #4A3F35;
  --color-text-secondary: #8C7F70;
  --color-text-tertiary: #B8AEA0;
  --color-divider: #DDE5D8;
  --color-brand: #8BAD72;
  --color-brand-deep: #6E9458;
  --color-brand-subtle: #E8F0E2;
  --color-brand-text: #5E8348;
  --color-brand-rgb: 139, 173, 114;
  --color-danger: #C87878;
  --color-danger-subtle: #F5E0E0;
  --color-success: #9AAB7C;
  --color-success-subtle: #EDF2E8;

  --shadow-convex: 6px 6px 14px #D4DBD0, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #D8DFD4, -3px -3px 6px #FFFFFF;
  --shadow-concave: inset 4px 4px 10px #D6DDD2, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #D8DFD4, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #D6DDD2, inset -3px -3px 8px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #7A9B62, -4px -4px 10px #9CC084;
  --shadow-float: 0 8px 32px rgba(74, 63, 53, 0.08);
}

/* 温馨粉主题 */
[data-theme="cozy"] {
  --color-canvas: #FFF5F5;
  --color-canvas-rgb: 255, 245, 245;
  --color-surface: #FFFFFF;
  --color-surface-alt: #FAEDED;
  --color-canvas-deep: #F5EAEA;
  --color-text-primary: #4A3A3A;
  --color-text-secondary: #8C7070;
  --color-text-tertiary: #B89A9A;
  --color-divider: #F0E0E0;
  --color-brand: #E8A0A0;
  --color-brand-deep: #D4858A;
  --color-brand-light: #F0B5B5;
  --color-brand-subtle: #FCE8E8;
  --color-brand-text: #C47070;
  --color-brand-rgb: 232, 160, 160;
  --color-danger: #D47070;
  --color-danger-subtle: #FCE8E8;
  --color-success: #8FB088;
  --color-success-subtle: #EDF2E8;

  --shadow-convex: 6px 6px 14px #F0E0E0, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #F2E2E2, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #D4858A, -4px -4px 10px #F0B5B5;
  --shadow-concave: inset 4px 4px 10px #F0E0E0, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #F2E2E2, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #F0E0E0, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(74, 58, 58, 0.08);
}

/* 马卡龙主题 */
[data-theme="macaron"] {
  --color-canvas: #FFF8F0;
  --color-canvas-rgb: 255, 248, 240;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F5F0E8;
  --color-canvas-deep: #F0EAE0;
  --color-text-primary: #5A4A4A;
  --color-text-secondary: #8C7A7A;
  --color-text-tertiary: #B8A8A0;
  --color-divider: #E8E0D5;
  --color-brand: #A8D8C8;
  --color-brand-deep: #8CC5B5;
  --color-brand-light: #C5E8DD;
  --color-brand-subtle: #E0F0EA;
  --color-brand-text: #5E9882;
  --color-brand-rgb: 168, 216, 200;
  --color-danger: #E8A0A0;
  --color-danger-subtle: #FCE8E8;
  --color-success: #A8D8C8;
  --color-success-subtle: #E0F0EA;

  --shadow-convex: 6px 6px 14px #E8E0D5, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #EDE5D8, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #8CC5B5, -4px -4px 10px #C5E8DD;
  --shadow-concave: inset 4px 4px 10px #E8E0D5, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #EDE5D8, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E8E0D5, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(90, 74, 74, 0.08);
}

/* 莫兰迪主题 */
[data-theme="morandi"] {
  --color-canvas: #E8E4E0;
  --color-canvas-rgb: 232, 228, 224;
  --color-surface: #F2EFEA;
  --color-surface-alt: #E0DCD6;
  --color-canvas-deep: #DDD9D3;
  --color-text-primary: #4A4540;
  --color-text-secondary: #7A7570;
  --color-text-tertiary: #A8A29C;
  --color-divider: #D5D0CA;
  --color-brand: #8B9DAF;
  --color-brand-deep: #6B7D8F;
  --color-brand-light: #A8B8C8;
  --color-brand-subtle: #D5DDE5;
  --color-brand-text: #5B6D7F;
  --color-brand-rgb: 139, 157, 175;
  --color-danger: #A88080;
  --color-danger-subtle: #E8DDDD;
  --color-success: #8FA590;
  --color-success-subtle: #DDE5DD;

  --shadow-convex: 6px 6px 14px #D5D0CA, -6px -6px 14px #F2EFEA;
  --shadow-convex-subtle: 3px 3px 6px #D8D3CD, -3px -3px 6px #F2EFEA;
  --shadow-convex-brand: 4px 4px 10px #6B7D8F, -4px -4px 10px #A8B8C8;
  --shadow-concave: inset 4px 4px 10px #D5D0CA, inset -4px -4px 10px #F2EFEA;
  --shadow-concave-subtle: inset 2px 2px 5px #D8D3CD, inset -2px -2px 5px #F2EFEA;
  --shadow-pressed: inset 3px 3px 8px #D5D0CA, inset -3px -3px 8px #F2EFEA;
  --shadow-float: 0 8px 32px rgba(74, 69, 64, 0.08);
}

/* 玫瑰金主题 */
[data-theme="rosegold"] {
  --color-canvas: #FAF6F2;
  --color-canvas-rgb: 250, 246, 242;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F5EDE8;
  --color-canvas-deep: #F0E8E2;
  --color-text-primary: #3D2E2A;
  --color-text-secondary: #6B5450;
  --color-text-tertiary: #A89088;
  --color-divider: #E8DDD5;
  --color-brand: #C9A0A0;
  --color-brand-deep: #B08585;
  --color-brand-light: #DDB8B8;
  --color-brand-subtle: #F0E0E0;
  --color-brand-text: #A06868;
  --color-brand-rgb: 201, 160, 160;
  --color-danger: #C47878;
  --color-danger-subtle: #F0E0E0;
  --color-success: #9AB088;
  --color-success-subtle: #E8F0E0;

  --shadow-convex: 6px 6px 14px #E8DDD5, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #EDE2DA, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #B08585, -4px -4px 10px #DDB8B8;
  --shadow-concave: inset 4px 4px 10px #E8DDD5, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #EDE2DA, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E8DDD5, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(61, 46, 42, 0.08);
}

/* ===== UI 风格变量重定义 ===== */

/* 扁平化风格 */
[data-style="flat"] {
  --shadow-convex: none;
  --shadow-concave: none;
  --shadow-convex-subtle: none;
  --shadow-concave-subtle: none;
  --shadow-pressed: none;
  --shadow-convex-brand: none;
  --shadow-float: none;
  --card-border: 1rpx solid var(--color-divider);
  --card-radius: 20rpx;
  --surface-alpha: 1;
}

/* 玻璃拟态风格 */
[data-style="glass"] {
  --shadow-convex: 0 8px 32px rgba(0,0,0,0.08);
  --shadow-concave: inset 0 2px 8px rgba(0,0,0,0.06);
  --shadow-convex-subtle: 0 4px 16px rgba(0,0,0,0.06);
  --shadow-concave-subtle: inset 0 1px 4px rgba(0,0,0,0.04);
  --shadow-pressed: inset 0 2px 8px rgba(0,0,0,0.08);
  --shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.3);
  --shadow-float: 0 8px 32px rgba(0,0,0,0.08);
  --card-border: 1rpx solid rgba(255,255,255,0.3);
  --card-radius: 28rpx;
  --surface-alpha: 0.55;
}

/* 女性美学风格 */
[data-style="female"] {
  --shadow-convex: 0 8px 32px rgba(var(--color-brand-rgb), 0.15);
  --shadow-concave: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.08);
  --shadow-convex-subtle: 0 4px 16px rgba(var(--color-brand-rgb), 0.1);
  --shadow-concave-subtle: inset 0 1px 4px rgba(var(--color-brand-rgb), 0.05);
  --shadow-pressed: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.1);
  --shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.25);
  --shadow-float: 0 8px 32px rgba(var(--color-brand-rgb), 0.12);
  --card-border: none;
  --card-radius: 48rpx;
  --surface-alpha: 0.75;
}

/* ===== 全局重置（仅 class 选择器） ===== */
page {
  background-color: var(--color-canvas);
  transition: background-color 0.3s ease, color 0.3s ease;
}

/* ===== 容器 ===== */
.lumira-container {
  position: relative;
  width: 100%;
  min-height: 100vh;
  background-color: var(--color-canvas);
  padding-bottom: 176rpx;
  overflow-x: hidden;
  transition: background-color 0.3s ease;
}

.lumira-container.no-tabbar {
  padding-bottom: 0;
}

/* ===== 顶部导航 ===== */
.lumira-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20rpx 40rpx;
  padding-top: calc(20rpx + env(safe-area-inset-top, 0));
  min-height: 96rpx;
  background-color: transparent;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
  transition:
    background-color 0.4s cubic-bezier(0.16, 1, 0.3, 1),
    backdrop-filter 0.4s cubic-bezier(0.16, 1, 0.3, 1),
    border-color 0.4s ease,
    box-shadow 0.4s ease;
  border-bottom: 1rpx solid transparent;
}

/* 滚动后毛玻璃态（JS 滚动监听添加 .scrolled 类） */
.lumira-nav.scrolled {
  background-color: rgba(var(--color-canvas-rgb, 250, 247, 242), 0.72);
  backdrop-filter: blur(28px) saturate(1.8);
  -webkit-backdrop-filter: blur(28px) saturate(1.8);
  border-bottom: 1rpx solid var(--color-divider);
  box-shadow: 0 1rpx 12rpx rgba(0, 0, 0, 0.03);
}

/* 兼容旧 .translucent 修饰类（已废弃，保留向后兼容） */
.lumira-nav.translucent {
  background-color: transparent !important;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}

.lumira-nav-left {
  display: flex;
  align-items: center;
  gap: 12rpx;
  min-width: 64rpx;
  min-height: 64rpx;
}

.lumira-nav-right {
  display: flex;
  align-items: center;
  gap: 8rpx;
  min-width: 64rpx;
  min-height: 64rpx;
  justify-content: flex-end;
}

.lumira-nav-title {
  font-family: var(--font-cn-title);
  font-size: 38rpx;
  font-weight: 600;
  text-align: left;
  flex: 1;
  letter-spacing: 0.04em;
  padding-left: 12rpx;
  color: var(--color-text-primary);
  line-height: 1.3;
  transition: color 0.3s ease;
}

.lumira-nav-btn {
  background: none;
  border: none;
  color: var(--color-text-primary);
  padding: 12rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
  border-radius: 16rpx;
}

/* 导航图标统一样式 */
.lumira-nav .ph,
.lumira-nav-left .ph,
.lumira-nav-right .ph {
  font-size: 40rpx;
  color: var(--color-text-secondary);
  transition: color 0.2s ease;
}

.lumira-nav .ph:active {
  color: var(--color-brand);
}

/* 返回按钮圆形毛玻璃背景 */
.lumira-nav-left .ph.ph-caret-left,
.lumira-nav-left .ph.ph-arrow-left,
.lumira-nav-left .ph.ph-x {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background-color: var(--color-surface);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-subtle);
  font-size: 36rpx;
  color: var(--color-text-primary);
}

.lumira-nav-left .ph.ph-caret-left:active,
.lumira-nav-left .ph.ph-arrow-left:active,
.lumira-nav-left .ph.ph-x:active {
  box-shadow: var(--shadow-concave-subtle);
  color: var(--color-brand);
}

/* ===== 悬浮 Tab 栏（新拟态） ===== */
.floating-tabbar {
  position: fixed !important;
  left: 50%;
  transform: translateX(-50%);
  bottom: 28rpx;
  width: calc(100% - 80rpx);
  height: 108rpx;
  display: flex;
  align-items: center;
  justify-content: space-around;
  border-radius: 9999rpx;
  border: none;
  background-color: var(--color-canvas);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  box-shadow: var(--shadow-convex);
  z-index: 900;
  transition: background-color 0.3s ease, box-shadow 0.3s ease;
}

.tabbar-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2rpx;
  background: none;
  border: none;
  color: var(--color-text-tertiary);
  padding: 8rpx 24rpx;
  position: relative;
  line-height: 1;
  transition: color 0.2s ease;
}

.tabbar-item.active {
  color: var(--color-brand);
}

.tabbar-item:active {
  transform: scale(0.92);
}

.tabbar-label {
  font-size: 20rpx;
  letter-spacing: 0.04em;
  font-weight: 500;
}

.tabbar-center {
  width: 100rpx;
  height: 100rpx;
  border-radius: 50%;
  background: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-inverse);
  transform: translateY(-12rpx);
  box-shadow: var(--shadow-convex-brand);
  border: none;
  flex-shrink: 0;
  line-height: 1;
}

.tabbar-center:active {
  transform: translateY(-12rpx) scale(0.92);
}

/* ===== 按钮 ===== */
.lumira-btn-primary {
  background-color: var(--color-text-primary);
  color: var(--color-canvas);
  border-radius: 16rpx;
  padding: 28rpx 48rpx;
  font-size: 30rpx;
  font-weight: 500;
  border: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  line-height: 1;
}

.lumira-btn-primary:active {
  transform: scale(0.97);
}

.lumira-btn-brand {
  background: var(--color-brand);
  color: var(--color-text-inverse);
  border-radius: 16rpx;
  padding: 28rpx 48rpx;
  font-size: 30rpx;
  font-weight: 500;
  border: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  line-height: 1;
  box-shadow: var(--shadow-convex-brand);
}

.lumira-btn-brand:active {
  transform: scale(0.97);
  box-shadow: var(--shadow-pressed);
}

.lumira-btn-outline {
  background: transparent;
  color: var(--color-text-primary);
  border-radius: 16rpx;
  padding: 28rpx 48rpx;
  font-size: 30rpx;
  font-weight: 500;
  border: 3rpx solid var(--color-divider);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  line-height: 1;
}

.lumira-btn-outline:active {
  transform: scale(0.97);
}

.lumira-btn-ghost {
  background-color: var(--color-surface-alt);
  color: var(--color-text-secondary);
  border-radius: 16rpx;
  padding: 20rpx 32rpx;
  font-size: 26rpx;
  border: none;
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
  line-height: 1;
}

/* ===== 卡片（新拟态凸起） ===== */
.lumira-card {
  background-color: var(--color-canvas);
  border-radius: 28rpx;
  padding: 40rpx;
  border: none;
  box-shadow: var(--shadow-convex);
  transition: box-shadow 0.3s ease, background-color 0.3s ease;
}

.lumira-card-hover {
  transition: transform 0.2s, box-shadow 0.2s;
}

.lumira-card-hover:active {
  transform: scale(0.98);
  box-shadow: var(--shadow-pressed);
}

.lumira-card-svg-bg {
  position: relative;
  overflow: hidden;
}

.lumira-card-svg-bg::before {
  content: '';
  position: absolute;
  top: -40rpx;
  right: -40rpx;
  width: 240rpx;
  height: 240rpx;
  background: radial-gradient(circle at center, rgba(201, 169, 110, 0.15) 0%, transparent 70%);
  background-repeat: no-repeat;
  pointer-events: none;
}

/* ===== 标签 ===== */
.lumira-tag {
  display: inline-flex;
  align-items: center;
  gap: 6rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  font-size: 22rpx;
  font-weight: 500;
  letter-spacing: 0.04em;
  line-height: 1.4;
}

.lumira-tag-gold {
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
}

.lumira-tag-red {
  background-color: var(--color-danger-subtle);
  color: var(--color-danger);
}

.lumira-tag-green {
  background-color: var(--color-success-subtle);
  color: var(--color-success);
}

/* ===== 进度条 ===== */
.lumira-progress {
  width: 100%;
  height: 12rpx;
  border-radius: 6rpx;
  background-color: var(--color-divider);
  overflow: hidden;
}

.lumira-progress-fill {
  height: 100%;
  background: var(--color-brand);
  border-radius: 6rpx;
}

/* ===== 区块标题 ===== */
.lumira-section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32rpx;
}

.lumira-section-link {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  background: none;
  border: none;
  display: flex;
  align-items: center;
  gap: 4rpx;
  line-height: 1;
}

/* ===== 统计数字 ===== */
.lumira-stat-num {
  font-family: var(--font-cn-title);
  font-size: 56rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1;
}

.lumira-stat-label {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}

/* ===== 徽章 ===== */
.lumira-badge {
  display: inline-flex;
  align-items: center;
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  font-size: 22rpx;
  font-weight: 600;
  letter-spacing: 0.04em;
  line-height: 1.4;
}

.lumira-badge-brand {
  background: var(--color-brand);
  color: var(--color-text-inverse);
}

/* ===== 新拟态全局类 ===== */
.neu-card {
  background-color: var(--color-canvas);
  border-radius: 20rpx;
  box-shadow: var(--shadow-convex);
}

.neu-inset {
  background-color: var(--color-canvas);
  border-radius: 20rpx;
  box-shadow: var(--shadow-concave);
}

.neu-pill {
  background-color: var(--color-canvas);
  border-radius: 9999rpx;
  box-shadow: var(--shadow-convex-subtle);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-pill:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

.neu-pill.active {
  box-shadow: var(--shadow-pressed);
  color: var(--color-brand-deep);
}

.neu-block {
  background-color: var(--color-canvas);
  border-radius: 12rpx;
  box-shadow: var(--shadow-convex-subtle);
}

.neu-block-inset {
  background-color: var(--color-canvas);
  border-radius: 12rpx;
  box-shadow: var(--shadow-concave-subtle);
}

.neu-btn-convex {
  background-color: var(--color-canvas);
  border: none;
  border-radius: 9999rpx;
  box-shadow: var(--shadow-convex);
  color: var(--color-brand);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-btn-convex:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

.neu-btn-brand {
  background-color: var(--color-brand);
  border: none;
  border-radius: 16rpx;
  box-shadow: var(--shadow-convex-brand);
  color: var(--color-text-inverse);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-btn-brand:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

/* 新拟态开关 */
.neu-toggle {
  width: 96rpx;
  height: 52rpx;
  border-radius: 9999rpx;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex-subtle);
  position: relative;
  transition: box-shadow 0.2s ease;
  flex-shrink: 0;
}

.neu-toggle-knob {
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex-subtle);
  position: absolute;
  top: 6rpx;
  left: 6rpx;
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease, background-color 0.2s ease;
}

.neu-toggle.active {
  box-shadow: var(--shadow-concave);
}

.neu-toggle.active .neu-toggle-knob {
  transform: translateX(44rpx);
  background-color: var(--color-brand);
  box-shadow: var(--shadow-convex-brand);
}

/* ===== 动画 ===== */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(24rpx); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.fade-up { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) both; }
.fade-up-d1 { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) 80ms both; }
.fade-up-d2 { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) 160ms both; }
.fade-up-d3 { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) 240ms both; }
.fade-up-d4 { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) 320ms both; }
.fade-up-d5 { animation: fadeUp 0.55s cubic-bezier(0.16,1,0.3,1) 400ms both; }
.fade-in { animation: fadeIn 0.4s ease both; }
.scale-in { animation: scaleIn 0.35s cubic-bezier(0.16,1,0.3,1) both; }

/* ===== 风格定向覆盖规则 ===== */

/* 所有页面卡片类的统一切换选择器 */
/* 涵盖全局工具类 + 页面自定义卡片类 */
/* eslint-disable-next-line no-useless-concat */

/* ===== 玻璃拟态：半透明 + backdrop-filter ===== */
[data-style="glass"] .neu-card,
[data-style="glass"] .lumira-card,
[data-style="glass"] .floating-tabbar,
[data-style="glass"] .scene-card,
[data-style="glass"] .recent-card,
[data-style="glass"] .tpl-card,
[data-style="glass"] .col-card,
[data-style="glass"] .new-card,
[data-style="glass"] .tip-card,
[data-style="glass"] .work-card,
[data-style="glass"] .preview-card,
[data-style="glass"] .option-card,
[data-style="glass"] .mood-card,
[data-style="glass"] .section-card,
[data-style="glass"] .selected-card,
[data-style="glass"] .summary-card,
[data-style="glass"] .stats-card,
[data-style="glass"] .fragment-card,
[data-style="glass"] .menu-card,
[data-style="glass"] .level-card,
[data-style="glass"] .achievement-card,
[data-style="glass"] .trajectory-card,
[data-style="glass"] .calendar-card,
[data-style="glass"] .collection-card,
[data-style="glass"] .main-card,
[data-style="glass"] .sub-card,
[data-style="glass"] .streak-card,
[data-style="glass"] .practice-card,
[data-style="glass"] .recommend-card,
[data-style="glass"] .setting-group,
[data-style="glass"] .tips-card,
[data-style="glass"] .add-card,
[data-style="glass"] .upload-card,
[data-style="glass"] .style-card,
[data-style="glass"] .theme-card,
[data-style="glass"] .sys-card,
[data-style="glass"] .hero-card {
  background-color: rgba(255, 255, 255, var(--surface-alpha)) !important;
  backdrop-filter: blur(20px) !important;
  -webkit-backdrop-filter: blur(20px) !important;
  border: 1rpx solid rgba(255, 255, 255, 0.3) !important;
}

/* 玻璃拟态：页面背景添加渐变装饰，让模糊效果可见 */
[data-style="glass"] .lumira-container {
  background-color: var(--color-canvas);
  background-image:
    radial-gradient(circle at 15% 20%, var(--color-brand-subtle) 0%, transparent 40%),
    radial-gradient(circle at 85% 60%, var(--color-brand-light) 0%, transparent 35%),
    radial-gradient(circle at 50% 90%, var(--color-brand-subtle) 0%, transparent 30%);
  background-attachment: fixed;
}

/* 玻璃拟态：导航栏滚动后毛玻璃 */
[data-style="glass"] .lumira-nav.scrolled {
  background-color: rgba(255, 255, 255, 0.6) !important;
  backdrop-filter: blur(24px) saturate(1.8) !important;
  -webkit-backdrop-filter: blur(24px) saturate(1.8) !important;
  border-bottom: 1rpx solid rgba(255, 255, 255, 0.2) !important;
}

/* 女性美学：导航栏滚动后毛玻璃 */
[data-style="female"] .lumira-nav.scrolled {
  background-color: rgba(255, 255, 255, 0.75) !important;
  backdrop-filter: blur(24px) saturate(1.8) !important;
  -webkit-backdrop-filter: blur(24px) saturate(1.8) !important;
  border-bottom: 1rpx solid rgba(var(--color-brand-rgb), 0.15) !important;
}

/* ===== 女性美学：半透明 + 暖粉弥散阴影 + 大圆角 ===== */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .floating-tabbar,
[data-style="female"] .scene-card,
[data-style="female"] .recent-card,
[data-style="female"] .tpl-card,
[data-style="female"] .col-card,
[data-style="female"] .new-card,
[data-style="female"] .tip-card,
[data-style="female"] .work-card,
[data-style="female"] .preview-card,
[data-style="female"] .option-card,
[data-style="female"] .mood-card,
[data-style="female"] .section-card,
[data-style="female"] .selected-card,
[data-style="female"] .summary-card,
[data-style="female"] .stats-card,
[data-style="female"] .fragment-card,
[data-style="female"] .menu-card,
[data-style="female"] .level-card,
[data-style="female"] .achievement-card,
[data-style="female"] .trajectory-card,
[data-style="female"] .calendar-card,
[data-style="female"] .collection-card,
[data-style="female"] .main-card,
[data-style="female"] .sub-card,
[data-style="female"] .streak-card,
[data-style="female"] .practice-card,
[data-style="female"] .recommend-card,
[data-style="female"] .setting-group,
[data-style="female"] .tips-card,
[data-style="female"] .add-card,
[data-style="female"] .upload-card,
[data-style="female"] .style-card,
[data-style="female"] .theme-card,
[data-style="female"] .sys-card,
[data-style="female"] .hero-card {
  background-color: rgba(255, 255, 255, var(--surface-alpha)) !important;
  backdrop-filter: blur(20px) !important;
  -webkit-backdrop-filter: blur(20px) !important;
  box-shadow: 0 8px 32px rgba(var(--color-brand-rgb), 0.15) !important;
  border: none !important;
}

/* 女性美学：大圆角 */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .scene-card,
[data-style="female"] .recent-card,
[data-style="female"] .tpl-card,
[data-style="female"] .col-card,
[data-style="female"] .new-card,
[data-style="female"] .tip-card,
[data-style="female"] .work-card,
[data-style="female"] .preview-card,
[data-style="female"] .option-card,
[data-style="female"] .mood-card,
[data-style="female"] .section-card,
[data-style="female"] .selected-card,
[data-style="female"] .summary-card,
[data-style="female"] .stats-card,
[data-style="female"] .fragment-card,
[data-style="female"] .menu-card,
[data-style="female"] .level-card,
[data-style="female"] .achievement-card,
[data-style="female"] .trajectory-card,
[data-style="female"] .calendar-card,
[data-style="female"] .collection-card,
[data-style="female"] .main-card,
[data-style="female"] .sub-card,
[data-style="female"] .streak-card,
[data-style="female"] .practice-card,
[data-style="female"] .recommend-card,
[data-style="female"] .setting-group,
[data-style="female"] .tips-card,
[data-style="female"] .add-card,
[data-style="female"] .upload-card,
[data-style="female"] .style-card,
[data-style="female"] .theme-card,
[data-style="female"] .sys-card,
[data-style="female"] .hero-card {
  border-radius: var(--card-radius) !important;
}

/* 女性美学：页面背景添加柔和渐变装饰 */
[data-style="female"] .lumira-container {
  background-color: var(--color-canvas);
  background-image:
    radial-gradient(circle at 20% 10%, rgba(var(--color-brand-rgb), 0.08) 0%, transparent 50%),
    radial-gradient(circle at 80% 80%, rgba(var(--color-brand-rgb), 0.06) 0%, transparent 45%);
  background-attachment: fixed;
}

/* 女性美学：所有卡片和按钮过渡使用 cubic-bezier */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .scene-card,
[data-style="female"] .recent-card,
[data-style="female"] .tpl-card,
[data-style="female"] .tip-card,
[data-style="female"] .work-card,
[data-style="female"] .neu-btn-convex,
[data-style="female"] .neu-btn-brand,
[data-style="female"] .lumira-btn-brand,
[data-style="female"] .neu-pill,
[data-style="female"] .style-card,
[data-style="female"] .theme-card,
[data-style="female"] .menu-card,
[data-style="female"] .setting-item {
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

/* 女性美学：按压反馈 scale(0.96) */
[data-style="female"] .neu-card:active,
[data-style="female"] .lumira-card:active,
[data-style="female"] .scene-card:active,
[data-style="female"] .recent-card:active,
[data-style="female"] .tpl-card:active,
[data-style="female"] .tip-card:active,
[data-style="female"] .work-card:active,
[data-style="female"] .neu-btn-convex:active,
[data-style="female"] .neu-btn-brand:active,
[data-style="female"] .lumira-btn-brand:active,
[data-style="female"] .style-card:active,
[data-style="female"] .theme-card:active {
  transform: scale(0.96);
}

/* 女性美学：呼吸光晕动画 */
@keyframes female-pulse {
  0%, 100% {
    box-shadow: 0 0 0 0 rgba(var(--color-brand-rgb), 0.4);
  }
  50% {
    box-shadow: 0 0 0 8rpx rgba(var(--color-brand-rgb), 0);
  }
}

[data-style="female"] .tabbar-item.active,
[data-style="female"] .tabbar-center {
  animation: female-pulse 2s ease-in-out infinite;
}

/* 女性美学：品牌按钮使用暖粉弥散阴影 */
[data-style="female"] .neu-btn-brand,
[data-style="female"] .lumira-btn-brand {
  box-shadow: 0 8px 24px rgba(var(--color-brand-rgb), 0.25);
}

[data-style="female"] .neu-btn-brand:active,
[data-style="female"] .lumira-btn-brand:active {
  box-shadow: 0 4px 12px rgba(var(--color-brand-rgb), 0.2);
}

/* ===== 扁平化：卡片边框 + 圆角 ===== */
[data-style="flat"] .neu-card,
[data-style="flat"] .lumira-card,
[data-style="flat"] .scene-card,
[data-style="flat"] .recent-card,
[data-style="flat"] .tpl-card,
[data-style="flat"] .col-card,
[data-style="flat"] .new-card,
[data-style="flat"] .tip-card,
[data-style="flat"] .work-card,
[data-style="flat"] .preview-card,
[data-style="flat"] .option-card,
[data-style="flat"] .mood-card,
[data-style="flat"] .section-card,
[data-style="flat"] .selected-card,
[data-style="flat"] .summary-card,
[data-style="flat"] .stats-card,
[data-style="flat"] .fragment-card,
[data-style="flat"] .menu-card,
[data-style="flat"] .level-card,
[data-style="flat"] .achievement-card,
[data-style="flat"] .trajectory-card,
[data-style="flat"] .calendar-card,
[data-style="flat"] .collection-card,
[data-style="flat"] .main-card,
[data-style="flat"] .sub-card,
[data-style="flat"] .streak-card,
[data-style="flat"] .practice-card,
[data-style="flat"] .recommend-card,
[data-style="flat"] .setting-group,
[data-style="flat"] .tips-card,
[data-style="flat"] .add-card,
[data-style="flat"] .upload-card,
[data-style="flat"] .style-card,
[data-style="flat"] .theme-card,
[data-style="flat"] .sys-card {
  border: var(--card-border) !important;
  border-radius: var(--card-radius) !important;
}

/* 扁平化：toggle 色块填充 */
[data-style="flat"] .neu-toggle {
  box-shadow: none;
  background-color: var(--color-divider);
}

[data-style="flat"] .neu-toggle.active {
  background-color: var(--color-brand);
  box-shadow: none;
}

[data-style="flat"] .neu-toggle-knob {
  box-shadow: none;
  background-color: #FFFFFF;
}

[data-style="flat"] .neu-toggle.active .neu-toggle-knob {
  background-color: #FFFFFF;
  box-shadow: none;
}

/* 扁平化：去除所有阴影 */
[data-style="flat"] .neu-block,
[data-style="flat"] .neu-pill,
[data-style="flat"] .neu-btn-convex,
[data-style="flat"] .scene-card,
[data-style="flat"] .recent-card,
[data-style="flat"] .tpl-card,
[data-style="flat"] .tip-card,
[data-style="flat"] .work-card {
  box-shadow: none !important;
}

[data-style="flat"] .neu-block-inset,
[data-style="flat"] .neu-inset {
  box-shadow: none;
  background-color: var(--color-surface-alt);
}

/* ===== 深色主题 + 玻璃/女性美学适配 ===== */
[data-theme="ink"][data-style="glass"] .neu-card,
[data-theme="ink"][data-style="glass"] .lumira-card,
[data-theme="ink"][data-style="glass"] .floating-tabbar,
[data-theme="ink"][data-style="glass"] .scene-card,
[data-theme="ink"][data-style="glass"] .recent-card,
[data-theme="ink"][data-style="glass"] .tpl-card,
[data-theme="ink"][data-style="glass"] .tip-card,
[data-theme="ink"][data-style="glass"] .work-card,
[data-theme="ink"][data-style="glass"] .hero-card,
[data-theme="ink"][data-style="glass"] .stats-card,
[data-theme="ink"][data-style="glass"] .menu-card {
  background-color: rgba(38, 35, 32, 0.55) !important;
  border-color: rgba(255, 255, 255, 0.1) !important;
}

/* 深色主题导航栏滚动后毛玻璃 */
[data-theme="ink"][data-style="glass"] .lumira-nav.scrolled {
  background-color: rgba(28, 26, 23, 0.6) !important;
  border-color: rgba(255, 255, 255, 0.08) !important;
}

[data-theme="ink"][data-style="female"] .lumira-nav.scrolled {
  background-color: rgba(28, 26, 23, 0.75) !important;
  border-color: rgba(255, 255, 255, 0.08) !important;
}

[data-theme="ink"][data-style="female"] .neu-card,
[data-theme="ink"][data-style="female"] .lumira-card,
[data-theme="ink"][data-style="female"] .floating-tabbar,
[data-theme="ink"][data-style="female"] .scene-card,
[data-theme="ink"][data-style="female"] .recent-card,
[data-theme="ink"][data-style="female"] .tpl-card,
[data-theme="ink"][data-style="female"] .tip-card,
[data-theme="ink"][data-style="female"] .work-card,
[data-theme="ink"][data-style="female"] .hero-card,
[data-theme="ink"][data-style="female"] .stats-card,
[data-theme="ink"][data-style="female"] .menu-card {
  background-color: rgba(38, 35, 32, 0.75) !important;
}
</style>
