import type { PhotoTemplate } from '@/types/template'

// 模板：CCD 胶片复古 — 90 年代 CCD 复古质感，暖黄颗粒自带柔光
const ccdRetroPortrait: PhotoTemplate = {
  meta: {
    id: 'ccd_retro_portrait',
    name: 'CCD 胶片复古',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: { type: 'portrait', style: 'ccd_retro', method: 'half_body' },
    tags: ['人像', 'CCD', '复古', '胶片', '暖黄'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-ccd-retro-portrait/400/600',
    description: '90 年代 CCD 复古质感，暖黄颗粒自带柔光，拍出老照片的温柔记忆',
    referenceSource: '设计规范 v1.0 模板 1；参考 vivo X200 Ultra CCD 模式 / ProCCD 教程'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.28, y: 0.15, w: 0.45, h: 0.7 },
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '三分线左侧构图，半身取景，头部位于上三分线'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'ccd-retro-portrait' },
    position: { x: 0.5, y: 0.5 },
    scale: 0.75,
    rotation: 0,
    description: '随性侧身回眸，一手自然下垂，一手轻触发梢，一前一后重心后移，微笑看镜头'
  },
  camera: {
    exposureCompensation: 0.3,
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensType: '1x'
  },
  sceneGuide: {
    lightDirection: '侧顺光 45°',
    lightDirectionAngle: 45,
    shootingDistance: '1.5-2m',
    background: '老街 / 室内暖光 / 复古墙面',
    props: [],
    bestTime: '下午 15:00-17:00',
    bestTimeFrom: '15:00',
    bestTimeTo: '17:00',
    tips: [
      '利用午后暖光营造复古氛围',
      '可轻微晃动模拟 CCD 对焦不准',
      '服装选择纯色或格纹'
    ]
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 8,
      contrast: -5,
      saturation: 5,
      temperature: 15,
      tint: 0,
      highlights: -10,
      shadows: 10,
      clarity: -5,
      vibrance: 5
    },
    smoothStrength: 15,
    sharpen: 8,
    vignette: 15,
    grain: 20,
    lut: 'vintage'
  }
}

export default ccdRetroPortrait
