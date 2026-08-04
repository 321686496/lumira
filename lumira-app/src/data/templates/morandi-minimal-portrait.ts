import type { PhotoTemplate } from '@/types/template'

// 模板：莫兰迪高级冷淡 — 低饱和莫兰迪纯色背景，知性简约高级感
const morandiMinimalPortrait: PhotoTemplate = {
  meta: {
    id: 'morandi_minimal_portrait',
    name: '莫兰迪高级冷淡',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'morandi_minimal', method: 'half_body' },
    tags: ['人像', '莫兰迪', '高级', '冷淡', '知性'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-morandi-minimal-portrait/400/600',
    description: '莫兰迪低饱和高级冷淡，纯色极简知性风，轻熟女的品质感',
    referenceSource: '设计规范 v1.0 模板 7；参考莫兰迪色系人像 / 轻熟女知性风'
  },
  composition: {
    overlayType: 'center',
    subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 },
    opacity: 0.2,
    aspectRatio: '4:5',
    description: '居中构图，半身取景，纯色背景极简'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'morandi-minimal-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.8,
    rotation: 0,
    description: '正面端坐，双手交叠放膝上，并拢侧坐，正视镜头，知性无表情'
  },
  camera: {
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '顺光 / 柔光',
    lightDirectionAngle: 30,
    shootingDistance: '1.5-2m',
    background: '纯色灰墙 / 莫兰迪色背景纸',
    props: [],
    bestTime: '全天（室内可控光）',
    tips: [
      '纯色背景保持极简',
      '服装选莫兰迪灰粉 / 灰绿 / 灰蓝',
      '光线柔和不产生硬阴影'
    ]
  },
  postProcess: {
    cropRatio: '4:5',
    color: {
      brightness: 0,
      contrast: 5,
      saturation: -20,
      temperature: -5,
      tint: 0,
      highlights: 0,
      shadows: 0,
      clarity: 5,
      vibrance: -10
    },
    smoothStrength: 12,
    sharpen: 10,
    vignette: 5,
    grain: 5,
    lut: 'none'
  }
}

export default morandiMinimalPortrait
