// lib/features/capture/data/templates/indoor_still_life.dart
import '../../domain/photo_template.dart';

/// 室内静物模板
/// 来源：lumira-app/src/data/templates/indoor-still-life.ts
const PhotoTemplate indoorStillLifeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'indoor_still_life',
    name: '室内静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'minimal', method: 'single'),
    tags: ['静物', '室内', '柔光', '生活美学'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/indoor_still_life.jpg',
    description: '室内柔光环境下的静物台面拍摄，突出物体质感与生活气息',
    referenceSource: '样片 EXIF: Pexels 静物摄影作品；参数参考静物摄影教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.4),
    opacity: 0.4,
    aspectRatio: '4:5',
    description: '主体置于三分线交点，利用网格对齐台面物品，保持画面均衡',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'still-life-table'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '静物台面布局参考，物品高低错落，主物居中略偏一侧',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 45°（窗户自然光或柔光箱为主光源）',
    shootingDistance: '0.3-0.8m',
    background: '哑光背景纸或纯色墙面，避免反光与杂色干扰',
    props: ['陶瓷器皿', '亚麻布', '干花', '木质托盘'],
    bestTime: '上午 09:00-11:00（窗光均匀柔和）',
    tips: [
      '使用侧光突出物体表面纹理与质感',
      '避免使用闪光灯造成生硬阴影',
      '主物与辅物形成高低错落的层次',
      '可使用反光板或白卡纸补暗部细节',
      '保持背景简洁，避免杂物入镜',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 10, saturation: 5, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 10,
    grain: 5,
    lut: 'none',
  ),
);
