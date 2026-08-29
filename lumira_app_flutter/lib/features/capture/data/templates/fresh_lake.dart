// lib/features/capture/data/templates/fresh_lake.dart
import '../../domain/photo_template.dart';

/// 湖畔清新平拍模板（风光 / 清新 / 平拍）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate freshLakeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'fresh_lake',
    name: '湖畔清新平拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'flat'),
    tags: ['风光', '湖畔', '清新', '平拍', '治愈'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/fresh_lake.jpg'),
    ],
    description: '平视角的湖畔风光，水面镜面倒影配上清澈天空，营造清新宁静的氛围',
    referenceSource: '样片参考：Pexels 湖畔清新风光精选；参数参考风光摄影清新色调合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'horizontal_thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.25, w: 1.0, h: 0.5),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '竖构图大远景。机位平视。利用前景树叶（上部）和草坪（下部）夹持中景湖面。主体湖面占据画面中央核心位置，约占画幅50%。环境交代完整，天空占上部少量空间。无特定人物主体，强调风景的层次与色彩块面分割。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为晴朗正午的自然顶光/顺光，从屏幕上方偏后照射。光线硬朗，光比大（约4:1）。树叶在下方草坪投下边缘清晰、浓度较深的阴影，方向朝向屏幕下方。湖面有强烈的镜面反光。无需补光，纯自然光拍摄。',
    shootingDistance: '5-10m (面向湖面站立)',
    background: '开阔的碧蓝湖泊 + 对岸连绵的深绿色树林 + 蓝天白云',
    props: ['无 (纯自然景观)'],
    bestTime: '11:00-14:00',
    tips: [
      '寻找一棵枝叶茂密的大树，站在树荫下向湖面拍摄，利用下垂的树枝作为前景框架。',
      '确保脚下是修剪整齐的草坪，以形成底部的绿色色块。',
      '曝光补偿+0.3以防止草地和树叶欠曝变暗，但注意不要过曝导致天空死白。',
      '真机无法实现光学浅景深，依靠前景树叶的自然遮挡和色彩对比来突出层次。',
      '若阳光过于强烈导致反差过大，可后期适当提亮阴影(shadows)。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 8, saturation: 18, temperature: -2, tint: 3, highlights: -10, shadows: 12, vibrance: 15),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 15,
    grain: 0,
    lut: 'fuji',
  ),
);