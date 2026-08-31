// lib/features/capture/data/templates/epic_valley.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 峡谷晨雾俯拍模板（风光 / 大气 / 俯拍）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate epicValleyTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'epic_valley',
    name: '峡谷晨雾俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'overhead'),
    tags: ['风光', '峡谷', '晨雾', '俯拍', '大气'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/epic_valley.jpg'),
    ],
    description: '自然风光大远景模板，高山石阶作为引导线通向远方云海落日，暖金色黄昏侧光打亮山石松林，适合山顶观景台拍摄山川云海风光，可容纳游人作为环境点缀，日落黄金时段出片效果最佳。',
    referenceSource: '样片参考：500px 高山俯拍峡谷晨雾精选；参数参考风光摄影航拍视角合集',
    shortDesc: '金辉漫过山巅云海，石阶向天际延伸，山河壮阔氛围感🌄',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'autumn'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['goldenHour'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.3,
    aspectRatio: '9:16',
    description: '大远景风光，机位略微仰拍；石阶引导线从画面底部向远方延伸；山体框架占据画面左右两侧；云海天际线落在上三分之一分割线，天空保留充足留白；环境占满全部画幅。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/320',
    whiteBalance: 'sunset',
    whiteBalanceK: 6200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕右上方45°黄昏低角度照射，属于硬侧光；无额外辅光；光比约4:1；山体背光面阴影浓重，阴影投向屏幕左下方，阴影边缘偏硬；岩壁、松树受光面呈现强烈金色高光质感；环境光是整片橙黄色黄昏天空漫射光；受光区域暖金，背光山体冷暗，冷暖对比强烈。',
    shootingDistance: '无限远风光拍摄',
    background: '高山花岗岩峭壁、成片松林、漫无边际的层叠云海、橙黄色渐变黄昏天空，山间中式古亭建筑',
    props: [],
    bestTime: '日落前30‑60分钟黄金时刻',
    tips: [
      '站在高处观景台，利用石阶道路做向前汇聚的引导线',
      '等待云海流动的时刻拍摄，中景游人保留少许作为画面层次点缀，不要让人物遮挡远处云海',
      '压低曝光补偿防止天空金色高光过曝丢失层次',
      '该画面宏大景深为光学镜头物理效果，手机无法复刻，依靠构图保留远近层次，使用vignette压暗四角强化纵深感',
      '尽量避开正午强光，优先选择日出日落低角度侧光时段',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(brightness: 2, contrast: 14, saturation: 16, temperature: 8, tint: 5, highlights: -18, shadows: 10, clarity: 12),
    smoothStrength: 0,
    sharpen: 26,
    vignette: 28,
    grain: 22,
    lut: 'warm_film',
  ),
);