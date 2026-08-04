// lib/features/capture/domain/photo_template.dart
import 'package:flutter/foundation.dart';

/// 内部哨兵常量，用于区分 copyWith 中"未传入参数"与"显式传入 null"。
/// 解决 `systemFilter ?? this.systemFilter` 无法将 nullable 字段清空的问题。
const _unset = Object();

class PhotoTemplate {
  final TemplateMeta meta;
  final Composition composition;
  final Pose pose;
  final CameraParams camera;
  final SceneGuide sceneGuide;
  final PostProcess postProcess;

  const PhotoTemplate({
    required this.meta,
    required this.composition,
    required this.pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
  });

  PhotoTemplate copyWith({
    TemplateMeta? meta,
    Composition? composition,
    Pose? pose,
    CameraParams? camera,
    SceneGuide? sceneGuide,
    PostProcess? postProcess,
  }) =>
      PhotoTemplate(
        meta: meta ?? this.meta,
        composition: composition ?? this.composition,
        pose: pose ?? this.pose,
        camera: camera ?? this.camera,
        sceneGuide: sceneGuide ?? this.sceneGuide,
        postProcess: postProcess ?? this.postProcess,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoTemplate &&
          meta == other.meta &&
          composition == other.composition &&
          pose == other.pose &&
          camera == other.camera &&
          sceneGuide == other.sceneGuide &&
          postProcess == other.postProcess;

  @override
  int get hashCode => Object.hash(meta, composition, pose, camera, sceneGuide, postProcess);
}

class TemplateMeta {
  final String id;
  final String name;
  final String author;
  final String version;
  final String category;
  final TemplateClassification classification;
  final List<String> tags;
  final List<String> tagIds;
  final int price;
  final String cover;
  final String description;
  final String referenceSource;

  const TemplateMeta({
    required this.id,
    required this.name,
    this.author = 'Lumira',
    this.version = '1.0',
    required this.category,
    required this.classification,
    this.tags = const [],
    this.tagIds = const [],
    this.price = 0,
    this.cover = '',
    this.description = '',
    this.referenceSource = '',
  });

  TemplateMeta copyWith({
    String? id,
    String? name,
    String? author,
    String? version,
    String? category,
    TemplateClassification? classification,
    List<String>? tags,
    List<String>? tagIds,
    int? price,
    String? cover,
    String? description,
    String? referenceSource,
  }) =>
      TemplateMeta(
        id: id ?? this.id,
        name: name ?? this.name,
        author: author ?? this.author,
        version: version ?? this.version,
        category: category ?? this.category,
        classification: classification ?? this.classification,
        tags: tags ?? this.tags,
        tagIds: tagIds ?? this.tagIds,
        price: price ?? this.price,
        cover: cover ?? this.cover,
        description: description ?? this.description,
        referenceSource: referenceSource ?? this.referenceSource,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateMeta &&
          id == other.id &&
          name == other.name &&
          author == other.author &&
          version == other.version &&
          category == other.category &&
          classification == other.classification &&
          listEquals(tags, other.tags) &&
          listEquals(tagIds, other.tagIds) &&
          price == other.price &&
          cover == other.cover &&
          description == other.description &&
          referenceSource == other.referenceSource;

  @override
  int get hashCode => Object.hash(id, name, author, version, category, classification,
      Object.hashAll(tags), Object.hashAll(tagIds), price, cover, description, referenceSource);
}

class TemplateClassification {
  final String type;
  final String style;
  final String method;
  const TemplateClassification({required this.type, this.style = '', this.method = ''});

  TemplateClassification copyWith({String? type, String? style, String? method}) =>
      TemplateClassification(type: type ?? this.type, style: style ?? this.style, method: method ?? this.method);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateClassification &&
          type == other.type && style == other.style && method == other.method;

  @override
  int get hashCode => Object.hash(type, style, method);
}

class Composition {
  final String overlayType;
  final String? gridType;
  final SubjectFrame? subjectFrame;
  final double opacity;
  final String aspectRatio;
  final String description;
  const Composition({
    this.overlayType = 'rule_of_thirds',
    this.gridType,
    this.subjectFrame,
    this.opacity = 0.5,
    this.aspectRatio = '3:4',
    this.description = '',
  });

