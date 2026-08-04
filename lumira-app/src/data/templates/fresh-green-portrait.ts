import type { PhotoTemplate } from '@/types/template'

// 模板：清新淡雅绿 — 户外森系露营净白滤镜，空气感清新淡雅绿
const freshGreenPortrait: PhotoTemplate = {
  meta: {
    id: 'fresh_green_portrait',
    name: '清新淡雅绿',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'fresh_green', method: 'full_body' },
    tags: ['人像', '森系', '露营', '净白', '空气感'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-fresh-green-portrait/400/600',
    description: '户外森系净白空气感，清新淡雅绿调，草地森林的自然治愈',
    referenceSource: '设计规范 v1.0 模板 10；参考小红书净白滤镜教程 / 户外森系露营'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.25, y: 0.1, w: 0.5, h: 0.8 },
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线左侧构图，全身取景，留白充足'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'fresh-green-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.7,
    rotation: 0,
    description: '侧身草地坐姿，回眸看镜头，双手撑地后撑，屈膝坐地，自然微笑'
  },
  camera: {
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '漫射光（阴天 / 树荫）',
    lightDirectionAngle: 0,
    shootingDistance: '2-3m',
    background: '草地 / 森林 / 露营地 / 野餐垫',
    props: ['草帽', '野餐垫', '帐篷'],
    bestTime: '上午 8:00-10:00 或阴天',
    bestTimeFrom: '08:00',
    bestTimeTo: '10:00',
    tips: [
      '选择阴天或树荫漫射光',
      '服装浅色棉麻与自然融合',
      '留白要足，人景比例 4:6'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 12,
      contrast: -8,
      saturation: -8,
      temperature: -8,
      tint: 0,
      highlights: 5,
      shadows: 12,
      clarity: -5,
      vibrance: 0
    },
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel'
  }
}

export default freshGreenPortrait
