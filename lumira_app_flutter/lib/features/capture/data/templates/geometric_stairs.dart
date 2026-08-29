// lib/features/capture/data/templates/geometric_stairs.dart
import '../../domain/photo_template.dart';

/// 旋转楼梯几何模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate geometricStairsTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'geometric_stairs',
    name: '旋转楼梯几何',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '旋转楼梯', '几何', '建筑', '极简'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/geometric_stairs.jpg'),
    ],
    description: '俯拍或仰拍的旋转楼梯，螺旋曲线与同心结构构成强烈的几何韵律',
    referenceSource: '样片参考：旋转楼梯几何摄影作品；参数参考建筑抽象构图合集',
  ),
  composition: Composition(
    overlayType: 'center_focus',
    gridType: 'spiral_guide',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.4,
    aspectRatio: '3:2',
    description: '大远景/全景别，低机位垂直仰拍（90度朝天）。主体为整个螺旋楼梯结构，占画幅95%。环境交代极少，仅中心天窗可见外部天空。无头顶留白概念，改为\'中心留白\'，中心圆直径约占画幅宽度的1/5。构图核心是\'向心式螺旋\'，要求极高的水平校准，任何倾斜都会破坏几何美感。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'ultra_wide',
    lensType: '超广角镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '混合光源。主光为楼梯侧面嵌入的暖橙色LED灯带（约3000K），从屏幕四周向中心漫射，光质较硬但被结构遮挡形成条纹光；辅光为中心天窗的自然天光（约6500K-7000K），从屏幕正上方/中心垂直向下，光质柔和。光比约为 4:1（暖光区亮，背光台阶暗）。阴影落在台阶下方及栏杆背光面，投向屏幕外侧/下方，边缘中等硬度。无需正面补光，依靠环境自发光。',
    shootingDistance: '0.5-1m (紧贴楼梯底部中心)',
    background: '现代建筑内部中庭，白色/浅灰色混凝土或涂料墙面，金属栏杆，玻璃天窗。',
    props: [],
    bestTime: '10:00-14:00',
    tips: [
      '必须使用超广角镜头（0.5x或更广），否则无法收纳完整的螺旋结构。',
      '开启手机相机的\'水平仪\'或\'网格线\'，确保中心点严格居中，画面不旋转。',
      '曝光补偿略微降低（-0.3至-0.7），防止中心天窗过曝死白，同时压暗周围以突出暖光灯带的线条感。',
      '寻找楼梯底部正中心站立，手机镜头朝上完全垂直于地面拍摄。',
      '若现场灯光太暗，可适当提高ISO，但注意控制噪点；此效果真机无法实现长曝光流光，依靠静态灯带即可。',
      '后期重点在于强化\'橙-青\'互补色对比，提升清晰度以凸显金属栏杆质感。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:2',
    color: PostProcessColor(brightness: -2, contrast: 18, saturation: 25, temperature: 8, tint: 5, highlights: -35, shadows: 12, clarity: 28, vibrance: 15),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 30,
    grain: 8,
    lut: 'warm_film',
  ),
);