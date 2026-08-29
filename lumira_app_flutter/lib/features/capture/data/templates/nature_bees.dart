// lib/features/capture/data/templates/nature_bees.dart
import '../../domain/photo_template.dart';

/// 蜜蜂采蜜微距模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate natureBeesTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'nature_bees',
    name: '蜜蜂采蜜微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '蜜蜂', '采蜜', '自然'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/nature_bees.jpg'),
    ],
    description: '暖阳穿透薄翼，绒毛沾满金黄花粉，定格春日花间最灵动的微距采蜜瞬间。',
    referenceSource: '样片参考：蜜蜂采蜜微距作品；参数参考虫类微距高速拍摄合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'none',
    subjectFrame: SubjectFrame(x: 0.15, y: 0.25, w: 0.7, h: 0.65),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '竖幅3:4构图，微距特写景别。机位平视略俯，贴近花朵高度。主体（蜜蜂+花）占画幅60%，环境（虚化草地）占40%。头顶（画面上方）留有充足绿色负空间，避免压抑。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'tele_macro',
    lensType: '长焦/微距镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为自然日光，从屏幕左上方约45°射入，光线柔和漫射（非正午硬光），光比约2:1。阴影落在蜜蜂腹部下方及花瓣右侧，边缘柔和过渡。无需人工补光，纯自然顺光/侧顺光照明。',
    shootingDistance: '0.1-0.3m (微距距离)',
    background: '远离主体的绿色草坪或低矮植被，确保背景距离主体至少50cm以上以形成虚化。',
    props: ['黄色野花（如蒲公英、雏菊类）', '活跃蜜蜂'],
    bestTime: '09:00-11:00 或 14:00-16:00',
    tips: [
      '使用手机“微距模式”或2x-3x长焦镜头，尽量靠近花朵直至对焦清晰。',
      '保持手部稳定，可寻找支撑点或使用三脚架，微距下轻微抖动都会导致模糊。',
      '等待蜜蜂落稳后再按快门，连拍多张以提高成功率。',
      '真机无法实现光学大光圈虚化时，请尽量让背景远离主体，并在后期适当增加“人像模式/虚化”强度模拟景深。',
      'vignette:20 轻微压暗四角，进一步集中视线到中央蜜蜂身上。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 8, saturation: 18, temperature: 6, tint: 2, highlights: -5, shadows: 10, clarity: 15, vibrance: 12),
    smoothStrength: 10,
    sharpen: 35,
    vignette: 20,
    grain: 5,
    lut: 'fuji',
  ),
);
