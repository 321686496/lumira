// lib/features/capture/data/templates/chinese_classical_portrait.dart
import '../../domain/photo_template.dart';

/// 新中式古风模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 5
const PhotoTemplate chineseClassicalPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'chinese_classical_portrait',
    name: '中式古典全身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'retro_nostalgia', style: 'chinese_classical', subStyle: 'chinese_classical', method: 'full_body'),
    tags: ['人像', '古风', '新中式', '莫兰迪', '园林'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/chinese_classical_portrait.png',
    description: '莫兰迪冷调东方意境，侧逆光园林古风，国潮新中式美学。',
    referenceSource: '小红书古风人像教程；莫兰迪冷色调风格；汉服摄影套图',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.1, w: 0.35, h: 0.8),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '黄金分割点全身取景，侧逆光勾勒轮廓',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/chinese_classical_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.65,
    rotation: 0,
    description: '侧身站立执扇半遮面，回眸看镜头，并拢微立，含蓄浅笑',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光',
    lightDirectionAngle: 135,
    shootingDistance: '2-3m',
    background: '园林/竹林/古建/白墙黛瓦',
    props: ['团扇', '折扇', '油纸伞'],
    bestTime: '上午 8:00-10:00 或下午 15:00-17:00',
    bestTimeFrom: '08:00',
    bestTimeTo: '10:00',
    tips: [
      '侧逆光勾勒人物轮廓',
      '选择莫兰迪冷调背景（灰墙/竹林）',
      '服装选低饱和汉服',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -5,
      contrast: 5,
      saturation: -15,
      temperature: -10,
      tint: 0,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: -5,
    ),
    smoothStrength: 12,
    sharpen: 10,
    vignette: 15,
    grain: 8,
    lut: 'cinematic',
  ),
);
