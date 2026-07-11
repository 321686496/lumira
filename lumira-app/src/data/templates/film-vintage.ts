import type { PhotoTemplate } from '@/types/template'

const filmVintage: PhotoTemplate = {
  meta: {
    id: 'film_vintage',
    name: '胶片复古人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    tags: ['胶片', '复古', '人像', '怀旧', '暖调'],
    price: 3,
    cover: 'https://picsum.photos/seed/film-vintage/600/800',
    description: '模拟胶片质感的复古人像，暖调褪色感营造怀旧氛围',
    referenceSource: '样片 EXIF: 500px 胶片人像作品；参数参考胶片摄影作品'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.33, y: 0.3, w: 0.34, h: 0.55 },
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '人物置于左侧三分线交点，右侧留白展示环境氛围'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'vintage-portrait' },
    position: { x: 0.4, y: 0.45 },
    scale: 1.0,
    rotation: 0,
    description: '复古半身人像姿态，身体微侧，神情悠远望向画外'
  },
  camera: {
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 400,
    shutterSpeed: '1/125',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '柔光黄金时刻（日落前低角度暖光）',
    shootingDistance: '2-3m',
    background: '复古背景：老墙、木门、藤蔓或怀旧室内场景',
    props: ['复古帽子', '胶片相机', '老式道具', '干花束'],
    bestTime: '黄金时刻 16:00-18:00 或阴天柔光环境',
    tips: [
      '略微过曝营造胶片的轻盈通透感',
      '使用暖色白平衡模拟胶片色温',
      '后期添加颗粒与褪色效果强化复古质感',
      '避免画面中出现现代元素破坏氛围'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: { brightness: 10, contrast: -10, saturation: -10, temperature: 20, tint: 5 },
    smoothStrength: 25,
    sharpen: 10,
    vignette: 20,
    grain: 40,
    lut: 'vintage'
  }
}

export default filmVintage
