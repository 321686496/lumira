// lib/features/capture/data/templates/mountain_dawn.dart
import '../../domain/photo_template.dart';

/// 山岳晨光模板（风光 / 大气应急 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate mountainDawnTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'mountain_dawn',
    name: '群山破晓',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'wide'),
    tags: ['风光', '山岳', '云海', '晨雾', '大气'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/mountain_dawn.jpg'),
    ],
    description: '黄金时刻侧逆光将雪峰染成金橙，与冷调云海森林形成强烈冷暖对比的日照金山奇观。',
    referenceSource: '样片参考：500px 高山日出云海精选；参数参考风光摄影黄金时刻合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'center_cross',
    subjectFrame: SubjectFrame(x: 0.1, y: 0.15, w: 0.8, h: 0.7),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '竖构图3:4比例。大远景，平视正拍。雪山主体居中，占据画面核心视觉区（上部60%）。头顶（天空）留白充足展示云彩层次，脚下（森林）压低稳住重心。云海作为中间过渡层增加空间深度。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 6200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'telephoto_70mm_plus',
    lensType: '长焦镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为自然太阳光，从屏幕左侧偏低角度（约15-30度高度角）射入，属于硬光。光线直接照射在山体左侧面及顶部，形成强烈的明暗分界。光比极大（约5:1以上），受光面极亮呈金黄，背光面及山谷深陷于蓝紫阴影中。阴影投向屏幕右侧及山谷深处，边缘清晰锐利。无需人工补光，纯自然光环境。',
    shootingDistance: '远距离（需长焦拉近，实际距离数公里）',
    background: '高海拔雪山群峰，背景为渐变橙红色晚霞天空',
    props: [],
    bestTime: '17:30-18:15 (日落前20分钟) 或 07:00-07:40 (日出后20分钟)',
    tips: [
      '必须使用长焦镜头（建议70mm以上）压缩空间，让雪山显得巨大且逼近，排除杂乱前景。',
      '曝光策略：对着雪山受光面（最亮处）测光并适当降低曝光补偿（-0.3至-0.7EV），防止金色高光过曝死白，保留岩石纹理。',
      '白平衡设置：手动设定K值在6000-6500之间，强化夕阳的暖橙色调，避免自动白平衡将金光修正为白光。',
      '构图要点：确保主峰完整且居中，下方保留一层云海或雾气以增加仙气，最底部用暗色树林压住阵脚。',
      '后期无法复现说明：真实的空气透视感和长焦压缩感无法通过手机数码变焦完美模拟，建议尽量靠近拍摄点或使用外接长焦镜头。',
      '稳定性：长焦拍摄极易抖动，务必使用三脚架或依托固定物体，开启防抖模式。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -2, contrast: 18, saturation: 25, temperature: 12, tint: 5, highlights: -15, shadows: 8, clarity: 20, vibrance: 15),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 5,
    lut: 'warm_film',
  ),
);
