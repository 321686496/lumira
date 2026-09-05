// lib/features/capture/data/templates/anime_dream_portrait.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 动漫温柔青模板（anime_tender 子风格，归位 fresh_healing）
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 12
const PhotoTemplate animeDreamPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'anime_dream_portrait',
    name: '草地蓝天跳跃少女｜清新日系人像模板',
    author: 'Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'fresh_healing', style: 'anime_tender', subStyle: 'anime_tender', method: 'full_body'),
    tags: ['人像', '日系清新', '草坪', '蓝天', '跳跃抓拍', '少女感', '户外'],
    tagIds: [],
    price: 20,
    images: [
      TemplateImage(url: 'assets/images/templates/anime_dream_portrait.jpg'),
    ],
    description: '户外晴天草坪人像模板，低机位仰拍捕捉背对镜头跳跃瞬间，利用澄澈蓝天大留白，搭配浅色系洛丽塔风裙装，适合夏日晴天拍摄元气自由感的少女写真。',
    referenceSource: '小红书梦境滤镜教程；宫崎骏动漫感；晴天户外人像',
    shortDesc: '向着蓝天白云纵身跃起，满是自由元气的夏日氛围感☁️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer'],
      weathers: ['sunny'],
      timeTones: ['day'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.42, y: 0.32, w: 0.34, h: 0.56),
    opacity: 0.3,
    aspectRatio: '9:16',
    description: '竖版9:16构图，下方保留绿色草地，上方大面积留给蓝天白云，人物主体放在画面中间区域，天空做大量留白，强化开阔自由的感觉。',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/anime_dream_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 2.5,
          rotation: 0,
          description: '人物背对镜头，双脚腾空跳跃，屏幕左侧手臂竖直向上高举握拳，屏幕右侧手臂向身体侧后方张开握拳，双腿屈膝，一条腿向上抬，一条腿向下，呈现起跳腾空姿态。',
          cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0.2,
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5700,
    flashMode: 'off',
    focusMode: 'continuous',
    lensType: '1x',
    lensSuggestion: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '晴天白天自然光，光源屏幕右上方45°，软日光，低光比',
    lightDirectionAngle: 45,
    shootingDistance: '2.2-2.8m',
    background: '前景绿色起伏草坪，背景布满蓬松白云的湛蓝色天空，无多余杂物',
    props: ['装饰花草草帽'],
    bestTime: '14:00-16:00',
    bestTimeFrom: '14:00',
    bestTimeTo: '16:00',
    tips: [
      '拍摄者放低手机做低机位仰拍，镜头朝向斜上方',
      '让模特多尝试连续跳跃，抓拍腾空最高点瞬间',
      '尽量找干净无杂物的草坪，避开地面多余垃圾物体',
      '选择云朵丰富的晴天，蓝天氛围感更强',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(
      brightness: 4,
      contrast: -6,
      saturation: 8,
      temperature: -4,
      tint: 2,
      highlights: -12,
      shadows: 10,
      clarity: -5,
      vibrance: 12,
    ),
    smoothStrength: 25,
    sharpen: 12,
    vignette: 18,
    grain: 22,
    lut: 'japanese_fresh',
  ),
);
