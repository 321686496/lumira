import type { PhotoTemplate } from '@/types/template'

const nightCityscape: PhotoTemplate = {
  meta: {
    id: 'night_cityscape',
    name: '夜景城市',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    tags: ['夜景', '城市', '长曝光', '风光'],
    price: 0,
    cover: 'https://picsum.photos/seed/night-cityscape/600/800',
    description: '城市夜景长曝光拍摄，捕捉灯光车轨与建筑天际线',
    referenceSource: '样片 EXIF: 城市夜景摄影集；参数参考 500px 城市夜景精选作品'
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.2, y: 0.3, w: 0.6, h: 0.5 },
    opacity: 0.5,
    aspectRatio: '16:9',
    description: '地平线位于下三分之一线，建筑主体位于三分线交点，天空留白展示云层'
  },
  pose: {
    silhouette: { type: 'builtin', data: 'none' },
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯风光场景'
  },
  camera: {
    exposureCompensation: -0.5,
    isoMode: 'manual',
    iso: 800,
    shutterSpeed: '1/15',
    whiteBalance: 'tungsten',
    whiteBalanceK: 3200,
    flashMode: 'off',
    focusMode: 'manual',
    filterPreset: 'none',
    lensSuggestion: 'ultra_wide'
  },
  sceneGuide: {
    lightDirection: '混合光源（城市灯光 + 残余天空光）',
    shootingDistance: '远景（城市天际线 500m+）',
    background: '城市天际线、桥梁、车流道路',
    props: ['三脚架（必备）', '手机夹具', '快门线或语音快门'],
    bestTime: '日落后 30-60 分钟（蓝调时刻，天空未全黑）',
    tips: [
      '必须使用三脚架稳定拍摄，避免抖动',
      '对焦锁定到建筑或远景灯光',
      '车流长曝光可拍出光轨效果',
      '降低 EV 保留高光细节，避免灯光过曝'
    ]
  },
  postProcess: {
    cropRatio: '16:9',
    color: { brightness: 5, contrast: 20, saturation: 15, temperature: -10, tint: 5 },
    smoothStrength: 0,
    sharpen: 25,
    vignette: 20,
    grain: 15,
    lut: 'cinematic'
  }
}

export default nightCityscape