  Composition copyWith({
    String? overlayType,
    String? gridType,
    SubjectFrame? subjectFrame,
    double? opacity,
    String? aspectRatio,
    String? description,
  }) =>
      Composition(
        overlayType: overlayType ?? this.overlayType,
        gridType: gridType ?? this.gridType,
        subjectFrame: subjectFrame ?? this.subjectFrame,
        opacity: opacity ?? this.opacity,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Composition &&
          overlayType == other.overlayType &&
          gridType == other.gridType &&
          subjectFrame == other.subjectFrame &&
          opacity == other.opacity &&
          aspectRatio == other.aspectRatio &&
          description == other.description;

  @override
  int get hashCode => Object.hash(overlayType, gridType, subjectFrame, opacity, aspectRatio, description);

  Map<String, dynamic> toJson() => {
        'overlayType': overlayType,
        if (gridType != null) 'gridType': gridType,
        if (subjectFrame != null)
          'subjectFrame': {
            'x': subjectFrame!.x,
            'y': subjectFrame!.y,
            'w': subjectFrame!.w,
            'h': subjectFrame!.h,
          },
        'opacity': opacity,
        'aspectRatio': aspectRatio,
        'description': description,
      };

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
        overlayType: json['overlayType'] as String? ?? 'rule_of_thirds',
        gridType: json['gridType'] as String?,
        subjectFrame: (json['subjectFrame'] as Map<String, dynamic>?) != null
            ? SubjectFrame(
                x: (json['subjectFrame']['x'] as num).toDouble(),
                y: (json['subjectFrame']['y'] as num).toDouble(),
                w: (json['subjectFrame']['w'] as num).toDouble(),
                h: (json['subjectFrame']['h'] as num).toDouble(),
              )
            : null,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
        aspectRatio: json['aspectRatio'] as String? ?? '3:4',
        description: json['description'] as String? ?? '',
      );
}

class SubjectFrame {
  final double x, y, w, h;
  const SubjectFrame({required this.x, required this.y, required this.w, required this.h});

