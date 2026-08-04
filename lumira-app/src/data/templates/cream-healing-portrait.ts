import type { PhotoTemplate } from '@/types/template'

// 模板：奶油治愈风 — 奶油橙暖调温柔治愈，海边夕阳小镰仓滤镜
const creamHealingPortrait: PhotoTemplate = {
  meta: {
    id: 'cream_healing_portrait',
    name: '奶油治愈风',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'cream_healing', method: 'half_body' },
    tags: ['人像', '奶油', '治愈', '暖调', '夕阳'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-cream-healing-portrait/400/600',
    description: '奶油橙暖调温柔治愈，夕阳海边氛围感，拯救废片的小镰仓风',
    referenceSource: '设计规范 v1.0 模板 4；参考小红书小镰仓滤镜教程'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.65 },
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '居中偏右构图，半身取景，三分位右'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'cream-healing-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '正面坐姿，单手托腮，头部微倾，盘腿或屈膝坐，温柔微笑看镜头'
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
    lightDirection: '逆光 / 侧逆光（夕阳）',
    lightDirectionAngle: 150,
    shootingDistance: '1.5-2m',
    background: '海边 / 夕阳 / 沙滩 / 暖色墙面',
    props: [],
    bestTime: '下午 16:00-18:00',
    bestTimeFrom: '16:00',
    bestTimeTo: '18:00',
    tips: [
      '利用夕阳逆光营造暖调氛围',
      '让发丝透光产生金色轮廓光',
      '服装选择奶油色系'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 12,
      contrast: -8,
      saturation: 5,
      temperature: 12,
      tint: 0,
      highlights: -5,
      shadows: 12,
      clarity: -5,
      vibrance: 5
    },
    smoothStrength: 15,
    sharpen: 8,
    vignette: 5,
    grain: 5,
    lut: 'warm_film'
  }
}

export default creamHealingPortrait
