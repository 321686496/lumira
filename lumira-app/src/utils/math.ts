/**
 * 数学/几何计算工具
 */

/** 2D 点 */
export interface Point {
  x: number
  y: number
}

/** 矩形（归一化坐标 0~1） */
export interface Rect {
  x: number
  y: number
  w: number
  h: number
}

/**
 * 限制值在范围内
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

/**
 * 线性插值
 */
export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t
}

/**
 * 两点距离
 */
export function distance(a: Point, b: Point): number {
  const dx = b.x - a.x
  const dy = b.y - a.y
  return Math.sqrt(dx * dx + dy * dy)
}

/**
 * 点是否在矩形内
 */
export function isPointInRect(point: Point, rect: Rect): boolean {
  return (
    point.x >= rect.x &&
    point.x <= rect.x + rect.w &&
    point.y >= rect.y &&
    point.y <= rect.y + rect.h
  )
}

/**
 * 计算两个矩形的交面积
 */
export function rectIntersection(a: Rect, b: Rect): number {
  const x1 = Math.max(a.x, b.x)
  const y1 = Math.max(a.y, b.y)
  const x2 = Math.min(a.x + a.w, b.x + b.w)
  const y2 = Math.min(a.y + a.h, b.y + b.h)

  if (x2 <= x1 || y2 <= y1) return 0
  return (x2 - x1) * (y2 - y1)
}

/**
 * 计算矩形面积
 */
export function rectArea(rect: Rect): number {
  return rect.w * rect.h
}

/**
 * 计算 IoU (Intersection over Union)
 */
export function IoU(a: Rect, b: Rect): number {
  const intersection = rectIntersection(a, b)
  const union = rectArea(a) + rectArea(b) - intersection
  if (union === 0) return 0
  return intersection / union
}

/**
 * 角度转弧度
 */
export function degToRad(deg: number): number {
  return (deg * Math.PI) / 180
}

/**
 * 弧度转角度
 */
export function radToDeg(rad: number): number {
  return (rad * 180) / Math.PI
}

/**
 * 生成唯一 ID
 */
export function generateId(prefix = 'id'): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`
}
