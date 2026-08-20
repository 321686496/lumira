// src/lib/profile-labels.ts
// 个人资料/问卷偏好的中文标签映射与渲染工具（个人中心同步 + 问卷），供后台复用。
// 避免在多处重复维护同一份 key -> 中文 映射。

export const genderLabels: Record<string, string> = {
  female: '女',
  male: '男',
  other: '其他',
};

export const sourceLabels: Record<string, string> = {
  app_store: '应用商店',
  social_media: '社交媒体',
  friend: '朋友推荐',
  search: '搜索引擎',
  article: '文章博客',
  other: '其他',
};

export const categoryLabels: Record<string, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

export const painTypeLabels: Record<string, string> = {
  composition: '构图困难',
  lighting: '光线处理',
  posing: '摆姿不自然',
  camera_settings: '参数设置',
  post_processing: '后期修图',
  no_subject: '找不到拍摄对象',
  no_time: '没时间拍',
};

export const skillLevelLabels: Record<string, string> = {
  beginner: '新手',
  intermediate: '进阶',
  advanced: '高级',
  pro: '专业',
};

export const expectationLabels: Record<string, string> = {
  learn_photo: '学摄影',
  inspiration: '找灵感',
  better_composition: '提升构图',
  master_camera: '玩转相机',
  share_works: '分享作品',
  record_life: '记录生活',
};

export const sceneLabels: Record<string, string> = {
  indoor_home: '家中',
  cafe: '咖啡馆',
  outdoor_park: '户外公园',
  street: '街头',
  travel: '旅行',
  office: '办公室',
  studio: '影棚',
};

export const frequencyLabels: Record<string, string> = {
  rarely: '偶尔',
  monthly: '每月',
  weekly: '每周',
  daily: '每天',
};

// 单值映射：field -> map
export const singleValueLabelMaps: Record<
  string,
  Record<string, string>
> = {
  gender: genderLabels,
  source: sourceLabels,
  skill_level: skillLevelLabels,
  shoot_frequency: frequencyLabels,
};

// 多值映射：field -> map
export const multiValueLabelMaps: Record<
  string,
  Record<string, string>
> = {
  favorite_categories: categoryLabels,
  pain_points: painTypeLabels,
  expectations: expectationLabels,
  common_scenes: sceneLabels,
};

/** label 化单个值：返回映射后的文本，未知 key 原样返回。 */
export function labelOf(field: string, value: string): string {
  const map = singleValueLabelMaps[field];
  return map?.[value] ? map[value] : value;
}