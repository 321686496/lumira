import type { PhotoTemplate } from '@/types/template'

// 模板：日系小清新 — 干净清透空气感，低对比微冷调樱花校园
const japaneseFreshPortrait: PhotoTemplate = {
  meta: {
    id: 'japanese_fresh_portrait',
    name: '日系小清新',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'japanese_fresh', method: 'seven_body' },
    tags: ['人像', '日系', '小清新', '空气感', '低对比'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-japanese-fresh-portrait/400/600',
    description: '干净清透的日系空气感，低对比微冷调，樱花校园的青春记忆',
    referenceSource: '设计规范 v1.0 模板 3；参考日系写真 / 小红书小清新教程'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.25, y: 0.1, w: 0.5, h: 0.8 },
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧构图，七分身取景，留白充足'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'japanese-fresh-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.7,
    rotation: 0,
    description: '侧身自然行走，侧脸看远方，双手自然摆动，迈步动态，微笑'
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
    lightDirection: '顺光 / 漫射光',
    lightDirectionAngle: 30,
    shootingDistance: '2-3m',
    background: '樱花树 / 校园 / 蓝天白云 / 草地',
    props: [],
    bestTime: '上午 7:00-10:00',
    bestTimeFrom: '07:00',
    bestTimeTo: '10:00',
    tips: [
      '选择阴天或晨光获得柔和光线',
      '留白要足，人物占比不超过 60%',
      '服装选择浅色系'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 12,
      contrast: -10,
      saturation: -5,
      temperature: -5,
      tint: 0,
      highlights: 5,
      shadows: 15,
      clarity: -8,
      vibrance: 5
    },
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel'
  }
}

export default japaneseFreshPortrait
