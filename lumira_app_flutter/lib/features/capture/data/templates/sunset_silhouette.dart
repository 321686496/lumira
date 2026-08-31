// lib/features/capture/data/templates/sunset_silhouette.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 日落逆光剪影模板
/// 来源：lumira-app/src/data/templates/sunset-silhouette.ts
const PhotoTemplate sunsetSilhouetteTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'sunset_silhouette',
    name: '夕阳剪影远景人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'emotional', subStyle: 'emotional', method: 'wide'),
    tags: ['逆光', '剪影', '黄昏', '人像'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/sunset_silhouette.png'),
    ],
    description: '黄昏山顶逆光剪影人像模板：太阳悬于屏幕右侧山脊之上，整片天空烧成橙金，人物以纯黑剪影立于画面中偏左，背对镜头、面部90°侧向屏幕右凝望落日，松散丸子头的碎发被逆光勾出金色轮廓光。穿搭要点：细吊带连身裙露出肩颈与锁骨线条，颈部一条细项链在逆光下隐约闪光，丸子头务必扯松留碎发。适合想拍氛围感背影杀、不愿露全脸也能出片的用户。',
    shortDesc: '落日熔金，山峦沉入暮色，她侧脸镶着一层金边，安静得像一首诗🌇',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['goldenHour'],
    ),
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.24, y: 0.27, w: 0.4, h: 0.73),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '正方形构图，半身景别（裁至腰臀以下、大腿以上），平视机位、正后方略偏屏幕左拍摄；人物主体占画面中偏左约45%宽、自下缘延伸至约28%高，发顶距上缘留白约28%交给天空与云；太阳置于屏幕右中三分线交点附近，与左侧人物形成左右呼应；下1/3为层叠远山与前景草影，上2/3为橙金天空，环境占比约60%。',
  ),
  poses: [
    Pose(
      name: '封面·侧身望日剪影',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/sunset_silhouette_pose1.png'),
      position: Position(x: 0.4, y: 0.62),
      scale: 0.95,
      rotation: 0,
      description: '站姿，身体约135°斜背对镜头（肩背朝向镜头、肩线略偏屏幕左），面部完全转向屏幕右约-90°呈标准侧脸，形成\u2018背身侧脸回眸望日\u2019；头颈保持水平不低不仰、下巴微收，头颈几乎无侧倾；双肩放松下沉、背部挺直；双臂自然垂落身体两侧，画面右侧手臂贴近躯干、手指放松微曲；重心均匀落于双腿、站姿稳定；视线平视屏幕右方的落日，表情安静松弛，侧脸轮廓（额头-鼻尖-唇-下巴）保持清晰锐利的剪影线条。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.7,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 6800,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '主摄镜头',
    lensSuggestion: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '自然落日为唯一强光源，从屏幕右前方低角度（接近地平线高度）逆光射来，光型偏硬但被大气柔化；光比极大约8:1以上，人物正面完全处于自身阴影中成纯黑剪影；逆光在丸子头碎发、耳廓、鼻尖、唇缘、肩线与吊带边缘勾出金色轮廓光；太阳在屏幕右中形成圆形高光与放射光晕；无需任何正面补光——补光会破坏剪影，如需看清面部细节才另开补光灯从屏幕正面低强度补光。',
    shootingDistance: '2-3m',
    background: '山顶或高地观景位，西向开阔视野：层叠远山轮廓+大面积落日天空+低空碎云，山脊线压在画面下1/3',
    props: ['细吊带连身裙', '细项链', '松丸子头碎发'],
    bestTime: '17:40-18:40（日落前40分钟至日落后10分钟）',
    tips: [
      '先量比例：样片为1:1正方形，机内裁切或后期cropRatio按1:1输出',
      '对天空亮部/太阳边缘点测光并压EV约-0.7~-1.0，让人物自然沉为纯黑剪影，切勿对人脸测光',
      '人物必须站在镜头与太阳之间形成逆光，太阳留在画面屏幕右中，人物放屏幕中偏左，遵守三分法',
      '侧脸90°转向屏幕右，保持额头-鼻尖-下巴的轮廓线条清晰，双下巴与低头都会毁掉剪影',
      '丸子头扯松、两鬓与后颈留碎发，逆光会把碎发照成金色发光丝',
      '穿细吊带或露肩装，让肩颈与锁骨轮廓进入剪影，配饰选细项链即可',
      '真机无法光学虚化远山：靠\u2018人物2-3m、远山无限远\u2019的自然距离差+vignette:25压四角近似层次',
      '剪影要的是黑透：postProcess不启用fillLight；若不小心拍成半亮脸，后期把blackPoint/shadows压低救回',
      '风大时顺发丝方向侧站，让飘发增强氛围；无云时可用远山脊线托住太阳位置',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(
      brightness: -2,
      contrast: 12,
      saturation: 18,
      temperature: 6,
      tint: 2,
      highlights: -10,
      shadows: -12,
      clarity: 6,
      vibrance: 8,
    ),
    smoothStrength: 15,
    sharpen: 25,
    vignette: 25,
    grain: 18,
    lut: 'warm_film',
  ),
);
