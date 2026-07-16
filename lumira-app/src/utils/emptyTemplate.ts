import type { PhotoTemplate } from '@/types/template'

/**
 * 创建空白模板（用于自由调参模式）
 * 所有参数为默认值，不产生任何滤镜效果
 */
export function createEmptyTemplate(): PhotoTemplate {
  return {
    meta: {
      id: '__empty__',
      name: '自由调参',
      author: '',
      version: '1.0.0',
      category: 'portrait',
      classification: { type: 'portrait', style: 'japanese', method: 'normal' },
      tags: [],
      tagIds: [],
      price: 0,
      cover: '',
      description: '自由调整相机与后期参数',
      referenceSource: ''
    },
    composition: {
      overlayType: 'none',
      gridType: 'thirds',
      subjectFrame: { x: 0.3, y: 0.3, w: 0.4, h: 0.4 },
      opacity: 1,
      aspectRatio: '3:4',
      description: ''
    },
    pose: {
      silhouette: { type: 'builtin', data: 'none' },
      position: { x: 0.5, y: 0.5 },
      positionX: 0,
      positionY: 0,
      scale: 1,
      rotation: 0,
      description: ''
    },
    camera: {
      exposureCompensation: 0,
      iso: 0,
      shutterSpeed: 'auto',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensType: '1x',
      photographicStyle: 'standard',
      hdr: false,
      // 新增字段默认值
      aperture: null,
      nightMode: false,
      nightExposureTime: 3,
      livePhoto: false,
      gridEnabled: false,
      aeAfLock: false,
      lensCorrection: false
    },
    sceneGuide: {
      lightDirection: '',
      shootingDistance: '',
      background: '',
      props: [],
      bestTime: '',
      tips: [],
      presetId: undefined,
      lightDirectionAngle: 0,
      shootingDistanceM: 2,
      bestTimeFrom: '09:00',
      bestTimeTo: '17:00'
    },
    postProcess: {
      cropRatio: '3:4',
      color: {
        brightness: 0,
        contrast: 0,
        saturation: 0,
        temperature: 0,
        tint: 0,
        highlights: 0,
        shadows: 0,
        blackPoint: 0,
        clarity: 0,
        vibrance: 0,
        brilliance: 0
      },
      smoothStrength: 0,
      sharpen: 0,
      vignette: 0,
      grain: 0,
      lut: 'none',
      systemFilter: 'none'
    }
  }
}
