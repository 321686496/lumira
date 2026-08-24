// lib/features/capture/data/templates/ceramic_vessel.dart
import '../../domain/photo_template.dart';

/// 素陶瓷器模板（静物 / 极简 / 单体）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate ceramicVesselTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'ceramic_vessel',
    name: '陶器器皿静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'minimal', subStyle: 'minimal', method: 'single'),
    tags: ['静物', '陶器', '极简', '质感', '柔和'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/ceramic_vessel.jpg',
    description: '陶器皿的极简静物表现，柔和侧光突出陶土肌理与优雅轮廓',
    referenceSource: '样片参考：Pexels 静物摄影精选；参数参考极简静物教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.45),
    opacity: 0.4,
    aspectRatio: '4:5',
    description: '单件陶器置于画面中心偏侧，底部留白，背景纯净突出主体剪影',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'still-life-table'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，静物单体呈现',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 45°-60°（突出陶土单侧受光与阴影的立体感）',
    shootingDistance: '0.4-0.8m（半身至整体）',
    background: '哑光纯色墙面 / 浅色亚麻背景布',
    props: ['陶器本身为主', '浅色托盘', '天然布料', '细枝/干花点缀'],
    bestTime: '上午或午后（窗边自然光）',
    tips: [
      '靠窗柔和侧光能让陶土肌理更立体',
      '背景简洁纯净，避免杂物抢走焦点',
      '用反光板给暗部补一点细节',
      '保持画面中的负空间，凸显极简意境',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 8, contrast: 12, saturation: 5, temperature: 8, tint: 0),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 8,
    grain: 5,
    lut: 'none',
  ),
);