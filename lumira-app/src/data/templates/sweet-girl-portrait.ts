import type { PhotoTemplate } from '@/types/template'

// 模板：甜妹元气少女 — 高亮暖粉比心托腮，九宫格甜美元气少女
const sweetGirlPortrait: PhotoTemplate = {
  meta: {
    id: 'sweet_girl_portrait',
    name: '甜妹元气少女',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'sweet_girl', method: 'half_body' },
    tags: ['人像', '甜妹', '元气', '少女', '粉色'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-sweet-girl-portrait/400/600',
    description: '高亮暖粉比心托腮，九宫格甜美元气少女，青春的粉色记忆',
    referenceSource: '设计规范 v1.0 模板 16；参考小红书甜妹拍照教程 / 元气少女风'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.15, w: 0.4, h: 0.7 },
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线右侧构图，半身取景，俏皮比心'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'sweet-girl-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.8,
    rotation: 0,
    description: '正面站立微倾，单手比心至脸侧，头部微歪，并拢微内八，俏皮大笑'
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
    lightDirection: '顺光',
    lightDirectionAngle: 30,
    shootingDistance: '1-1.5m',
    background: '纯色粉墙 / 游乐场 / 花墙',
    props: ['发夹', '泡泡', '气球'],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '顺光明亮均匀',
      '服装粉色亮色系',
      '表情要甜要活泼'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 12,
      contrast: -5,
      saturation: 8,
      temperature: 8,
      tint: 0,
      highlights: 5,
      shadows: 10,
      clarity: -5,
      vibrance: 5
    },
    smoothStrength: 15,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel'
  }
}

export default sweetGirlPortrait
