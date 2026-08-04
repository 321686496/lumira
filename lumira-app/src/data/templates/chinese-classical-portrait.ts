import type { PhotoTemplate } from '@/types/template'

// 模板：新中式古风 — 莫兰迪冷调东方意境，侧逆光园林古风
const chineseClassicalPortrait: PhotoTemplate = {
  meta: {
    id: 'chinese_classical_portrait',
    name: '新中式古风',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'chinese_classical', method: 'full_body' },
    tags: ['人像', '古风', '新中式', '汉服', '莫兰迪'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-chinese-classical-portrait/400/600',
    description: '莫兰迪冷调东方意境，侧逆光园林古风，国潮新中式美学',
    referenceSource: '设计规范 v1.0 模板 5；参考小红书古风人像教程 / 莫兰迪冷色调'
  },
  composition: {
    overlayType: 'golden_ratio',
    subjectFrame: { x: 0.35, y: 0.1, w: 0.35, h: 0.8 },
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '黄金分割点构图，全身取景，对称留白'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'chinese-classical-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.65,
    rotation: 0,
    description: '侧身站立执扇半遮面，回眸看镜头，并拢微立，汉服袖摆垂落，含蓄浅笑'
  },
  camera: {
    exposureCompensation: -0.3,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '侧逆光',
    lightDirectionAngle: 135,
    shootingDistance: '2-3m',
    background: '园林 / 竹林 / 古建 / 白墙黛瓦',
    props: ['团扇', '折扇', '油纸伞'],
    bestTime: '上午 8:00-10:00 或下午 15:00-17:00',
    bestTimeFrom: '08:00',
    bestTimeTo: '10:00',
    tips: [
      '侧逆光勾勒人物轮廓',
      '选择莫兰迪冷调背景（灰墙 / 竹林）',
      '服装选低饱和汉服'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: -5,
      contrast: 5,
      saturation: -15,
      temperature: -10,
      tint: 0,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: -5
    },
    smoothStrength: 12,
    sharpen: 10,
    vignette: 15,
    grain: 8,
    lut: 'cinematic'
  }
}

export default chineseClassicalPortrait
