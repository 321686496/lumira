/**
 * 主题配置表
 * 定义 8 套颜色主题 + 4 种 UI 风格的元数据
 */

export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh' | 'cozy' | 'macaron' | 'morandi' | 'rosegold'

export type StyleId = 'neumorphism' | 'flat' | 'glass' | 'female'

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

export interface StyleMeta {
  id: StyleId
  label: string
  description: string
  icon: string
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
  },
  cozy: {
    id: 'cozy',
    label: '温馨粉',
    description: '柔粉温暖，温馨治愈的日常',
    icon: 'ph-heart',
    colors: {
      canvas: '#FFF5F5',
      brand: '#E8A0A0',
      surface: '#FFFFFF',
      textPrimary: '#4A3A3A',
      textSecondary: '#8C7070'
    }
  },
  macaron: {
    id: 'macaron',
    label: '马卡龙',
    description: '薄荷糖果，甜美活泼',
    icon: 'ph-ice-cream',
    colors: {
      canvas: '#FFF8F0',
      brand: '#A8D8C8',
      surface: '#FFFFFF',
      textPrimary: '#5A4A4A',
      textSecondary: '#8C7A7A'
    }
  },
  morandi: {
    id: 'morandi',
    label: '莫兰迪',
    description: '灰调优雅，安静内敛',
    icon: 'ph-mountains',
    colors: {
      canvas: '#E8E4E0',
      brand: '#8B9DAF',
      surface: '#F2EFEA',
      textPrimary: '#4A4540',
      textSecondary: '#7A7570'
    }
  },
  rosegold: {
    id: 'rosegold',
    label: '玫瑰金',
    description: '轻奢优雅，玫瑰金质感',
    icon: 'ph-diamond',
    colors: {
      canvas: '#FAF6F2',
      brand: '#C9A0A0',
      surface: '#FFFFFF',
      textPrimary: '#3D2E2A',
      textSecondary: '#6B5450'
    }
  }
}

export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh', 'cozy', 'macaron', 'morandi', 'rosegold']

export const STYLE_METAS: Record<StyleId, StyleMeta> = {
  neumorphism: {
    id: 'neumorphism',
    label: '新拟态',
    description: '双向阴影，柔和立体',
    icon: 'ph-circle-half'
  },
  flat: {
    id: 'flat',
    label: '扁平化',
    description: '干净利落，无多余修饰',
    icon: 'ph-square'
  },
  glass: {
    id: 'glass',
    label: '玻璃拟态',
    description: '半透明毛玻璃，通透感',
    icon: 'ph-square-logo'
  },
  female: {
    id: 'female',
    label: '女性美学',
    description: '暖粉弥散，大圆角，呼吸感',
    icon: 'ph-heart'
  }
}

export const STYLE_IDS: StyleId[] = ['neumorphism', 'flat', 'glass', 'female']
