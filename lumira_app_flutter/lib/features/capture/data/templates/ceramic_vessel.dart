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
    images: [
      TemplateImage(url: 'assets/images/templates/ceramic_vessel_1.png'),
      TemplateImage(url: 'assets/images/templates/ceramic_vessel_2.png'),
      TemplateImage(url: 'assets/images/templates/ceramic_vessel_3.png'),
      TemplateImage(url: 'assets/images/templates/ceramic_vessel_4.png'),
    ],
    description: '素陶器物沐着温柔窗光，质朴安静，满是松弛侘寂的氛围感',
    referenceSource: '样片参考：Pexels 静物摄影精选；参数参考极简静物教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.24, y: 0.28, w: 0.52, h: 0.64),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '静物，平视机位正拍；器物主体占据画面中部，上方大量纯色背景留白，下方保留台面/织物，主体占画幅45-60%，环境背景占40-55%。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.15,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光来自屏幕侧上方（窗边漫射自然光），柔光，光比约2.5:1；阴影柔和边缘模糊，影子投向屏幕另一侧；保留陶器表面砂质颗粒纹理，无强烈高光反光；环境为室内漫反射环境光。',
    shootingDistance: '1.2-1.8m',
    background: '纯色哑光米白/浅灰墙面，避免花纹杂物',
    props: ['粗陶器皿', '棉麻/亚麻布料', '素陶圆盘', '原木桌面'],
    bestTime: '14:00-16:30',
    tips: [
      '使用窗边柔和自然光，避免直射硬阳光，可薄纱窗帘柔化光线',
      '尽量关闭室内顶光，只用窗光作为唯一主光源',
      '靠近主体、让背景离器物更远，模拟浅景深效果；手机无法物理大光圈虚化，依靠构图距离实现层次',
      '台面布料自然褶皱，不要过度平整，贴合侘寂质朴质感',
      '使用vignette轻微压暗四角，把视觉重心收拢到器物本体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 4, contrast: -8, saturation: -10, temperature: 6, tint: 1, highlights: -14, shadows: 10, clarity: 12),
    smoothStrength: 12,
    sharpen: 18,
    vignette: 24,
    grain: 22,
    lut: 'warm_film',
  ),
);
