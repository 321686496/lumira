/**
 * 主题配置表
 * 定义 4 套主题的元数据
 */

export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

export interface ThemeMeta {
  id: ThemeId
  label: string
  description: string
  icon: string
  colors: {
    canvas: string
    brand: string
    surface: string
    textPrimary: string
    textSecondary: string
  }
}

export const THEME_METAS: Record<ThemeId, ThemeMeta> = {
  warm: {
    id: 'warm',
    label: '暖米白',
    description: '温润如玉，东方留白的经典底色',
    icon: 'ph-sun',
    colors: {
      canvas: '#FAF7F2',
      brand: '#C9A96E',
      surface: '#FFFFFF',
      textPrimary: '#1A1A1A',
      textSecondary: '#5C5852'
    }
  },
  ink: {
    id: 'ink',
    label: '浓墨',
    description: '深邃墨色，暗夜中的专注拍摄',
    icon: 'ph-moon',
    colors: {
      canvas: '#1C1A17',
      brand: '#D4B57A',
      surface: '#262320',
      textPrimary: '#F2EEE6',
      textSecondary: '#A39D94'
    }
  },
  retro: {
    id: 'retro',
    label: '胶片复古',
    description: '温暖胶片质感，怀旧色彩调色',
    icon: 'ph-film-strip',
    colors: {
      canvas: '#F5E6D3',
      brand: '#C4956A',
      surface: '#FFF8F0',
      textPrimary: '#3D2817',
      textSecondary: '#6B4C2F'
    }
  },
  fresh: {
    id: 'fresh',
    label: '日系清新',
    description: '清新自然，柔和明亮的日常感',
    icon: 'ph-flower-tulip',
    colors: {
      canvas: '#F8FAF6',
      brand: '#8BAD72',
      surface: '#FFFFFF',
      textPrimary: '#4A3F35',
      textSecondary: '#8C7F70'
    }
  }
}

export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh']
