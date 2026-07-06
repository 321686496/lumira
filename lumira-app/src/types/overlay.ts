/**
 * 叠图层类型定义
 */

/** 叠图层数据 */
export interface OverlayLayer {
  composition?: CompositionOverlayData
  pose?: PoseOverlayData
  opacity: number
  visible: boolean
}

/** 构图叠图数据 */
export interface CompositionOverlayData {
  type: 'rule_of_thirds' | 'grid' | 'leading_lines' | 'custom'
  lines: OverlayLine[]
  subjectFrame?: { x: number; y: number; w: number; h: number }
  color: string
}

/** 姿势叠图数据 */
export interface PoseOverlayData {
  imageUrl: string
  position: { x: number; y: number }
  scale: number
  rotation: number
}

/** 叠图线段（归一化坐标 0~1） */
export interface OverlayLine {
  start: { x: number; y: number }
  end: { x: number; y: number }
  type: 'solid' | 'dashed'
}

/** 叠图设置 */
export interface OverlaySettings {
  showComposition: boolean
  showPose: boolean
  opacity: number
}
