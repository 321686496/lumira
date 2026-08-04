import type { PhotoTemplate } from '@/types/template'

// 模板：港风夜景人像 — 王家卫式霓虹夜景，暖黄低对比街头浪漫
const hkNoirPortrait: PhotoTemplate = {
  meta: {
    id: 'hk_noir_portrait',
    name: '港风夜景人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'hk_noir', method: 'half_body' },
    tags: ['人像', '港风', '夜景', '霓虹', '王家卫'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-hk-noir-portrait/400/600',
    description: '王家卫式港风夜景，霓虹暖黄低对比，街头浪漫故事感',
    referenceSource: '设计规范 v1.0 模板 2；参考小红书港风夜景教程 / 王家卫电影色调'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '居中偏左构图，半身取景，倚墙回眸'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'hk-noir-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '侧身倚墙回眸，一手插袋一手自然垂下，交叉倚墙，沉思微怅'
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
    lightDirection: '侧光 / 逆光（霓虹光源）',
    lightDirectionAngle: 120,
    shootingDistance: '1.5-2m',
    background: '霓虹招牌 / 老街夜景 / 路灯',
    props: [],
    bestTime: '夜晚 19:00-22:00',
    bestTimeFrom: '19:00',
    bestTimeTo: '22:00',
    tips: [
      '利用霓虹灯做侧光光源',
      '让模特倚靠墙面增加故事感',
      '选择暖色霓虹招牌做背景虚化'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: -5,
      contrast: 8,
      saturation: 5,
      temperature: 15,
      tint: 5,
      highlights: -15,
      shadows: 5,
      clarity: 0,
      vibrance: 0
    },
    smoothStrength: 12,
    sharpen: 10,
    vignette: 20,
    grain: 15,
    lut: 'warm_film'
  }
}

export default hkNoirPortrait
