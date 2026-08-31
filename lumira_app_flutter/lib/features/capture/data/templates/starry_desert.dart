// lib/features/capture/data/templates/starry_desert.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 璀璨星空模板（夜景 / 星空 / 无方法）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryDesertTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_desert',
    name: '沙漠银河星空',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry'),
    tags: ['夜景', '星空', '银河', '沙漠', '旷野'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/starry_desert.png'),
    ],
    description: "这是一张极具视觉张力的大远景星空风光模板。画面以横亘天际的璀璨银河为背景，前景是一株造型苍劲的荒漠枯木剪影，远处地平线泛着微弱的暖橙色光晕（可能是远方城镇光污染或 twilight 余晖）。整体色调呈现经典的'上冷下暖'对比：深邃的蓝紫夜空与地平线的暖橙形成互补，枯木的纯黑剪影强化了画面的寂寥感与史诗感。适合追求宏大叙事、孤独美学及天文摄影风格的用户。拍摄需极低光环境，依赖三脚架固定与长曝光（或手机夜景模式多帧合成）。",
    shortDesc: '枯木静立沙海，头顶银河倾泻而下，冷暖交织的宇宙级浪漫，孤独又治愈的极致静谧🌌',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['night', 'cool'],
    ),
    referenceSource: '样片参考：500px 银河星野摄影精选；参数参考星野摄影教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal_guide',
    subjectFrame: SubjectFrame(x: 0.15, y: 0.4, w: 0.4, h: 0.55),
    opacity: 0.3,
    aspectRatio: '16:9',
    description: '大远景，平视机位。枯木作为前景趣味点占画面左下约 15%，银河背景占上部 70%，地面与远山占底部 15%。强调横向延展的宽幅视野，突出天空的浩瀚。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 4200,
    flashMode: 'off',
    focusMode: 'manual_infinity',
    lensSuggestion: 'wide_angle_16mm',
    lensType: '广角镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '自然天光（星光）+ 地平线环境漫反射。主光源为满天星斗与银河自身辉光，来自屏幕上方及后方，极软且微弱；地平线处有微弱暖色环境光（屏幕下方），形成逆光剪影效果。光比极大（>10:1），枯木完全欠曝成剪影，星空正常曝光。无需正面补光，保持剪影纯度。',
    shootingDistance: '5-10m (针对枯木前景)，无限远 (针对星空)',
    background: '纯净无光污染的夜空，可见清晰银河带；远处低矮山脉轮廓；平坦沙地或荒漠地面。',
    props: ['造型独特的枯木/死树', '三脚架（必备）', '快门线或定时拍摄'],
    bestTime: '22:00-02:00 (避开月光，银河升起时)',
    tips: [
      '必须使用三脚架固定机位，开启手机‘专业模式’或‘星空模式’，曝光时间建议 15-30 秒（若 App 不支持长曝，则用夜景模式多帧合成，保持绝对静止）。',
      '对焦必须手动锁定在无限远（∞），或点击最亮的星星对焦，防止前景枯木导致跑焦。',
      '白平衡设为自定义 4000-4500K，以还原星空的冷蓝紫调，同时保留地平线暖橙色的对比。',
      '构图时让枯木枝干指向银河核心区域，形成视觉呼应。',
      '真机无法实现单反级别的长曝光星轨，依靠夜景算法提亮暗部；若噪点过多，后期适当增加 grain 掩盖并提升质感。',
      '无需补光灯，任何正面光都会破坏枯木剪影效果和星空对比度。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -5, contrast: 18, saturation: 12, temperature: -8, tint: 5, highlights: -10, shadows: -15, clarity: 25),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 30,
    grain: 22,
    lut: 'twilight',
  ),
);
