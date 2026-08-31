// lib/features/capture/data/templates/seaside_dusk.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 海边黄昏模板（风光 / 清新治愈 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate seasideDuskTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'seaside_dusk',
    name: '海边黄昏风光',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'wide'),
    tags: ['风光', '海边', '黄昏', '治愈', '粉色调'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/seaside_dusk.png'),
    ],
    description: '这是一套专为海滨日落设计的风光摄影模板。画面以壮丽的火烧云与金色海面为绝对主体，利用广角镜头收纳从前景礁石浪花到远景山脉建筑的完整层次。光线为典型的黄金时刻逆光/侧逆光，色温极暖，饱和度浓郁。构图采用经典三分法，地平线置于中下部，强调天空云彩的张力与海面反光的质感。适合旅行记录、情绪风光片拍摄，建议搭配三脚架以保证画质清晰。',
    shortDesc: '漫天橘云倾泻入海，浪花吻过礁石碎成金箔，远山静默，这一刻的温柔足以治愈所有疲惫🌅',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['goldenHour'],
    ),
    referenceSource: '样片参考：Pexels 沿海风光精选；参数参考风光摄影黄昏合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds_horizontal',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.3,
    aspectRatio: '16:9',
    description: '大远景，平视机位。采用16:9宽画幅增强电影感。地平线严格水平，置于画面中线略偏下。主体（太阳与反光带）位于左侧三分线，前景礁石位于右下，形成对角呼应。天空留白充足以展现云层纹理。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 6800,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '广角镜头',
    lensSuggestion: 'wide_angle',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为自然太阳光，从屏幕左侧低角度（约5-10度高度）射入，属于强逆光/侧逆光。光线柔和但方向性强，在海面形成强烈镜面反射。光比极大（约1:8），天空高光与礁石阴影反差明显。无需人工补光，依靠自然光与环境反射。',
    shootingDistance: '无限远（风景）',
    background: '开阔海面、远处连绵山脉剪影、右侧海岸线建筑群、布满层积云的天空',
    props: [],
    bestTime: '17:30-18:30',
    tips: [
      '使用三脚架固定机位，确保地平线绝对水平，避免画面倾斜。',
      '测光点选在太阳旁边的亮部云层，适当降低曝光补偿（-0.3至-0.7EV）以保留云彩层次，避免天空过曝死白。',
      '对焦模式设为无限远或手动对焦到前景礁石，保证前后景清晰（小光圈效果需靠后期锐化补偿）。',
      '等待海浪拍打礁石的瞬间按下快门，捕捉白色浪花的动态，增加画面生气。',
      '注意保护镜头，避免太阳直射产生严重眩光，必要时用手或遮光罩遮挡边缘杂光。',
      '真机无法实现长曝光丝滑水面效果，本模板依靠高快门凝固浪花，若需丝滑效果需后期APP模拟或物理ND镜。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(
      brightness: 2,
      contrast: 12,
      saturation: 18,
      temperature: 8,
      tint: 4,
      highlights: -15,
      shadows: 10,
      clarity: 15,
      vibrance: 12,
    ),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 8,
    lut: 'warm_film',
  ),
);
