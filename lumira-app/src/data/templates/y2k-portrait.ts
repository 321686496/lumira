import type { PhotoTemplate } from '@/types/template'

// 模板：Y2K 千禧风 — 千禧回潮高饱和闪光，飒爽酷 girl 攻击性非甜美
const y2kPortrait: PhotoTemplate = {
  meta: {
    id: 'y2k_portrait',
    name: 'Y2K 千禧风',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'y2k', method: 'half_body' },
    tags: ['人像', 'Y2K', '千禧', '高饱和', '闪光'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-y2k-portrait/400/600',
    description: '千禧回潮高饱和闪光，飒爽酷 girl 攻击性，Y2K 非甜美路线',
    referenceSource: '设计规范 v1.0 模板 11；参考小红书 Y2K 千禧风教程 / 酷 girl 非甜美'
  },
  composition: {
    overlayType: 'center',
    subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 },
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '居中构图，半身取景，闪光直打'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'y2k-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.8,
    rotation: 0,
    description: '正面双手叉腰站立，开立站姿，头部微仰，直视镜头，酷无表情'
  },
  camera: {
    exposureCompensation: 0,
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'on',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '正面闪光',
    lightDirectionAngle: 0,
    shootingDistance: '1-1.5m',
    background: '纯色墙 / 涂鸦墙 / 街头',
    props: ['墨镜', '链条', '发夹'],
    bestTime: '全天（闪光为主光）',
    tips: [
      '开启闪光灯直打',
      '服装亮色 + 金属配饰',
      '表情要酷不要甜'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 5,
      contrast: 12,
      saturation: 15,
      temperature: 5,
      tint: 0,
      highlights: -5,
      shadows: -5,
      clarity: 0,
      vibrance: 5
    },
    smoothStrength: 8,
    sharpen: 15,
    vignette: 5,
    grain: 5,
    lut: 'none'
  }
}

export default y2kPortrait
