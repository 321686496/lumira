import type { PhotoTemplate } from '@/types/template'

// 模板：探店美食人像 — 美食+人物对角线暖调，下午茶探店的诱人时光
const foodiePortrait: PhotoTemplate = {
  meta: {
    id: 'foodie_portrait',
    name: '探店美食人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'foodie_portrait', method: 'half_body' },
    tags: ['人像', '探店', '美食', '对角线', '暖调'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-foodie-portrait/400/600',
    description: '美食+人物对角线暖调，下午茶探店的诱人时光',
    referenceSource: '设计规范 v1.0 模板 15；参考小红书探店下午茶拍照 / Foodie 滤镜'
  },
  composition: {
    overlayType: 'diagonal',
    subjectFrame: { x: 0.2, y: 0.2, w: 0.6, h: 0.6 },
    opacity: 0.25,
    aspectRatio: '1:1',
    description: '对角线构图，人物与美食呈对角，1:1 方图'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'foodie-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '侧身坐姿，一手举杯一手托腮，低头看桌面食物，微笑'
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
    lightDirection: '顺光 / 侧光（室内灯）',
    lightDirectionAngle: 45,
    shootingDistance: '0.8-1.2m',
    background: '咖啡馆桌面 / 餐厅 / 美食',
    props: ['咖啡杯', '蛋糕', '餐具'],
    bestTime: '全天（室内）',
    tips: [
      '美食与人物呈对角线构图',
      '俯拍 45 度角',
      '暖调让食物更诱人'
    ]
  },
  postProcess: {
    cropRatio: '1:1',
    color: {
      brightness: 10,
      contrast: -5,
      saturation: 10,
      temperature: 10,
      tint: 0,
      highlights: 0,
      shadows: 8,
      clarity: 0,
      vibrance: 5
    },
    smoothStrength: 12,
    sharpen: 10,
    vignette: 5,
    grain: 0,
    lut: 'warm_film'
  }
}

export default foodiePortrait
