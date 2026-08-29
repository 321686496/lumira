// lib/features/capture/data/templates/architectural_lines.dart
import '../../domain/photo_template.dart';

/// 几何建筑线构模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate architecturalLinesTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'architectural_lines',
    name: '建筑线条几何',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '建筑', '几何', '线条', '极简'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/architectural_lines.png'),
    ],
    description: '晴日硬光下现代几何建筑的线条与体块，锐利阴影切割出高对比黑白极简质感',
    referenceSource: '样片参考：500px 建筑摄影精选；参数参考极简建筑构图教程',
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    gridType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '正方形画幅，建筑填满整个画面，利用建筑竖直线条、横向窗线作为引导线，几何体块左右分割，阴影斜向线条切割画面，不留多余天空留白。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '标准镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '晴天直射硬自然光，光源屏幕左上方约45°，高对比度（约4:1）；阴影边缘锐利、斜向投向右下方墙面，白色墙面干净发白、黑色窗洞深邃，无任何补光。',
    shootingDistance: '8-15m',
    background: '纯白色几何体块现代建筑、浅灰色平整地面、浅白天空',
    props: [],
    bestTime: '10:00-15:00',
    tips: [
      '尽量选择晴天，要有强烈直射阳光，保证锐利硬阴影',
      '对齐建筑横竖线条，手机保持水平，不要倾斜',
      '构图减少大面积天空，重点捕捉斜向落在墙面上的长条阴影',
      '避开阴天漫射光，阴天无法产生锐利切割阴影',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 0, contrast: 22, saturation: -100, temperature: 0, tint: 0, highlights: -18, shadows: 12, blackPoint: 8, clarity: 15),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 12,
    grain: 18,
    lut: 'fine_art_bw',
  ),
);
