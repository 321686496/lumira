// lumira-server/packages/backend/src/modules/ai/enums.ts
// AI 模块统一枚举表：枚举值数组 + 中文标签（Task 4 从 normalize.ts 迁出）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 枚举表从 admin/src/components/template-form.tsx 头部常量逐一拷贝（key + 中文标签），
// 与 Flutter 端 filter_recipe.dart 的 unifiedFilters 保持一致；
// normalize.ts（归一化）与后续 ai-analyze（prompt 构造）均从本文件导入。

// ===== AI 服务商（ai_provider_config.provider 合法值） =====

export const PROVIDERS = ['qwen', 'doubao', 'zhipu', 'openai'] as const;

// ===== 模板草稿枚举表（与 admin 表单常量一致） =====

/**
 * 统一滤镜库：25 项 = 24 个滤镜 + none（原图）。
 * 与 admin template-form.tsx 的 LUTS / LUT_LABELS、Flutter filter_recipe.dart 的
 * unifiedFilters / lutLabel 逐字一致（brief 中「LUT 24 项」指 24 个滤镜，不含 none 原图）。
 */
export const LUTS = [
  'none', 'cinematic', 'vintage', 'warm_film', 'cool_film', 'pastel', 'fuji',
  'portrait', 'japanese', 'japanese_fresh', 'cream', 'cyberpunk', 'night_cyber',
  'hk_neon', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan',
  'noir', 'fine_art_bw', 'silver', 'morandi', 'muted_gray', 'heavy_film',
] as const;

export const LUT_LABELS: Record<string, string> = {
  none: '原图',
  cinematic: '电影感',
  vintage: '复古胶片',
  warm_film: '暖色胶片',
  cool_film: '冷色胶片',
  pastel: '柔色',
  fuji: '富士感',
  portrait: '人像',
  japanese: '日系',
  japanese_fresh: '日系清新',
  cream: '奶油感',
  cyberpunk: '赛博朋克',
  night_cyber: '夜景赛博',
  hk_neon: '港风霓虹',
  sepia_classic: '褐调',
  mist: '薄雾',
  rouge: '胭脂',
  twilight: '暮光',
  cyan: '青调',
  noir: '黑白',
  fine_art_bw: '黑白艺术',
  silver: '银盐感',
  morandi: '莫兰迪',
  muted_gray: '低饱和高级灰',
  heavy_film: '浓厚胶片',
};

/** 构图叠加层类型 */
export const OVERLAY_TYPES = [
  'rule_of_thirds', 'golden_ratio', 'diagonal', 'grid', 'leading_lines', 'center', 'none',
] as const;

export const OVERLAY_TYPE_LABELS: Record<string, string> = {
  rule_of_thirds: '三等分',
  golden_ratio: '黄金比例',
  diagonal: '对角线',
  grid: '网格',
  leading_lines: '引导线',
  center: '居中',
  none: '无',
};

/** 构图比例 / 裁剪比例共用同一张表（admin 表单两个 Select 均渲染 ASPECT_RATIOS） */
export const ASPECT_RATIOS = ['fullscreen', '3:4', '4:3', '16:9', '1:1', '9:16'] as const;

export const ASPECT_RATIO_LABELS: Record<string, string> = {
  fullscreen: '全屏',
};

export const ISO_MODES = ['auto', 'manual'] as const;
export const ISO_MODE_LABELS: Record<string, string> = { auto: '自动', manual: '手动' };

export const WHITE_BALANCES = ['daylight', 'cloudy', 'shade', 'tungsten', 'fluorescent', 'custom'] as const;
export const WHITE_BALANCE_LABELS: Record<string, string> = {
  daylight: '日光',
  cloudy: '多云',
  shade: '阴影',
  tungsten: '白炽灯',
  fluorescent: '荧光灯',
  custom: '自定义',
};

export const FLASH_MODES = ['off', 'on', 'auto', 'torch'] as const;
export const FLASH_MODE_LABELS: Record<string, string> = { off: '关闭', on: '开启', auto: '自动', torch: '常亮' };

export const FOCUS_MODES = ['auto', 'manual', 'continuous'] as const;
export const FOCUS_MODE_LABELS: Record<string, string> = { auto: '自动', manual: '手动', continuous: '连续' };

export const LENS_SUGGESTIONS = ['wide', 'main', 'telephoto', 'ultra_wide'] as const;
export const LENS_SUGGESTION_LABELS: Record<string, string> = {
  wide: '广角',
  main: '主摄',
  telephoto: '长焦',
  ultra_wide: '超广角',
};

export const SEASONS = ['spring', 'summer', 'autumn', 'winter'] as const;
export const SEASON_LABELS: Record<string, string> = { spring: '春', summer: '夏', autumn: '秋', winter: '冬' };

export const WEATHERS = ['sunny', 'cloudy', 'overcast', 'rain', 'snow', 'fog'] as const;
export const WEATHER_LABELS: Record<string, string> = {
  sunny: '晴',
  cloudy: '多云',
  overcast: '阴',
  rain: '雨',
  snow: '雪',
  fog: '雾',
};

export const TIME_TONES = ['goldenHour', 'day', 'night', 'warm', 'cool'] as const;
export const TIME_TONE_LABELS: Record<string, string> = {
  goldenHour: '黄金小时',
  day: '白天',
  night: '夜晚',
  warm: '暖调',
  cool: '冷调',
};
