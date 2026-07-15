import type { ScenePreset, ScenePresetId, Target } from '@/types/template'

export const SCENE_PRESETS: ScenePreset[] = [
  {
    id: 'cafe',
    name: '咖啡馆',
    icon: 'ph-coffee',
    description: '柔和自然光，温暖氛围',
    cameraSuggestion: {
      whiteBalance: 'cloudy',
      whiteBalanceK: 4800,
      photographicStyle: 'warm',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { temperature: 20, contrast: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
      shootingDistance: '1.5-2.5m',
      background: '咖啡馆室内环境，虚化的吧台、书架或暖色墙面',
      props: ['咖啡杯', '书本', '绿植盆栽'],
      bestTime: '下午 14:00-17:00',
      tips: [
        '让模特面朝窗户，利用柔光均匀照亮面部',
        '使用大光圈虚化背景突出人物',
        '避免顶光直射造成眼窝阴影'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 2,
      bestTimeFrom: '14:00',
      bestTimeTo: '17:00'
    },
    relatedCategory: 'portrait'
  },
  {
    id: 'street',
    name: '街拍',
    icon: 'ph-buildings',
    description: '城市光影，故事感构图',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'high_contrast',
      aperture: 4
    },
    postSuggestion: {
      lut: 'cinematic',
      color: { contrast: 15, clarity: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光/侧逆光（利用建筑遮挡形成光斑）',
      shootingDistance: '3-5m 环境人像',
      background: '街角、橱窗、斑马线、涂鸦墙等城市元素',
      props: ['咖啡杯', '墨镜', '手提包'],
      bestTime: '黄金时刻 16:00-18:00 或清晨 07:00-09:00',
      tips: [
        '寻找街角光影对比，利用橱窗反光增加层次',
        '采用抓拍方式捕捉自然步态',
        '注意背景行人避免干扰主体'
      ],
      lightDirectionAngle: 135,
      shootingDistanceM: 4,
      bestTimeFrom: '16:00',
      bestTimeTo: '18:00'
    },
    relatedCategory: 'street'
  },
  {
    id: 'beach',
    name: '海边',
    icon: 'ph-waves',
    description: '广阔天际线，清新明亮',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'standard',
      aperture: 8
    },
    postSuggestion: {
      lut: 'cool_film',
      color: { brightness: 5, vibrance: 10 }
    },
    sceneGuide: {
      lightDirection: '顺光或侧光（避免正午顶光）',
      shootingDistance: '2-5m 半身至全身',
      background: '海平面、沙滩、礁石、天空',
      props: ['草帽', '丝巾', '沙滩裙'],
      bestTime: '黄金时刻 06:00-08:00 或 17:00-19:00',
      tips: [
        '利用海风让头发飘动增加动感',
        '低角度拍摄拉长身形，融入海平面',
        '注意镜头防沙防水'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 3,
      bestTimeFrom: '17:00',
      bestTimeTo: '19:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'macro',
    name: '微距',
    icon: 'ph-flower',
    description: '细节之美，浅景深虚化',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      focusMode: 'manual',
      aperture: 8
    },
    postSuggestion: {
      lut: 'pastel',
      color: { clarity: 15 },
      sharpen: 20
    },
    sceneGuide: {
      lightDirection: '柔光（避免直射造成硬阴影）',
      shootingDistance: '10-30cm 微距范围',
      background: '纯色虚化背景或同色系环境',
      props: ['花朵', '水滴', '昆虫'],
      bestTime: '上午 09:00-11:00 柔光时段',
      tips: [
        '使用手动对焦精准控制焦点',
        '保持稳定，建议使用三脚架',
        '收小光圈保证足够景深'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 0.2,
      bestTimeFrom: '09:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'macro'
  },
  {
    id: 'night',
    name: '夜景',
    icon: 'ph-moon',
    description: '霓虹光影，赛博氛围',
    cameraSuggestion: {
      nightMode: true,
      iso: 800,
      shutterSpeed: '1/30',
      aperture: 1.8,
      whiteBalance: 'daylight',
      whiteBalanceK: 5500
    },
    postSuggestion: {
      lut: 'cyberpunk',
      color: { contrast: 20 },
      vignette: 20
    },
    sceneGuide: {
      lightDirection: '利用环境光源（霓虹灯、路灯、橱窗灯）',
      shootingDistance: '2-4m 人像',
      background: '霓虹招牌、车流光轨、城市天际线',
      props: ['透明雨伞', '反光镜面', '发光道具'],
      bestTime: '夜晚 19:00-23:00',
      tips: [
        '开启夜景模式提升暗部细节',
        '寻找霓虹灯作为轮廓光或发丝光',
        '注意快门速度避免手抖'
      ],
      lightDirectionAngle: 180,
      shootingDistanceM: 3,
      bestTimeFrom: '19:00',
      bestTimeTo: '23:00'
    },
    relatedCategory: 'night'
  },
  {
    id: 'food',
    name: '美食',
    icon: 'ph-fork-knife',
    description: '诱人色泽，俯拍构图',
    cameraSuggestion: {
      whiteBalance: 'tungsten',
      whiteBalanceK: 3200,
      photographicStyle: 'warm',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { saturation: 15 },
      sharpen: 10
    },
    sceneGuide: {
      lightDirection: '侧光或逆光（突出食物质感）',
      shootingDistance: '30-50cm 俯拍或 45 度',
      background: '木质桌面、大理石、纯色餐布',
      props: ['餐具', '餐巾', '装饰花草'],
      bestTime: '白天自然光 11:00-14:00',
      tips: [
        '注意白平衡让美食色彩还原自然',
        '俯拍展示全貌，45 度展示层次',
        '加入手部动作增加生活感'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 0.4,
      bestTimeFrom: '11:00',
      bestTimeTo: '14:00'
    },
    relatedCategory: 'food'
  },
  {
    id: 'home',
    name: '居家',
    icon: 'ph-house',
    description: '温馨日常，生活质感',
    cameraSuggestion: {
      whiteBalance: 'tungsten',
      whiteBalanceK: 3200,
      photographicStyle: 'warm',
      aperture: 2.0
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { temperature: 15 }
    },
    sceneGuide: {
      lightDirection: '窗边柔光或室内暖灯',
      shootingDistance: '1-3m 生活场景',
      background: '沙发、床铺、书架、绿植角落',
      props: ['抱枕', '毛毯', '马克杯', '书本'],
      bestTime: '上午 09:00-11:00 或下午 15:00-17:00',
      tips: [
        '保持画面简洁，突出居家温馨氛围',
        '利用窗光营造柔和明暗过渡',
        '大光圈虚化背景杂物'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 2,
      bestTimeFrom: '09:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'still-life'
  },
  {
    id: 'sunset',
    name: '黄昏',
    icon: 'ph-sunset',
    description: '逆光剪影，暖调氛围',
    cameraSuggestion: {
      whiteBalance: 'shade',
      whiteBalanceK: 7500,
      photographicStyle: 'warm',
      aperture: 5.6
    },
    postSuggestion: {
      lut: 'twilight',
      color: { temperature: 30, saturation: 10 }
    },
    sceneGuide: {
      lightDirection: '逆光（太阳位于主体正后方）',
      shootingDistance: '3-8m 剪影或半身',
      background: '落日、晚霞、地平线、剪影前景',
      props: ['草帽', '气球', '雨伞'],
      bestTime: '黄昏 17:30-19:00（日落前后 30 分钟）',
      tips: [
        '对天空测光锁定，拍摄人物剪影',
        '利用前景增加画面纵深',
        '黄金时刻色温最暖，抓紧时间'
      ],
      lightDirectionAngle: 180,
      shootingDistanceM: 5,
      bestTimeFrom: '17:30',
      bestTimeTo: '19:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'forest',
    name: '森林',
    icon: 'ph-tree',
    description: '通透绿意，自然光影',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'standard',
      aperture: 5.6
    },
    postSuggestion: {
      lut: 'fuji',
      color: { vibrance: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光或顶光穿透树叶（丁达尔效应）',
      shootingDistance: '2-5m 人像或环境',
      background: '树林、蕨类、苔藓、林间小径',
      props: ['野餐垫', '篮子', '花束'],
      bestTime: '上午 08:00-11:00 光线通透',
      tips: [
        '寻找光线穿透树叶的光斑',
        '使用绿色浓郁的 LUT 增强氛围',
        '低角度仰拍突出树冠'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 3,
      bestTimeFrom: '08:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'indoor',
    name: '室内',
    icon: 'ph-building',
    description: '柔和均匀，干净构图',
    cameraSuggestion: {
      whiteBalance: 'fluorescent',
      whiteBalanceK: 4000,
      photographicStyle: 'standard',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'pastel',
      color: { brightness: 5 }
    },
    sceneGuide: {
      lightDirection: '均匀柔光（避免强反差）',
      shootingDistance: '1.5-3m 人像或静物',
      background: '白墙、纯色背景纸、简约家具',
      props: ['书本', '花瓶', '装饰画'],
      bestTime: '全天（室内光线稳定）',
      tips: [
        '使用大光圈虚化背景突出主体',
        '注意色温准确性，避免偏色',
        '利用墙面反射光补光'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 2,
      bestTimeFrom: '10:00',
      bestTimeTo: '16:00'
    },
    relatedCategory: 'still-life'
  }
]

export const SCENE_TO_CATEGORY: Record<ScenePresetId, Target> = {
  cafe: 'portrait',
  street: 'street',
  beach: 'landscape',
  macro: 'macro',
  night: 'night',
  food: 'food',
  home: 'still-life',
  sunset: 'landscape',
  forest: 'landscape',
  indoor: 'still-life'
}
