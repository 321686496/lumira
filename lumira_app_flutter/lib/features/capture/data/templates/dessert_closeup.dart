// lib/features/capture/data/templates/dessert_closeup.dart
import '../../domain/photo_template.dart';

/// 甜点特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate dessertCloseupTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'dessert_closeup',
    name: '甜品奶泡特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '甜点', '特写', '诱人', '细节'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/dessert_closeup.jpg',
    description: '近距离拍摄甜点局部的诱人细节，突出奶油质地、光泽与层次',
    referenceSource: '样片参考：Pexels 甜品摄影精选；参数参考美食微距教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.32, w: 0.45, h: 0.4),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '甜点主体置于三分线交点，侧方留出虚化空间突出主体细节',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'food-overhead'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，重点捕捉甜点的层叠与光泽',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/120',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 45°（窗边自然光为佳，凸显表面质感）',
    shootingDistance: '0.2-0.4m（贴近主体）',
    background: '纯色哑光桌面或浅色木板，避免抢主体注意',
    props: ['浅色盘子/托盘', '细碎装饰（水果、糖粉、薄荷）', '干净餐巾'],
    bestTime: '白天（自然光充足的窗边）',
    tips: [
      '贴近主体使用微距/近摄，突出奶油与果酱纹理',
      '轻微的角度让光线在表面形成细腻高光',
      '背景保持简洁，可用浅景深虚化干扰物',
      '俯拍与 45° 侧拍结合，找到最能展现层次的角度',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 10, saturation: 15, temperature: 8, tint: 0),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 8,
    grain: 0,
    lut: 'none',
  ),
);