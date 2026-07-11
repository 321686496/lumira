import type { PhotoTemplate } from '@/types/template'

const indoorStillLife: PhotoTemplate = {
  meta: {
    id: 'indoor_still_life',
    name: '室内静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    tags: ['静物', '室内', '柔光', '生活美学'],
    price: 0,
    cover: 'https://picsum.photos/seed/indoor-still-life/600/800',
    description: '室内柔光环境下的静物台面拍摄，突出物体质感与生活气息',
    referenceSource: '样片 EXIF: Pexels 静物摄影作品；参数参考静物摄影教程'
  },
  composition: {
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: { x: 0.3, y: 0.3, w: 0.4, h: 0.4 },
    opacity: 0.4,
    aspectRatio: '4:5',
    description: '主体置于三分线交点，利用网格对齐台面物品，保持画面均衡'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'still-life-table' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '静物台面布局参考，物品高低错落，主物居中略偏一侧'
  },
  camera: {
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '侧光 45°（窗户自然光或柔光箱为主光源）',
    shootingDistance: '0.3-0.8m',
    background: '哑光背景纸或纯色墙面，避免反光与杂色干扰',
    props: ['陶瓷器皿', '亚麻布', '干花', '木质托盘'],
    bestTime: '上午 09:00-11:00（窗光均匀柔和）',
    tips: [
      '使用侧光突出物体表面纹理与质感',
      '避免使用闪光灯造成生硬阴影',
      '主物与辅物形成高低错落的层次',
      '可使用反光板或白卡纸补暗部细节',
      '保持背景简洁，避免杂物入镜'
    ]
  },
  postProcess: {
    cropRatio: '4:5',
    color: { brightness: 5, contrast: 10, saturation: 5, temperature: 5, tint: 0 },
    smoothStrength: 0,
    sharpen: 30,
    vignette: 10,
    grain: 5,
    lut: 'none'
  }
}

export default indoorStillLife
