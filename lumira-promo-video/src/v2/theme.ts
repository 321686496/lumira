// V2 主题：黑白插画风格，色值取自 App 默认主题 warmWhite
export const V = {
  paper: '#FAF7F2', // App canvas 暖白纸色
  paperDeep: '#F1EBE1', // 纸面阴影
  ink: '#1A1A1A', // App textPrimary 墨黑
  inkSoft: '#4A4640', // 次级墨色
  gray: '#8A8580', // 灰调
  gold: '#C9A96E', // App brand 金褐（唯一强调色）
  goldDeep: '#B8935A',
  red: '#B85450', // App danger（破格冲击色，仅钩子使用）
  white: '#FDFBF7', // App surface
} as const;

export const FONT2 =
  '"Microsoft YaHei", "PingFang SC", "Noto Sans SC", sans-serif';

/** 盖章式金色渐变文字 */
export const goldInk = {
  background: 'linear-gradient(120deg, #C9A96E 10%, #B8935A 55%, #D8BC85 90%)',
  WebkitBackgroundClip: 'text' as const,
  backgroundClip: 'text' as const,
  color: 'transparent' as const,
};
