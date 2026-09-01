// lib/features/capture/data/templates/neon_storefront.dart
import '../../domain/photo_template.dart';

/// 霓虹招牌夜景模板（夜景 / 霓虹 / 常规）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate neonStorefrontTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_storefront',
    name: '霓虹招牌夜景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'neon', subStyle: 'neon', method: 'normal'),
    tags: ['夜景', '霓虹', '招牌', '夜晚'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/night_cityscape.jpg',
    description: '夜晚街角的霓虹招牌特写，缤纷灯牌与暗色背景形成强烈氛围',
    referenceSource: '样片参考：霓虹招牌夜景精选；参数参考夜景氛围摄影合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '霓虹招牌置于三分线交点，招牌灯光作为主体，背景暗部衬托氛围',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'fluorescent',
    whiteBalanceK: 4200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '招牌霓虹光为主光源（环境光暗）',
    shootingDistance: '5-15m（招牌全貌）',
    background: '霓虹灯牌、夜空、街道暗部与零星车灯',
    props: ['三脚架或稳定手托（夜景低光）'],
    bestTime: '夜晚霓虹点亮后（效果最佳）',
    tips: [
      '保留招牌灯光高光细节，控制过曝',
      '用暗色背景衬托霓虹色彩',
      '可尝试雨后地面反光增强氛围',
      '白平衡倾向冷色可增强夜色感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 0, contrast: 25, saturation: 25, temperature: -15, tint: 10),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 18,
    grain: 12,
    lut: 'neon',
  ),
);