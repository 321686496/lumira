import type { PhotoTemplate } from '@/types/template'

/**
 * 可调参数路径列表
 * 任何一项与模板原值不一致，applied 即变为 false
 */
const ADJUSTABLE_PARAM_PATHS = [
  // 相机 Tab
  'camera.exposureCompensation',
  'camera.iso',
  'camera.shutterSpeed',
  'camera.whiteBalance',
  'camera.whiteBalanceK',
  'camera.flashMode',
  'camera.focusMode',
  'camera.lensType',
  'camera.photographicStyle',
  'camera.hdr',
  // 构图 Tab
  'composition.overlayType',
  'composition.gridType',
  'composition.aspectRatio',
  'composition.subjectFrame',
  'composition.opacity',
  // 姿势 Tab
  'pose.silhouette.type',
  'pose.positionX',
  'pose.positionY',
  'pose.scale',
  'pose.rotation',
  // 后期 Tab
  'postProcess.systemFilter',
  'postProcess.lut',
  'postProcess.cropRatio',
  'postProcess.color.brightness',
  'postProcess.color.contrast',
  'postProcess.color.saturation',
  'postProcess.color.temperature',
  'postProcess.color.tint',
  'postProcess.smoothStrength',
  'postProcess.sharpen',
  'postProcess.vignette',
  'postProcess.grain'
] as const

/**
 * 按路径获取对象深层属性值
 * 支持 'a.b.c' 形式
 */
function getPath(obj: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>((acc, key) => {
    if (acc === null || acc === undefined) return undefined
    return (acc as Record<string, unknown>)[key]
  }, obj)
}

/**
 * 判定当前可编辑模板的参数是否与原模板一致
 * 所有可调参数都参与比较，任一不一致返回 false
 */
export function isParametersMatchingTemplate(
  current: PhotoTemplate,
  original: PhotoTemplate
): boolean {
  for (const path of ADJUSTABLE_PARAM_PATHS) {
    const curVal = getPath(current, path)
    const origVal = getPath(original, path)
    // 处理 undefined 与默认值兼容（如 positionX/positionY 可能在旧模板中不存在）
    if (curVal === undefined && origVal === undefined) continue
    if (curVal !== origVal) return false
  }
  return true
}
