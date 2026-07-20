// lib/features/capture/data/templates/neon_portrait.dart
import '../../domain/photo_template.dart';

/// 霓虹人像模板
/// 来源：lumira-app/src/data/templates/neon-portrait.ts
const PhotoTemplate neonPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_portrait',
    name: '霓虹人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'film', method: 'normal'),
    tags: ['霓虹', '夜景人像', '赛博朋克', '城市'],
    tagIds: [],
    price: 3,
    cover: 'https://picsum.photos/seed/template-neon-portrait/400/600',
    description: '利用城市霓虹灯光拍摄赛博朋克风格人像',
    referenceSource: '样片 EXIF: 赛博朋克人像作品集；参数参考 500px Neon Portrait 专题',
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    subjectFrame: SubjectFrame(x: 0.4, y: 0.3, w: 0.25, h: 0.6),
    opacity: 0.45,
    aspectRatio: '9:16',
    description: '人物置于画面右侧，左侧霓虹招牌引导线指向人物',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'neon-pose'),
    position: Position(x: 0.6, y: 0.5),
    scale: 0.9,
    rotation: -5,
    description: '模特微侧身，面部朝向霓虹光源，手部可触碰面部或举起',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'manual',
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'tungsten',
    whiteBalanceK: 3200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 90°（霓虹灯作为主光源）',
    shootingDistance: '1.5-2m',
    background: '霓虹招牌 / 广告灯箱 / 反光玻璃幕墙',
    props: ['霓虹灯环境', '湿润地面（雨后或洒水制造反射）'],
    bestTime: '夜晚 20:00-23:00（霓虹灯最亮时段）',
    tips: [
      '利用霓虹灯色彩渲染面部',
      '面部可部分入阴影营造神秘感',
      '寻找湿润地面制造倒影',
      '低角度仰拍增强人物气场',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(brightness: -10, contrast: 30, saturation: 25, temperature: -15, tint: -10),
    smoothStrength: 20,
    sharpen: 15,
    vignette: 25,
    grain: 15,
    lut: 'cool_film',
  ),
);
