import type { PhotoTemplate } from '@/types/template'

// 模板：夜景霓虹人像 — 城市霓虹青紫冷暖对比，爱乐之城夜景人像
const neonCityPortrait: PhotoTemplate = {
  meta: {
    id: 'neon_city_portrait',
    name: '夜景霓虹人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'neon_city', method: 'half_body' },
    tags: ['人像', '夜景', '霓虹', '青紫', '爱乐之城'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-neon-city-portrait/400/600',
    description: '城市霓虹青紫冷暖对比，爱乐之城夜景人像，夜晚街头的赛博浪漫',
    referenceSource: '设计规范 v1.0 模板 9；参考小红书爱乐之城滤镜教程 / 城市夜景人像'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.6 },
    opacity: 0.25,
    aspectRatio: '9:16',
    description: '三分线左侧构图，半身取景，9:16 竖图'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'neon-city-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '正面站立单手叉腰，一腿前一腿后，开立站姿，正视镜头，酷无表情'
  },
  camera: {
    exposureCompensation: -0.3,
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '多向光（霓虹光源）',
    lightDirectionAngle: 0,
    shootingDistance: '1.5-2m',
    background: '霓虹招牌 / 城市夜景 / 车流光斑',
    props: [],
    bestTime: '夜晚 20:00-23:00',
    bestTimeFrom: '20:00',
    bestTimeTo: '23:00',
    tips: [
      '选择多色霓虹招牌背景',
      '冷暖对比是核心（青天 + 品红霓虹）',
      '人物着深色突出霓虹色彩'
    ]
  },
  postProcess: {
    cropRatio: '9:16',
    color: {
      brightness: -8,
      contrast: 12,
      saturation: 8,
      temperature: -12,
      tint: 10,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: 5
    },
    smoothStrength: 12,
    sharpen: 12,
    vignette: 18,
    grain: 12,
    lut: 'cool_film'
  }
}

export default neonCityPortrait