  SubjectFrame copyWith({double? x, double? y, double? w, double? h}) =>
      SubjectFrame(x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectFrame && x == other.x && y == other.y && w == other.w && h == other.h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

class SilhouetteResource {
  final String type; // 'builtin' | 'image' | 'svg'
  final String data;
  final String? filename;
  final int? sizeKB;
  const SilhouetteResource({required this.type, this.data = 'none', this.filename, this.sizeKB});

  SilhouetteResource copyWith({String? type, String? data, String? filename, int? sizeKB}) =>
      SilhouetteResource(
          type: type ?? this.type,
          data: data ?? this.data,
          filename: filename ?? this.filename,
          sizeKB: sizeKB ?? this.sizeKB);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SilhouetteResource &&
          type == other.type && data == other.data &&
          filename == other.filename && sizeKB == other.sizeKB;

  @override
  int get hashCode => Object.hash(type, data, filename, sizeKB);
}

class Position {
  final double x;
  final double y;
  const Position({this.x = 0.5, this.y = 0.5});

  Position copyWith({double? x, double? y}) => Position(x: x ?? this.x, y: y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Position && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

class Pose {
  final SilhouetteResource silhouette;
  final Position position;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final String description;
  const Pose({
    this.silhouette = const SilhouetteResource(type: 'builtin', data: 'none'),
    this.position = const Position(),
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1.0,
    this.rotation = 0,
    this.description = '',
  });

  Pose copyWith({
    SilhouetteResource? silhouette,
    Position? position,
    double? positionX,
    double? positionY,
    double? scale,
    double? rotation,
    String? description,
  }) =>
      Pose(
        silhouette: silhouette ?? this.silhouette,
        position: position ?? this.position,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pose &&
          silhouette == other.silhouette &&
          position == other.position &&
          positionX == other.positionX &&
          positionY == other.positionY &&
          scale == other.scale &&
          rotation == other.rotation &&
          description == other.description;

  @override
  int get hashCode => Object.hash(silhouette, position, positionX, positionY, scale, rotation, description);
}

class CameraParams {
  final double exposureCompensation;
  final int iso;
  final String shutterSpeed;
  final String whiteBalance;
  final int whiteBalanceK;
  final String flashMode;
  final String focusMode;
  final String? lensType;
  final String? isoMode;
  final String? lensSuggestion;
  const CameraParams({
    this.exposureCompensation = 0.0,
    this.iso = 200,
    this.shutterSpeed = '1/200',
    this.whiteBalance = 'daylight',
    this.whiteBalanceK = 5500,
    this.flashMode = 'off',
    this.focusMode = 'auto',
    this.lensType,
    this.isoMode,
    this.lensSuggestion,
  });

  CameraParams copyWith({
    double? exposureCompensation,
    int? iso,
    String? shutterSpeed,
    String? whiteBalance,
    int? whiteBalanceK,
    String? flashMode,
    String? focusMode,
    String? lensType,
    String? isoMode,
    String? lensSuggestion,
  }) =>
      CameraParams(
        exposureCompensation: exposureCompensation ?? this.exposureCompensation,
        iso: iso ?? this.iso,
        shutterSpeed: shutterSpeed ?? this.shutterSpeed,
        whiteBalance: whiteBalance ?? this.whiteBalance,
        whiteBalanceK: whiteBalanceK ?? this.whiteBalanceK,
        flashMode: flashMode ?? this.flashMode,
        focusMode: focusMode ?? this.focusMode,
        lensType: lensType ?? this.lensType,
        isoMode: isoMode ?? this.isoMode,
        lensSuggestion: lensSuggestion ?? this.lensSuggestion,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraParams &&
          exposureCompensation == other.exposureCompensation &&
          iso == other.iso &&
          shutterSpeed == other.shutterSpeed &&
          whiteBalance == other.whiteBalance &&
          whiteBalanceK == other.whiteBalanceK &&
          flashMode == other.flashMode &&
          focusMode == other.focusMode &&
          lensType == other.lensType &&
          isoMode == other.isoMode &&
          lensSuggestion == other.lensSuggestion;

  @override
  int get hashCode => Object.hash(exposureCompensation, iso, shutterSpeed, whiteBalance,
      whiteBalanceK, flashMode, focusMode, lensType, isoMode, lensSuggestion);

  Map<String, dynamic> toJson() => {
        'exposureCompensation': exposureCompensation,
        'iso': iso,
        'shutterSpeed': shutterSpeed,
        'whiteBalance': whiteBalance,
        'whiteBalanceK': whiteBalanceK,
        'flashMode': flashMode,
        'focusMode': focusMode,
        if (lensType != null) 'lensType': lensType,
        if (isoMode != null) 'isoMode': isoMode,
        if (lensSuggestion != null) 'lensSuggestion': lensSuggestion,
      };

  factory CameraParams.fromJson(Map<String, dynamic> json) => CameraParams(
        exposureCompensation: (json['exposureCompensation'] as num?)?.toDouble() ?? 0.0,
        iso: (json['iso'] as num?)?.toInt() ?? 200,
        shutterSpeed: json['shutterSpeed'] as String? ?? '1/200',
        whiteBalance: json['whiteBalance'] as String? ?? 'daylight',
        whiteBalanceK: (json['whiteBalanceK'] as num?)?.toInt() ?? 5500,
        flashMode: json['flashMode'] as String? ?? 'off',
        focusMode: json['focusMode'] as String? ?? 'auto',
        lensType: json['lensType'] as String?,
        isoMode: json['isoMode'] as String?,
        lensSuggestion: json['lensSuggestion'] as String?,
      );
}

class SceneGuide {
  final String lightDirection;
  final String shootingDistance;
  final String background;
  final List<String> props;
  final String bestTime;
  final List<String> tips;
  final String? presetId;
  final double? lightDirectionAngle;
  final double? shootingDistanceM;
  final String? bestTimeFrom;
  final String? bestTimeTo;
  const SceneGuide({
    this.lightDirection = '',
    this.shootingDistance = '',
    this.background = '',
    this.props = const [],
    this.bestTime = '',
    this.tips = const [],
    this.presetId,
    this.lightDirectionAngle,
    this.shootingDistanceM,
    this.bestTimeFrom,
    this.bestTimeTo,
  });

  SceneGuide copyWith({
    String? lightDirection,
    String? shootingDistance,
    String? background,
    List<String>? props,
    String? bestTime,
    List<String>? tips,
    String? presetId,
    double? lightDirectionAngle,
    double? shootingDistanceM,
    String? bestTimeFrom,
    String? bestTimeTo,
  }) =>
      SceneGuide(
        lightDirection: lightDirection ?? this.lightDirection,
        shootingDistance: shootingDistance ?? this.shootingDistance,
        background: background ?? this.background,
        props: props ?? this.props,
        bestTime: bestTime ?? this.bestTime,
        tips: tips ?? this.tips,
        presetId: presetId ?? this.presetId,
        lightDirectionAngle: lightDirectionAngle ?? this.lightDirectionAngle,
        shootingDistanceM: shootingDistanceM ?? this.shootingDistanceM,
        bestTimeFrom: bestTimeFrom ?? this.bestTimeFrom,
        bestTimeTo: bestTimeTo ?? this.bestTimeTo,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneGuide &&
          lightDirection == other.lightDirection &&
          shootingDistance == other.shootingDistance &&
          background == other.background &&
          listEquals(props, other.props) &&
          bestTime == other.bestTime &&
          listEquals(tips, other.tips) &&
          presetId == other.presetId &&
          lightDirectionAngle == other.lightDirectionAngle &&
          shootingDistanceM == other.shootingDistanceM &&
          bestTimeFrom == other.bestTimeFrom &&
          bestTimeTo == other.bestTimeTo;

  @override
  int get hashCode => Object.hash(lightDirection, shootingDistance, background,
      Object.hashAll(props), bestTime, Object.hashAll(tips), presetId,
      lightDirectionAngle, shootingDistanceM, bestTimeFrom, bestTimeTo);
}

class PostProcess {
  final String cropRatio;
  final PostProcessColor color;
  final int smoothStrength;
  final int sharpen;
  final int vignette;
  final int grain;
  final String lut;
  final String? systemFilter;
  const PostProcess({
    this.cropRatio = '3:4',
    required this.color,
    this.smoothStrength = 0,
    this.sharpen = 0,
    this.vignette = 0,
    this.grain = 0,
    this.lut = 'none',
    this.systemFilter,
  });

  /// copyWith 的 systemFilter 参数使用 [_unset] 哨兵区分两种情况：
  /// - 未传入（使用 `_unset`）→ 保留原值
  /// - 显式传入 null → 清空为 null（用于"原图"按钮）
  PostProcess copyWith({
    String? cropRatio,
    PostProcessColor? color,
    int? smoothStrength,
    int? sharpen,
    int? vignette,
    int? grain,
    String? lut,
    Object? systemFilter = _unset,
  }) =>
      PostProcess(
        cropRatio: cropRatio ?? this.cropRatio,
        color: color ?? this.color,
        smoothStrength: smoothStrength ?? this.smoothStrength,
        sharpen: sharpen ?? this.sharpen,
        vignette: vignette ?? this.vignette,
        grain: grain ?? this.grain,
        lut: lut ?? this.lut,
        systemFilter: identical(systemFilter, _unset)
            ? this.systemFilter
            : systemFilter as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostProcess &&
          cropRatio == other.cropRatio &&
          color == other.color &&
          smoothStrength == other.smoothStrength &&
          sharpen == other.sharpen &&
          vignette == other.vignette &&
          grain == other.grain &&
          lut == other.lut &&
          systemFilter == other.systemFilter;

  @override
  int get hashCode => Object.hash(cropRatio, color, smoothStrength, sharpen, vignette, grain, lut, systemFilter);

  Map<String, dynamic> toJson() => {
        'cropRatio': cropRatio,
        'color': color.toJson(),
        'smoothStrength': smoothStrength,
        'sharpen': sharpen,
        'vignette': vignette,
        'grain': grain,
        'lut': lut,
        if (systemFilter != null) 'systemFilter': systemFilter,
      };

  /// 将另一个 PostProcess（增量）合并到当前参数上，返回全量参数。
  ///
  /// 用于预览页保存：照片已烘焙 [_bakedPostProcess]，用户在编辑页调整了 [_localPostProcess]（增量），
  /// 保存时需要全量参数 = baked + local（增量）从原图重新处理。
  PostProcess merge(PostProcess delta) => PostProcess(
        cropRatio: cropRatio,
        color: color.merge(delta.color),
        smoothStrength: smoothStrength + delta.smoothStrength,
        sharpen: sharpen + delta.sharpen,
        vignette: vignette + delta.vignette,
        grain: grain + delta.grain,
        lut: delta.lut != 'none' ? delta.lut : lut,
        systemFilter: delta.systemFilter ?? systemFilter,
      );

  factory PostProcess.fromJson(Map<String, dynamic> json) => PostProcess(
        cropRatio: json['cropRatio'] as String? ?? '3:4',
        color: PostProcessColor.fromJson(json['color'] as Map<String, dynamic>? ?? {}),
        smoothStrength: (json['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (json['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (json['vignette'] as num?)?.toInt() ?? 0,
        grain: (json['grain'] as num?)?.toInt() ?? 0,
        lut: json['lut'] as String? ?? 'none',
        systemFilter: json['systemFilter'] as String?,
      );
}

/// 照片变换参数（旋转/翻转/拉直）
/// 用于非破坏性编辑：保存时从原图重新应用变换
class TransformParams {
  final int rotation;        // 0, 90, 180, 270
  final bool flipH;
  final bool flipV;
  final double straighten;   // -15.0 到 +15.0 度

  const TransformParams({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0.0,
  });

  /// 是否为恒等变换（无需应用）
  bool get isIdentity =>
      rotation == 0 && !flipH && !flipV && straighten.abs() < 0.01;

  TransformParams copyWith({
    int? rotation,
    bool? flipH,
    bool? flipV,
    double? straighten,
  }) =>
      TransformParams(
        rotation: rotation ?? this.rotation,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        straighten: straighten ?? this.straighten,
      );

  Map<String, dynamic> toJson() => {
        'rotation': rotation,
        'flipH': flipH,
        'flipV': flipV,
        'straighten': straighten,
      };

  factory TransformParams.fromJson(Map<String, dynamic> json) => TransformParams(
        rotation: (json['rotation'] as num?)?.toInt() ?? 0,
        flipH: json['flipH'] as bool? ?? false,
        flipV: json['flipV'] as bool? ?? false,
        straighten: (json['straighten'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransformParams &&
          rotation == other.rotation &&
          flipH == other.flipH &&
          flipV == other.flipV &&
          straighten == other.straighten;

  @override
  int get hashCode => Object.hash(rotation, flipH, flipV, straighten);
}

class PostProcessColor {
  final double brightness;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double? highlights;
  final double? shadows;
  final double? blackPoint;
  final double? clarity;
  final double? vibrance;
  final double? brilliance;
  const PostProcessColor({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights,
    this.shadows,
    this.blackPoint,
    this.clarity,
    this.vibrance,
    this.brilliance,
  });

  PostProcessColor copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
    double? blackPoint,
    double? clarity,
    double? vibrance,
    double? brilliance,
  }) =>
      PostProcessColor(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        blackPoint: blackPoint ?? this.blackPoint,
        clarity: clarity ?? this.clarity,
        vibrance: vibrance ?? this.vibrance,
        brilliance: brilliance ?? this.brilliance,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostProcessColor &&
          brightness == other.brightness &&
          contrast == other.contrast &&
          saturation == other.saturation &&
          temperature == other.temperature &&
          tint == other.tint &&
          highlights == other.highlights &&
          shadows == other.shadows &&
          blackPoint == other.blackPoint &&
          clarity == other.clarity &&
          vibrance == other.vibrance &&
          brilliance == other.brilliance;

  /// 将增量参数合并到当前参数上（用于预览页保存时计算全量参数）。
  PostProcessColor merge(PostProcessColor delta) => PostProcessColor(
        brightness: brightness + delta.brightness,
        contrast: contrast + delta.contrast,
        saturation: saturation + delta.saturation,
        temperature: temperature + delta.temperature,
        tint: tint + delta.tint,
        highlights: (highlights ?? 0) + (delta.highlights ?? 0),
        shadows: (shadows ?? 0) + (delta.shadows ?? 0),
        blackPoint: (blackPoint ?? 0) + (delta.blackPoint ?? 0),
        clarity: (clarity ?? 0) + (delta.clarity ?? 0),
        vibrance: (vibrance ?? 0) + (delta.vibrance ?? 0),
        brilliance: (brilliance ?? 0) + (delta.brilliance ?? 0),
      );

  @override
  int get hashCode => Object.hash(brightness, contrast, saturation, temperature, tint,
      highlights, shadows, blackPoint, clarity, vibrance, brilliance);

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        if (highlights != null) 'highlights': highlights,
        if (shadows != null) 'shadows': shadows,
        if (blackPoint != null) 'blackPoint': blackPoint,
        if (clarity != null) 'clarity': clarity,
        if (vibrance != null) 'vibrance': vibrance,
        if (brilliance != null) 'brilliance': brilliance,
      };

  factory PostProcessColor.fromJson(Map<String, dynamic> json) => PostProcessColor(
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
        tint: (json['tint'] as num?)?.toDouble() ?? 0,
        highlights: (json['highlights'] as num?)?.toDouble(),
        shadows: (json['shadows'] as num?)?.toDouble(),
        blackPoint: (json['blackPoint'] as num?)?.toDouble(),
        clarity: (json['clarity'] as num?)?.toDouble(),
        vibrance: (json['vibrance'] as num?)?.toDouble(),
        brilliance: (json['brilliance'] as num?)?.toDouble(),
      );
}
