import type { PhotoTemplate } from '@/types/template'

// 模板：动漫温柔青 — 宫崎骏感饱和提亮梦境青，晴天草地张开双臂的动漫浪漫
const animeDreamPortrait: PhotoTemplate = {
  meta: {
    id: 'anime_dream_portrait',
    name: '动漫温柔青',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'anime_dream', method: 'full_body' },
    tags: ['人像', '动漫', '宫崎骏', '梦境', '温柔青'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-anime-dream-portrait/400/600',
    description: '宫崎骏感饱和提亮梦境青，晴天草地张开双臂的动漫浪漫',
    referenceSource: '设计规范 v1.0 模板 12；参考小红书梦境滤镜教程 / 宫崎骏动漫感'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.2, y: 0.1, w: 0.55, h: 0.8 },
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线左侧偏中构图，全身取景，天空留白'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'anime-dream-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.7,
    rotation: 0,
    description: '正面站立张开双臂，仰头看天，微张站立，裙摆飘动，开心大笑'
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
    lightDirection: '顺光 / 顶光',
    lightDirectionAngle: 30,
    shootingDistance: '2-3m',
    background: '蓝天白云 / 草地 / 花海',
    props: [],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '晴天蓝天才有效果',
      '仰拍带天空',
      '服装浅色与天空呼应'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 12,
      contrast: -5,
      saturation: 10,
      temperature: 5,
      tint: 0,
      highlights: -5,
      shadows: 15,
      clarity: -5,
      vibrance: 8
    },
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel'
  }
}

export default animeDreamPortrait
