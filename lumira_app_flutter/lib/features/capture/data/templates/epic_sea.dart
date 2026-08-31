// lib/features/capture/data/templates/epic_sea.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 海天一色远景模板（风光 / 大气 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate epicSeaTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'epic_sea',
    name: '海天一色远景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'wide'),
    tags: ['风光', '大海', '海天', '远景', '大气'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/epic_sea.jpg'),
    ],
    description: '海岸风景模板，高机位俯拍沙滩海洋，自然光日间户外场景，利用海岸线作为引导线，呈现碧海金滩远山白云的开阔海景，适合海边度假记录自然风光。',
    referenceSource: '样片参考：500px 海天一色大气风光精选；参数参考海洋风光黄金时刻合集',
    shortDesc: '澄澈蓝海伴着绵长沙滩，海风辽阔治愈，夏日海边氛围感🌊',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['day'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '大远景风景，高机位俯拍，海平线置于画面上1/3分割线，沙滩海浪引导线从画面左下角向远处延伸；沙滩占画面下半约55%，海洋、远山、天空环境占画面上45%，天空保留充足留白。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.15,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光来自屏幕上方偏左，白天柔和直射日光，属于软‑硬过渡自然光，光比约2.5:1；海浪泡沫亮部高光明显，沙滩阴影柔和，阴影边缘柔和、浓度浅；水面具备波光反光质感，云朵层次分明。',
    shootingDistance: '远距离风景拍摄',
    background: '蓝色海洋、金色沙滩、层叠远山、蓝天白云，近岸带有绿色沿海植被',
    props: [],
    bestTime: '10:00‑15:00',
    tips: [
      '将海平线对齐上方三分线，利用海浪与沙滩交界的曲线做引导线增强纵深感',
      '拍摄尽量避开正午顶光最强时刻，防止海面高光大面积溢出',
      '适当压低高光保留云朵与海面波纹细节，提升阴影还原沙滩纹理',
      '该画面远景虚化效果为光学镜头实现，手机无法复刻，依靠构图引导视线模拟空间层次',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 4, contrast: 5, saturation: 14, temperature: -3, tint: 1, highlights: -12, shadows: 8, vibrance: 9),
    smoothStrength: 0,
    sharpen: 26,
    vignette: 14,
    grain: 12,
    lut: 'fuji',
  ),
);