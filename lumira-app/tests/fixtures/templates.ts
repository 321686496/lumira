/**
 * 测试 fixture — 完整的 .pptpl 模板 JSON
 */
export const VALID_TEMPLATE_JSON = JSON.stringify({
  meta: {
    id: 'tmpl_test_001',
    name: '日落逆光剪影',
    author: 'device_test',
    version: '1.0.0',
    category: '人像',
    tags: ['逆光', '剪影', '日落'],
    price: 0,
    description: '适合黄昏海边/山顶的逆光人像剪影',
  },
  composition: {
    overlayType: 'rule_of_thirds',
    subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
    opacity: 0.5,
  },
  pose: {
    referenceImage: 'mock://pose.png',
    position: { x: 0.5, y: 0.5 },
    scale: 1.0,
    rotation: 0,
  },
  camera: {
    exposureCompensation: -0.7,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    focusMode: 'auto',
    filterPreset: 'warm',
    lensSuggestion: 'main',
  },
  sceneGuide: {
    lightDirection: 'backlight',
    shootingDistance: '3-5m',
    background: '天空/水面',
    props: ['宽檐帽'],
    tips: '让模特侧身',
  },
  postProcess: {
    cropRatio: '3:4',
    color: {
      brightness: 0.1,
      contrast: 0.15,
      saturation: -0.1,
      temperature: 0.2,
      tint: 0.0,
    },
    smoothStrength: 0.3,
    sharpen: 0.2,
    vignette: 0.3,
    grain: 0.1,
    lut: 'warm_sunset.cube',
  },
})

export const TEMPLATE_MISSING_META = JSON.stringify({
  composition: { overlayType: 'grid', opacity: 0.5 },
  camera: { iso: 100 },
  postProcess: { sharpen: 0.1 },
})

export const TEMPLATE_MISSING_ID = JSON.stringify({
  meta: { name: '无ID模板', version: '1.0.0' },
  composition: { overlayType: 'grid', opacity: 0.5 },
  camera: { iso: 100 },
  postProcess: { sharpen: 0.1 },
})

export const TEMPLATE_OLD_VERSION = JSON.stringify({
  meta: {
    id: 'tmpl_old_001',
    name: '旧版本模板',
    version: '0.9.0',
  },
  composition: { overlayType: 'grid', opacity: 0.5 },
  camera: { iso: 100 },
  postProcess: { sharpen: 0.1 },
})

export const TEMPLATE_FUTURE_VERSION = JSON.stringify({
  meta: {
    id: 'tmpl_future_001',
    name: '未来版本模板',
    version: '2.0.0',
  },
  composition: { overlayType: 'grid', opacity: 0.5 },
  camera: { iso: 100 },
  postProcess: { sharpen: 0.1 },
})

export const INVALID_JSON = '{ "meta": { "id": "broken", '

export const TEMPLATE_NO_POSTPROCESS = JSON.stringify({
  meta: { id: 'tmpl_nopost', name: '无后期', version: '1.0.0' },
  composition: { overlayType: 'grid', opacity: 0.5 },
  camera: { iso: 100 },
})
