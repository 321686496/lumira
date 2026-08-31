// lib/features/capture/data/templates/starry_meteor.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 流星划过夜空模板（夜景 / 星空 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryMeteorTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_meteor',
    name: '流星划过夜空',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry', method: 'wide'),
    tags: ['夜景', '流星', '星空', '夜空'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/starry_meteor.png'),
    ],
    description: '大远景星空夜景模板。以连绵山脊剪影为前景底边，左侧银河带纵向贯穿、右侧明亮流星斜向划过形成对角呼应，地平线处城市暖光晕染与冷调夜空形成冷暖对比。需长曝光+三脚架固定机位拍摄（真机无法自动长曝光，需手动设置或借助专业模式，本模板以夜色LUT+颗粒+暗角近似模拟星夜质感）。适合天文爱好者、户外露营、追求宇宙浪漫氛围的创作者。',
    shortDesc: '深蓝夜幕下银河垂落，一道绿尾流星划破寂静山脊，地平线暖光微漾，浩瀚治愈又带着宇宙的浪漫孤寂🌌✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['night', 'cool'],
    ),
    referenceSource: '样片参考：流星雨星空摄影；参数参考流星拍摄合集合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal_guide',
    subjectFrame: SubjectFrame(x: 0.15, y: 0.05, w: 0.75, h: 0.75),
    opacity: 0.25,
    aspectRatio: '16:9',
    description: '大远景横拍16:9。机位平视略仰，山脊剪影压底占下部1/5，银河纵贯左侧1/3，流星对角线从右上划向中心偏右，地平线暖光带横贯下1/5上方，星空留白占上部4/5，前景孤树居中偏下作近景锚点，主体（银河+流星）占画幅视觉重心60%，环境夜空占80%以上。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'shade',
    whiteBalanceK: 7200,
    flashMode: 'off',
    focusMode: 'manual_infinity',
    lensSuggestion: 'wide_angle_16mm_equiv',
    lensType: '广角主摄',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '无定向主光源，纯自然星光+地平线远处城市漫反射暖光（从屏幕底部向上微弱晕染）；流星为瞬时自发光轨迹（右上至左下）；银河为弥散冷光；光比极高（星空亮部与山脊纯黑剪影约10:1）；无硬阴影，山脊为纯黑剪影无细节；质感为高感颗粒+星点锐利+银河柔雾状；无需补光（纯自然夜景，补光会破坏星空曝光）',
    shootingDistance: '无限远（对焦无穷远）',
    background: '远离城市光污染的开阔山野/山顶/高原，视野无遮挡，可见银河核心区域',
    props: ['三脚架（必须）', '快门线/定时拍摄（防抖）', '保暖衣物（深夜低温）', '红光头灯（保护暗视力）'],
    bestTime: '22:30-01:30（银河核心可见时段，避开月光）',
    tips: [
      '必须使用三脚架固定机位，真机无法自动长曝光，需切换专业模式手动设置快门15-30秒、ISO 1600-3200、光圈最大（f/2.8或更大）',
      '对焦切换手动模式拧到无穷远（∞），或对准亮星放大确认清晰',
      '关闭闪光灯、关闭HDR、关闭AI场景优化（避免算法涂抹星点）',
      'vignette:28 压暗四角聚焦中央星空；grain:22 模拟高感夜空颗粒质感；sharpen:30 强化星点锐度',
      'lut选twilight强化紫蓝暮色星空氛围，color.temperature:-6微调更冷冽，saturation:+8提升银河色彩层次',
      '地平线暖光为远处城市光污染，非布光效果，选址时保留适度远方城镇可增加冷暖对比层次',
      '流星为偶发天象，需耐心等待或连拍捕捉，无法人为制造，模板仅做构图与色调参考',
      'fillLight禁用：纯夜景补光会严重过曝前景并冲淡星空，绝对不要开补光灯',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -4, contrast: 12, saturation: 8, temperature: -6, tint: 3, highlights: -8, shadows: -15, clarity: 18, vibrance: 10),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 28,
    grain: 22,
    lut: 'twilight',
  ),
);
