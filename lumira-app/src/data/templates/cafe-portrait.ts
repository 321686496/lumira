import type { PhotoTemplate } from '@/types/template'

const cafePortrait: PhotoTemplate = {
  meta: {
    id: 'cafe_portrait',
    name: '咖啡馆人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'japanese', method: 'normal' },
    tags: ['咖啡馆', '人像', '柔光', '生活'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-cafe-portrait/400/600',
    description: '咖啡馆室内自然光人像，氛围温暖柔和，适合生活感肖像',
    referenceSource: '样片 EXIF: Unsplash #67890；参数参考 Unsplash 咖啡馆人像摄影合集'
  },
  composition: {
    overlayType: 'center',
    subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '人物居中或略偏窗光一侧，保留桌面/咖啡杯作为前景元素增强故事感'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'sitting-cafe' },
    position: { x: 0.5, y: 0.45 },
    scale: 1.0,
    rotation: 0,
    description: '模特坐姿，身体微侧向窗光方向，手部自然搭于桌面或持咖啡杯'
  },
  camera: {
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/80',
    whiteBalance: 'cloudy',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
    shootingDistance: '1.5-2.5m',
    background: '咖啡馆室内环境，虚化的吧台、书架或暖色墙面',
    props: ['咖啡杯', '书本', '绿植盆栽'],
    bestTime: '下午 14:00-17:00（避开正午强光，窗光柔和）',
    tips: [
      '让模特面朝窗户，利用柔光均匀照亮面部',
      '使用大光圈虚化背景突出人物',
      '避免顶光直射造成眼窝阴影',
      '可利用白桌布或白卡纸作为反光板补光'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: { brightness: 5, contrast: 10, saturation: 10, temperature: 20, tint: -5 },
    smoothStrength: 20,
    sharpen: 15,
    vignette: 15,
    grain: 5,
    lut: 'warm_film'
  }
}

export default cafePortrait
