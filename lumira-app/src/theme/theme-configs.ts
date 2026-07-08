/**
 * 主题配置表
 * 定义 4 套内置主题的元数据与布局参数
 */

/** 主题 ID */
export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

/** 主题布局参数 */
export interface ThemeLayout {
  /** 首页区块顺序 */
  homeSectionOrder: string[]
  /** 模板库网格列数 */
  templateGridColumns: number
  /** 相册网格列数 */
  galleryGridColumns: number
  /** 卡片宽高比 */
  cardAspectRatio: string
  /** TabBar 样式 */
  tabBarStyle: 'floating' | 'compact' | 'minimal'
}

/** 主题元数据 */
export interface ThemeMeta {
  /** 主题 ID */
  id: ThemeId
  /** 主题名称（中文） */
  label: string
  /** 主题描述（中文） */
  description: string
  /** 图标风格 */
  iconStyle: 'line' | 'fill' | 'handdrawn'
  /** 组件变体标识 */
  componentVariant: 'default' | 'default-dark' | 'retro' | 'fresh'
  /** 布局参数 */
  layout: ThemeLayout
}

/** 全部主题 ID 列表 */
export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh']

/** 主题配置表 */
export const THEME_METAS: Record<ThemeId, ThemeMeta> = {
  warm: {
    id: 'warm',
    label: '暖米白',
    description: '温暖留白，编辑式质感',
    iconStyle: 'line',
    componentVariant: 'default',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'recent', 'featured', 'scene', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 3,
      cardAspectRatio: '3 / 4',
      tabBarStyle: 'floating',
    },
  },
  ink: {
    id: 'ink',
    label: '浓墨',
    description: '深色沉浸，夜拍伴侣',
    iconStyle: 'line',
    componentVariant: 'default-dark',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'recent', 'featured', 'scene', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 3,
      cardAspectRatio: '3 / 4',
      tabBarStyle: 'floating',
    },
  },
  retro: {
    id: 'retro',
    label: '胶片复古',
    description: '暖橘深棕，胶片方格',
    iconStyle: 'handdrawn',
    componentVariant: 'retro',
    layout: {
      homeSectionOrder: ['brand', 'scene', 'featured', 'inspiration', 'recent', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 2,
      cardAspectRatio: '1 / 1',
      tabBarStyle: 'compact',
    },
  },
  fresh: {
    id: 'fresh',
    label: '日系清新',
    description: '淡粉米白，杂志呼吸',
    iconStyle: 'line',
    componentVariant: 'fresh',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'featured', 'scene', 'recent', 'stats'],
      templateGridColumns: 1,
      galleryGridColumns: 2,
      cardAspectRatio: '4 / 5',
      tabBarStyle: 'minimal',
    },
  },
}
