// lib/features/capture/data/templates/object_leaf.dart
import '../../domain/photo_template.dart';

/// 枯叶纹理微距模板（微距 / 物品 / 细节）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate objectLeafTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'object_leaf',
    name: '枯叶纹理微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'object', subStyle: 'object', method: 'detail'),
    tags: ['微距', '枯叶', '纹理', '细节'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/object_leaf.jpg'),
    ],
    description: '微距放大枯叶的脉络与肌理，呈现时间留下的织密纹路',
    referenceSource: '样片参考：枯叶纹理微距作品；参数参考自然纹理细节合集',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.4),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '叶脉沿对角线延展，局部纹路放大为画面主体，虚化边缘',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光（让叶脉纹理产生立体光影）',
    shootingDistance: '5-12cm（微距）',
    background: '枯叶表面、板材纹理、纯色背景',
    props: ['微距镜头', '背景纸或托架'],
    bestTime: '室内恒定光环境最佳',
    tips: [
      '侧光能凸显叶脉的沟壑质感',
      '对焦锁定最清晰的纹路段',
      '控制景深让局部纹理锐利',
      '防止叶片晃动可压平固定',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 24, saturation: -10, temperature: 10, tint: 8),
    smoothStrength: 0,
    sharpen: 38,
    vignette: 10,
    grain: 8,
    lut: 'nature',
  ),
);
