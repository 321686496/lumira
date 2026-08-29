// lib/features/capture/data/templates/dew_moss.dart
import '../../domain/photo_template.dart';

/// 露珠苔藓模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate dewMossTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'dew_moss',
    name: '苔藓晨露微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '苔藓', '露珠', '自然', '清新'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/dew_moss_1.png'),
      TemplateImage(url: 'assets/images/templates/dew_moss_2.png'),
      TemplateImage(url: 'assets/images/templates/dew_moss_3.png'),
    ],
    description: '雨后清晨苔藓与露珠的微距特写，晨光通透晶莹，展现微观森林的治愈之美。',
    referenceSource: '样片参考：Pexels 微距自然精选；参数参考自然微距教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'third',
    subjectFrame: SubjectFrame(x: 0.02, y: 0.25, w: 0.96, h: 0.73),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '微距特写，低机位贴近地面仰拍苔藓；主体苔藓水珠集中在画面中下区域，上半部分留给虚化环境光斑；主体占画面65%，虚化环境占35%。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕偏左上方45°侧逆光入射；属于硬质晨阳光，光比约4:1；高光打亮水珠边缘形成亮轮廓，阴影落向屏幕右下方，阴影边缘中等硬度；质感表现水珠强反光、通透高光光斑，苔藓保留植物细微纹理；背景形成柔和圆形散景光斑；整体暖金色环境光，主体暖调。',
    shootingDistance: '0.25‑0.45m',
    background: '林间地面，湿润泥土、干枯褐色落叶、湿润灰色石块，背景需要与拍摄主体拉开距离实现虚化散景。',
    props: ['带水珠的鲜活苔藓', '湿润石块', '干枯落叶、松针'],
    bestTime: '06:30‑08:30',
    tips: [
      '尽量雨后清晨拍摄，保证苔藓表面留存自然水珠；不要人工大量喷水，避免水珠形态死板',
      '贴近地面低角度拍摄，手机尽量靠近苔藓，同时主体和背景之间拉开距离，模拟微距浅景深效果，真机无法实现光学大光圈虚化，依靠构图距离配合后期暗角辅助聚焦主体',
      '避开正午强光，强光会直接蒸发水珠，高光容易大面积溢出',
      '对焦锁定水珠或苔藓叶尖，不要对焦远处背景；轻微负向曝光补偿保护水珠高光不发白过曝',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 2, contrast: 10, saturation: 14, temperature: 6, tint: 1, highlights: -18, shadows: 12, clarity: 16),
    smoothStrength: 10,
    sharpen: 28,
    vignette: 28,
    grain: 14,
    lut: 'none',
  ),
);
