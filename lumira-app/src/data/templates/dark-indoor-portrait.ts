import type { PhotoTemplate } from '@/types/template'

// 模板：室内暗调氛围 — 咖啡馆暗调精致高级，锐化质感黑森林氛围
const darkIndoorPortrait: PhotoTemplate = {
  meta: {
    id: 'dark_indoor_portrait',
    name: '室内暗调氛围',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'dark_indoor', method: 'half_body' },
    tags: ['人像', '暗调', '咖啡馆', '质感', '高级'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-dark-indoor-portrait/400/600',
    description: '咖啡馆暗调精致高级，锐化质感黑森林氛围，探店氛围感首选',
    referenceSource: '设计规范 v1.0 模板 8；参考小红书黑森林滤镜教程 / 咖啡馆暗调'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.28, y: 0.18, w: 0.44, h: 0.65 },
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧构图，半身取景，倚桌托腮'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'dark-indoor-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.78,
    rotation: 0,
    description: '侧身倚桌坐姿，单手托腮撑桌，微低头看侧方，咖啡杯在桌面，沉思'
  },
  camera: {
    exposureCompensation: -0.3,
    iso: 400,
    shutterSpeed: '1/80',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '侧光（室内灯 / 窗光）',
    lightDirectionAngle: 90,
    shootingDistance: '1-1.5m',
    background: '咖啡馆 / 暗调室内 / 木质桌面',
    props: ['咖啡杯', '书', '餐具'],
    bestTime: '全天（室内）',
    tips: [
      '选择暗调咖啡馆靠窗位',
      '侧光营造明暗对比',
      '锐化突出质感细节'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: -10,
      contrast: 10,
      saturation: -5,
      temperature: 5,
      tint: 0,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: 0
    },
    smoothStrength: 12,
    sharpen: 20,
    vignette: 15,
    grain: 8,
    lut: 'cinematic'
  }
}

export default darkIndoorPortrait
