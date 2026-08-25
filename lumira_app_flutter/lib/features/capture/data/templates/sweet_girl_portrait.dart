// lib/features/capture/data/templates/sweet_girl_portrait.dart
import '../../domain/photo_template.dart';

/// 甜妹元气少女模板（sweet_girl 子风格）
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 16
const PhotoTemplate sweetGirlPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'sweet_girl_portrait',
    name: '甜美少女半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'fresh_healing', style: 'sweet_girl', subStyle: 'sweet_girl', method: 'half_body'),
    tags: ['人像', '甜妹', '元气', '少女', '粉色'],
    tagIds: [],
    price: 0,
    images: [

      TemplateImage(url: 'assets/images/templates/sweet_girl_portrait.png'),

    ],
    description: '高亮暖粉比心托腮，九宫格甜美元气少女，青春的粉色记忆。',
    referenceSource: '小红书甜妹拍照教程；元气少女风；九宫格甜美拍照',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.15, w: 0.4, h: 0.7),
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线右侧半身取景，比心托腮构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/sweet_girl_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.8,
          rotation: 0,
          description: '正面站立微倾，单手比心至脸侧，头部微歪，并拢微内八，俏皮大笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/sweet_girl_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.8,
          rotation: 0,
          description: '手持手机前置，另一手比耶贴脸，歪头俏皮，甜笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/sweet_girl_portrait.png'),
          position: Position(x: 0.5, y: 0.55),
          scale: 0.7,
          rotation: 0,
          description: '正面站立，双手提起裙摆，脚尖轻踮，灿烂大笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/sweet_girl_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '侧身回头，手轻抚发辫，回眸看向镜头，俏皮甜笑',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光',
    lightDirectionAngle: 30,
    shootingDistance: '1-1.5m',
    background: '纯色粉墙/游乐场/花墙',
    props: ['发夹', '泡泡', '气球'],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '顺光明亮均匀',
      '服装粉色亮色系',
      '表情要甜要活泼',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 12,
      contrast: -5,
      saturation: 8,
      temperature: 8,
      tint: 0,
      highlights: 5,
      shadows: 10,
      clarity: -5,
      vibrance: 5,
    ),
    smoothStrength: 15,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel',
  ),
);
