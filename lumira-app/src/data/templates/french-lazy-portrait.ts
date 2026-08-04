import type { PhotoTemplate } from '@/types/template'

// 模板：法式慵懒高雅 — 白床单窗光下慵懒倚靠，颗粒质感复古高雅
const frenchLazyPortrait: PhotoTemplate = {
  meta: {
    id: 'french_lazy_portrait',
    name: '法式慵懒高雅',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'french_lazy', method: 'half_body' },
    tags: ['人像', '法式', '慵懒', '颗粒', '高雅'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-french-lazy-portrait/400/600',
    description: '白床单窗光下的法式慵懒，颗粒质感复古高雅，卧室里的慵懒时光',
    referenceSource: '设计规范 v1.0 模板 6；参考小红书法式慵懒风格教程 / 复古颗粒'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.25, y: 0.2, w: 0.5, h: 0.6 },
    opacity: 0.25,
    aspectRatio: '4:5',
    description: '三分线左侧构图，半身取景，倚靠侧坐'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'french-lazy-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.78,
    rotation: 0,
    description: '侧身倚靠侧坐，头部微仰看侧方，一手撑床一手自然放置，侧坐屈膝，慵懒无表情'
  },
  camera: {
    exposureCompensation: 0,
    iso: 200,
    shutterSpeed: '1/100',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '侧光（窗光）',
    lightDirectionAngle: 90,
    shootingDistance: '1.5-2m',
    background: '白床单 / 白墙 / 木地板 / 窗帘',
    props: ['书', '咖啡杯', '干花'],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '利用窗光侧光营造明暗',
      '白床单 / 白墙做背景保持干净',
      '颗粒是法式质感核心'
    ]
  },
  postProcess: {
    cropRatio: '4:5',
    color: {
      brightness: -5,
      contrast: 5,
      saturation: -5,
      temperature: 10,
      tint: 0,
      highlights: 0,
      shadows: 5,
      clarity: 0,
      vibrance: 0
    },
    smoothStrength: 12,
    sharpen: 12,
    vignette: 10,
    grain: 22,
    lut: 'vintage'
  }
}

export default frenchLazyPortrait
