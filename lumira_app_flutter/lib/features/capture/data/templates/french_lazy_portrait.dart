// lib/features/capture/data/templates/french_lazy_portrait.dart
import '../../domain/photo_template.dart';

/// 法式慵懒高雅模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 6
const PhotoTemplate frenchLazyPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'french_lazy_portrait',
    name: '法式慵懒半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'retro_nostalgia', style: 'french_lazy', subStyle: 'french_lazy', method: 'half_body'),
    tags: ['人像', '法式', '慵懒', '颗粒', '窗光'],
    tagIds: [],
    price: 40,
    images: [

      TemplateImage(url: 'assets/images/templates/french_lazy_portrait.png'),

    ],
    description: '白床单窗光下的法式慵懒，颗粒质感复古高雅，卧室里的慵懒时光。',
    referenceSource: '小红书法式慵懒风格教程；复古颗粒质感；法式写真套图',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.2, w: 0.5, h: 0.6),
    opacity: 0.25,
    aspectRatio: '4:5',
    description: '三分线左侧半身取景，倚靠侧坐构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/french_lazy_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.78,
          rotation: 0,
          description: '侧身倚靠侧坐，头部微仰看侧方，一手撑床/桌面，一手自然放置，慵懒无表情',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/french_lazy_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.78,
          rotation: 0,
          description: '侧身倚靠墙边或行走回眸，一手自然垂放，慵懒随性，不刻意',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/french_lazy_portrait.png'),
          position: Position(x: 0.45, y: 0.5),
          scale: 0.78,
          rotation: 0,
          description: '侧面坐姿或站立，头部微侧看向侧方，慵懒优雅，视线淡然',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/french_lazy_portrait.png'),
          position: Position(x: 0.5, y: 0.4),
          scale: 0.6,
          rotation: 0,
          description: '俯拍侧倚姿态，一手托腮或搭在咖啡杯边，慵懒松弛看向镜头',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 200,
    shutterSpeed: '1/100',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光（窗光）',
    lightDirectionAngle: 90,
    shootingDistance: '1.5-2m',
    background: '白床单/白墙/木地板/窗帘',
    props: ['书', '咖啡杯', '干花'],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '利用窗光侧光营造明暗',
      '白床单/白墙做背景保持干净',
      '颗粒是法式质感核心',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(
      brightness: -5,
      contrast: 5,
      saturation: -5,
      temperature: 10,
      tint: 0,
      highlights: 0,
      shadows: 5,
      clarity: 0,
      vibrance: 0,
    ),
    smoothStrength: 12,
    sharpen: 12,
    vignette: 10,
    grain: 22,
    lut: 'vintage',
  ),
);
