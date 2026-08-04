/**
 * 内置模板注册表
 *
 * 汇总所有内置模板，提供按 id 查询能力。
 * 自定义模板由 useTemplate composable 通过本地存储管理，不在此处注册。
 */

import type { PhotoTemplate } from '@/types/template'

import sunsetSilhouette from './sunset-silhouette'
import cafePortrait from './cafe-portrait'
import streetBw from './street-bw'
import foodFlatLay from './food-flat-lay'
import nightCityscape from './night-cityscape'
import goldenLandscape from './golden-landscape'
import indoorStillLife from './indoor-still-life'
import softPortrait from './soft-portrait'
import neonPortrait from './neon-portrait'
import macroFlower from './macro-flower'
import filmVintage from './film-vintage'
import urbanArchitecture from './urban-architecture'

// 新增 17 个人像拍照模板（设计规范 v1.0）
import ccdRetroPortrait from './ccd-retro-portrait'
import hkNoirPortrait from './hk-noir-portrait'
import japaneseFreshPortrait from './japanese-fresh-portrait'
import creamHealingPortrait from './cream-healing-portrait'
import chineseClassicalPortrait from './chinese-classical-portrait'
import frenchLazyPortrait from './french-lazy-portrait'
import morandiMinimalPortrait from './morandi-minimal-portrait'
import darkIndoorPortrait from './dark-indoor-portrait'
import neonCityPortrait from './neon-city-portrait'
import freshGreenPortrait from './fresh-green-portrait'
import y2kPortrait from './y2k-portrait'
import animeDreamPortrait from './anime-dream-portrait'
import blueNightPortrait from './blue-night-portrait'
import purpleDuskPortrait from './purple-dusk-portrait'
import foodiePortrait from './foodie-portrait'
import sweetGirlPortrait from './sweet-girl-portrait'
import elegantLadyPortrait from './elegant-lady-portrait'

/** 所有内置模板（16 免费 + 13 付费） */
export const BUILTIN_TEMPLATES: PhotoTemplate[] = [
  // 免费 8 个
  sunsetSilhouette,
  cafePortrait,
  streetBw,
  foodFlatLay,
  nightCityscape,
  goldenLandscape,
  indoorStillLife,
  softPortrait,
  // 付费 4 个
  neonPortrait,
  macroFlower,
  filmVintage,
  urbanArchitecture,

  // ── 新增 17 个人像拍照模板（设计规范 v1.0，按优先级 P0→P3 排序，免费优先）──

  // P0 免费（3 个）
  ccdRetroPortrait,
  hkNoirPortrait,
  japaneseFreshPortrait,

  // P1 免费（2 个）
  creamHealingPortrait,
  chineseClassicalPortrait,

  // P1 付费（2 个）
  frenchLazyPortrait,
  morandiMinimalPortrait,

  // P2 免费（1 个）
  freshGreenPortrait,

  // P2 付费（4 个）
  darkIndoorPortrait,
  neonCityPortrait,
  y2kPortrait,
  animeDreamPortrait,

  // P3 免费（2 个）
  foodiePortrait,
  sweetGirlPortrait,

  // P3 付费（3 个）
  blueNightPortrait,
  purpleDuskPortrait,
  elegantLadyPortrait
]

/** 内置模板 id → 模板对象映射（用于快速查找） */
const BUILTIN_TEMPLATE_MAP: Record<string, PhotoTemplate> = BUILTIN_TEMPLATES.reduce(
  (map, tpl) => {
    map[tpl.meta.id] = tpl
    return map
  },
  {} as Record<string, PhotoTemplate>
)

/**
 * 按 id 查找内置模板
 * @param id 模板 id
 * @returns 模板对象，未找到返回 null
 */
export function getTemplateById(id: string): PhotoTemplate | null {
  return BUILTIN_TEMPLATE_MAP[id] || null
}

/** 获取所有免费内置模板 */
export function getFreeBuiltinTemplates(): PhotoTemplate[] {
  return BUILTIN_TEMPLATES.filter(t => t.meta.price === 0)
}

/** 获取所有付费内置模板 */
export function getPaidBuiltinTemplates(): PhotoTemplate[] {
  return BUILTIN_TEMPLATES.filter(t => t.meta.price > 0)
}
