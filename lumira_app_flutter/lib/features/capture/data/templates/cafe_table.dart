// lib/features/capture/data/templates/cafe_table.dart
import '../../domain/photo_template.dart';

/// 餐桌氛围模板（美食 / 俯拍 / 平面）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate cafeTableTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'cafe_table',
    name: '咖啡馆午后桌面',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'overhead', subStyle: 'overhead', method: 'flat'),
    tags: ['美食', '咖啡', '餐桌', '俯拍', '生活气息'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/cafe_table.jpg',
    description: '咖啡馆餐桌的 90 度俯拍，咖啡、甜点与桌面物件构成温暖的生活画面',
    referenceSource: '样片参考：Pexels 咖啡馆俯拍精选；参数参考美食平铺摄影教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '主物（咖啡杯）居中偏一侧，餐具与小物件沿对角线摆放构建节奏',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'food-overhead'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，重点呈现桌面物件分布与色彩搭配',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 250,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '自然窗光顺光（避免直射硬影）',
    shootingDistance: '0.5-1m（机位正上方垂直于桌面）',
    background: '木纹桌面、亚麻布、大理石纹均可',
    props: ['咖啡杯/咖啡壶', '甜点或面包', '餐巾', '书本/小花做氛围点缀'],
    bestTime: '上午或午后（咖啡馆窗边自然光）',
    tips: [
      '手机与桌面严格平行，避免透视畸变',
      '物件之间预留留白，画面更透气',
      '咖啡杯与桌布形成色彩对比更出彩',
      '可用 2× 镜头压缩桌面透视',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 12, saturation: 15, temperature: 12, tint: 0),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 5,
    grain: 5,
    lut: 'warm_film',
  ),
);