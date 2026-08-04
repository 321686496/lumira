// lib/features/capture/data/templates/street_bw.dart
import '../../domain/photo_template.dart';

/// 黑白街拍模板
/// 来源：lumira-app/src/data/templates/street-bw.ts
const PhotoTemplate streetBwTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'street_bw',
    name: '黑白街拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', method: 'candid'),
    tags: ['黑白', '街拍', '人文', '极简'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/street_bw.jpg',
    description: '黑白街拍摄影，强调光影对比与几何线条，捕捉城市人文瞬间',
    referenceSource: '样片 EXIF: Magnum 街拍作品；参数参考 Magnum Photos 黑白街拍合集',
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.3, w: 0.5, h: 0.5),
    opacity: 0.55,
    aspectRatio: '3:4',
    description: '利用街道透视线引导视线至主体，人物位于线条交汇点或三分线交点',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'walking-street'),
    position: Position(x: 0.4, y: 0.5),
    scale: 0.9,
    rotation: 0,
    description: '模特自然行走姿态，步伐迈开，眼神看向斜前方或低头沉思',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 45° 或顶光（强化阴影与几何感）',
    shootingDistance: '3-8m（街拍距离）',
    background: '城市街道、建筑立面、斑马线、广告牌等几何元素',
    props: ['相机包', '雨伞（雨天增氛围）'],
    bestTime: '上午 9:00-11:00 或下午 15:00-17:00（侧光强烈）',
    tips: [
      '提前对焦锁定距离，等待主体进入构图区域',
      '使用连续对焦捕捉移动主体',
      '寻找强光与深影的对比场景',
      '黑白处理时注意高光不过曝，保留暗部细节',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 0, contrast: 35, saturation: -100, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 40,
    vignette: 25,
    grain: 20,
    lut: 'bw',
  ),
);
