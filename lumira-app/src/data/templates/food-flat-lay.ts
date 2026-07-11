import type { PhotoTemplate } from '@/types/template'

const foodFlatLay: PhotoTemplate = {
  meta: {
    id: 'food_flat_lay',
    name: '美食俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    tags: ['美食', '俯拍', 'flat-lay', '静物'],
    price: 0,
    cover: '/static/templates/food_flat_lay.jpg',
    description: '90 度俯拍美食 flat-lay，突出摆盘与桌面构成',
    referenceSource: '样片 EXIF: 食物摄影教程；参数参考 YouTube 频道 The Bite Shot'
  },
  composition: {
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: { x: 0.25, y: 0.25, w: 0.5, h: 0.5 },
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '主菜置于画面中心或三分线交点，餐具沿对角线摆放'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'food-overhead' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，仅示意手部可辅助摆放餐具'
  },
  camera: {
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '侧光 45°（窗户自然光最佳）',
    shootingDistance: '0.5-1m（俯拍正上方）',
    background: '哑光桌面 / 木板 / 亚麻布',
    props: ['餐具', '餐巾', '新鲜食材', '小道具（花朵、杂志）'],
    bestTime: '白天（自然光充足的窗边）',
    tips: [
      '手机与桌面保持平行，避免透视畸变',
      '使用 2× 镜头减少广角变形',
      '主菜与配菜形成色彩对比',
      '留白区域放小道具增加层次'
    ]
  },
  postProcess: {
    cropRatio: '1:1',
    color: { brightness: 10, contrast: 15, saturation: 20, temperature: 10, tint: 0 },
    smoothStrength: 0,
    sharpen: 30,
    vignette: 0,
    grain: 0,
    lut: 'none'
  }
}

export default foodFlatLay
