import type { PhotoTemplate } from '@/types/template'

// 模板：温柔日暮紫 — 夕阳克莱因蓝梦幻紫，HSL 蓝饱和提升的日暮浪漫
const purpleDuskPortrait: PhotoTemplate = {
  meta: {
    id: 'purple_dusk_portrait',
    name: '温柔日暮紫',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'purple_dusk', method: 'half_body' },
    tags: ['人像', '日暮', '紫色', '梦幻', '夕阳'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-purple-dusk-portrait/400/600',
    description: '夕阳克莱因蓝梦幻紫，HSL 蓝饱和提升的日暮浪漫',
    referenceSource: '设计规范 v1.0 模板 14；参考小红书克莱因蓝滤镜教程 / 夕阳紫色梦幻'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.65 },
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线右侧构图，半身取景，侧脸望夕阳'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'purple-dusk-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '侧身站立，侧脸仰头望夕阳，一手轻拂发丝，并拢站立，裙摆轻动，陶醉微笑'
  },
  camera: {
    exposureCompensation: -0.3,
    iso: 200,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '侧逆光（夕阳）',
    lightDirectionAngle: 150,
    shootingDistance: '1.5-2m',
    background: '夕阳天空 / 紫色晚霞 / 海边',
    props: [],
    bestTime: '黄昏 17:30-19:00',
    bestTimeFrom: '17:30',
    bestTimeTo: '19:00',
    tips: [
      '选择紫色晚霞的黄昏',
      '侧逆光勾勒轮廓',
      'tint+15 是紫色关键'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: -5,
      contrast: 8,
      saturation: 5,
      temperature: 5,
      tint: 15,
      highlights: -10,
      shadows: 5,
      clarity: 0,
      vibrance: 5
    },
    smoothStrength: 10,
    sharpen: 8,
    vignette: 10,
    grain: 5,
    lut: 'cinematic'
  }
}

export default purpleDuskPortrait
