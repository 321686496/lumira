import type { PhotoTemplate } from '@/types/template'

const urbanArchitecture: PhotoTemplate = {
  meta: {
    id: 'urban_architecture',
    name: '城市建筑',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    tags: ['建筑', '城市', '风光', '几何线条'],
    price: 3,
    cover: 'https://picsum.photos/seed/urban-architecture/600/800',
    description: '城市建筑摄影，利用几何线条与透视关系呈现现代建筑之美',
    referenceSource: '样片 EXIF: ArchDaily 建筑摄影作品；参数参考建筑摄影作品集'
  },
  composition: {
    overlayType: 'diagonal',
    subjectFrame: { x: 0.2, y: 0.2, w: 0.6, h: 0.6 },
    opacity: 0.4,
    aspectRatio: '4:5',
    description: '利用建筑斜线引导视线，主体置于对角线区域，强化透视纵深感'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'none' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯建筑构图，可使用三脚架稳定拍摄'
  },
  camera: {
    exposureCompensation: -0.3,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensSuggestion: 'ultra_wide'
  },
  sceneGuide: {
    lightDirection: '侧光 45°（突出建筑立面立体感）',
    shootingDistance: '10-30m',
    background: '天空与建筑主体，避免杂乱前景干扰',
    props: ['三脚架', '偏振镜（消除玻璃反光）'],
    bestTime: '上午 08:00-10:00 或下午 15:00-17:00（侧光最佳）',
    tips: [
      '使用超广角镜头强化建筑透视张力',
      '后期进行透视校正保持线条垂直',
      '寻找几何线条与对称构图增强形式感',
      '利用偏振镜消除玻璃幕墙反光',
      '降低 EV 保留天空云层细节'
    ]
  },
  postProcess: {
    cropRatio: '4:5',
    color: { brightness: 0, contrast: 35, saturation: 10, temperature: -5, tint: 0 },
    smoothStrength: 0,
    sharpen: 25,
    vignette: 15,
    grain: 5,
    lut: 'cinematic'
  }
}

export default urbanArchitecture
