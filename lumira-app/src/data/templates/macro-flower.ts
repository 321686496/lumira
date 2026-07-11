import type { PhotoTemplate } from '@/types/template'

const macroFlower: PhotoTemplate = {
  meta: {
    id: 'macro_flower',
    name: '微距花卉',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    tags: ['微距', '花卉', '特写', '自然'],
    price: 3,
    cover: '/static/templates/macro_flower.jpg',
    description: '微距镜头捕捉花卉细节，呈现花蕊纹理与娇嫩质感',
    referenceSource: '样片 EXIF: 500px 微距花卉作品；参数参考微距摄影教程'
  },
  composition: {
    overlayType: 'center',
    subjectFrame: { x: 0.3, y: 0.3, w: 0.4, h: 0.4 },
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '花蕊居于画面中心，四周留白突出主体细节，方构图强化稳定感'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'macro-flower' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '微距手持姿势参考，相机贴近花卉，稳定持握避免抖动'
  },
  camera: {
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    filterPreset: 'none',
    lensSuggestion: 'main'
  },
  sceneGuide: {
    lightDirection: '柔光散射光（阴天或柔光罩下的漫射光）',
    shootingDistance: '0.1-0.3m',
    background: '虚化的绿色 foliage 或深色背景，突出花卉主体',
    props: ['柔光罩', '反光板', '喷壶（制造水珠）'],
    bestTime: '清晨 06:00-08:00 或阴天（光线柔和均匀）',
    tips: [
      '使用手动对焦精准锁定花蕊细节',
      '提高快门速度避免微距抖动',
      '使用喷壶制造水珠增加生机感',
      '选择深色背景突出花卉主体',
      '避免直射强光造成高光溢出'
    ]
  },
  postProcess: {
    cropRatio: '1:1',
    color: { brightness: 5, contrast: 15, saturation: 15, temperature: 5, tint: 5 },
    smoothStrength: 0,
    sharpen: 40,
    vignette: 15,
    grain: 5,
    lut: 'fuji'
  }
}

export default macroFlower
