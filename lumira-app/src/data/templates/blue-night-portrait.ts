import type { PhotoTemplate } from '@/types/template'

// 模板：复古暗夜蓝 — 黄昏逆光暗夜蓝冷峻浪漫，天空大海的背影剪影诗
const blueNightPortrait: PhotoTemplate = {
  meta: {
    id: 'blue_night_portrait',
    name: '复古暗夜蓝',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'blue_night', method: 'seven_body' },
    tags: ['人像', '暗夜蓝', '逆光', '剪影', '冷峻'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-blue-night-portrait/400/600',
    description: '黄昏逆光暗夜蓝冷峻浪漫，天空大海的背影剪影诗',
    referenceSource: '设计规范 v1.0 模板 13；参考小红书爱乐之城深色滤镜 / 逆光剪影'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.25, y: 0.15, w: 0.5, h: 0.75 },
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧构图，七分身取景，天空大海占主体'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'blue-night-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.65,
    rotation: 0,
    description: '背影站立望海，仰头望远方，双手自然下垂，并拢站立，长裙下摆'
  },
  camera: {
    exposureCompensation: -0.5,
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
    lightDirection: '逆光',
    lightDirectionAngle: 180,
    shootingDistance: '2-3m',
    background: '天空 / 大海 / 夕阳余晖 / 山顶',
    props: [],
    bestTime: '黄昏 17:00-19:00',
    bestTimeFrom: '17:00',
    bestTimeTo: '19:00',
    tips: [
      '黄昏逆光剪影感',
      '天空大海占画面 2/3',
      '人物深色突出轮廓'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: -8,
      contrast: 12,
      saturation: -5,
      temperature: -12,
      tint: 0,
      highlights: -15,
      shadows: -5,
      clarity: 0,
      vibrance: 0
    },
    smoothStrength: 8,
    sharpen: 10,
    vignette: 15,
    grain: 8,
    lut: 'cool_film'
  }
}

export default blueNightPortrait
