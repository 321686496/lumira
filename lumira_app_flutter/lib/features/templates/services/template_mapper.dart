import '../../../core/db/dao/templates_dao.dart';
import '../../capture/domain/photo_template.dart';
import '../data/templates_editor_mock_data.dart' as editor;

/// 模板领域对象与 [TemplateRecord] / [editor.EditorForm] 之间的双向映射。
///
/// 同时承担剪影资源（[SilhouetteResource] / [editor.SilhouetteResource]）的自包含序列化：
/// builtin 仅存 key，image 存 base64 data URL，svg 存 inline SVG。
class TemplateMapper {
  TemplateMapper._();

  // === PhotoTemplate ↔ TemplateRecord ===

  /// PhotoTemplate → TemplateRecord。
  /// 注意：新建记录的 [TemplateRecord.isBuiltin] / [TemplateRecord.isRecommended]
  /// 均默认为 false（导入或用户自建模板均不是内置模板）。
  static TemplateRecord toRecord(PhotoTemplate tpl, {required int createdAt}) {
    return TemplateRecord(
      id: tpl.meta.id,
      name: tpl.meta.name,
      author: tpl.meta.author,
      version: tpl.meta.version,
      category: tpl.meta.category,
      classification: {
        'type': tpl.meta.classification.type,
        'style': tpl.meta.classification.style,
        'method': tpl.meta.classification.method,
      },
      tags: List<String>.from(tpl.meta.tags),
      tagIds: List<String>.from(tpl.meta.tagIds),
      price: tpl.meta.price,
      cover: tpl.meta.cover,
      description: tpl.meta.description,
      referenceSource: tpl.meta.referenceSource,
      composition: _compositionToJson(tpl.composition),
      pose: _poseToJson(tpl.pose),
      camera: _cameraToJson(tpl.camera),
      sceneGuide: _sceneGuideToJson(tpl.sceneGuide),
      postProcess: _postProcessToJson(tpl.postProcess),
      createdAt: createdAt,
      updatedAt: createdAt,
      isBuiltin: false,
      isRecommended: false,
    );
  }

  /// TemplateRecord → PhotoTemplate。
  static PhotoTemplate toPhotoTemplate(TemplateRecord r) {
    return PhotoTemplate(
      meta: TemplateMeta(
        id: r.id,
        name: r.name,
        author: r.author,
        version: r.version,
        category: r.category,
        classification: TemplateClassification(
          type: (r.classification['type'] as String?) ?? r.category,
          style: (r.classification['style'] as String?) ?? '',
          method: (r.classification['method'] as String?) ?? '',
        ),
        tags: List<String>.from(r.tags),
        tagIds: List<String>.from(r.tagIds),
        price: r.price,
        cover: r.cover,
        description: r.description,
        referenceSource: r.referenceSource,
      ),
      composition: _compositionFromJson(r.composition),
      pose: _poseFromJson(r.pose),
      camera: _cameraFromJson(r.camera),
      sceneGuide: _sceneGuideFromJson(r.sceneGuide),
      postProcess: _postProcessFromJson(r.postProcess),
    );
  }

  // === EditorForm ↔ TemplateRecord ===

  /// EditorForm → TemplateRecord。
  /// 编辑器表单不包含 author/version/cover/tagIds/price 等字段，使用默认值填充。
  static TemplateRecord fromEditorForm(editor.EditorForm form, {String? id, required int createdAt}) {
    return TemplateRecord(
      id: id ?? form.meta.id,
      name: form.meta.name,
      author: 'Lumira',
      version: '1.0.0',
      category: form.meta.category,
      classification: {
        'type': form.meta.category,
        'style': '',
        'method': '',
      },
      tags: List<String>.from(form.meta.tags),
      tagIds: const [],
      price: 0,
      cover: '',
      description: form.meta.description,
      referenceSource: form.meta.referenceSource,
      composition: {
        'overlayType': form.composition.overlayType,
        'aspectRatio': form.composition.aspectRatio,
        'opacity': form.composition.opacity,
        'description': form.composition.description,
      },
      pose: {
        'silhouette': editorSilhouetteToJson(form.pose.silhouette),
        'position': {'x': form.pose.position.x, 'y': form.pose.position.y},
        'scale': form.pose.scale,
        'rotation': form.pose.rotation,
        'description': form.pose.description,
      },
      camera: {
        'exposureCompensation': form.camera.exposureCompensation,
        'isoMode': form.camera.isoMode,
        'iso': form.camera.iso,
        'shutterSpeed': form.camera.shutterSpeed,
        'whiteBalance': form.camera.whiteBalance,
        'whiteBalanceK': form.camera.whiteBalanceK,
        'flashMode': form.camera.flashMode,
        'focusMode': form.camera.focusMode,
        'lensSuggestion': form.camera.lensSuggestion,
      },
      sceneGuide: {
        'lightDirection': form.sceneGuide.lightDirection,
        'shootingDistance': form.sceneGuide.shootingDistance,
        'background': form.sceneGuide.background,
        'props': List<String>.from(form.sceneGuide.props),
        'bestTime': form.sceneGuide.bestTime,
        'tips': List<String>.from(form.sceneGuide.tips),
      },
      postProcess: {
        'cropRatio': form.postProcess.cropRatio,
        'color': {
          'brightness': form.postProcess.color.brightness,
          'contrast': form.postProcess.color.contrast,
          'saturation': form.postProcess.color.saturation,
          'temperature': form.postProcess.color.temperature,
          'tint': form.postProcess.color.tint,
        },
        'smoothStrength': form.postProcess.smoothStrength,
        'sharpen': form.postProcess.sharpen,
        'vignette': form.postProcess.vignette,
        'grain': form.postProcess.grain,
        'lut': form.postProcess.lut,
      },
      createdAt: createdAt,
      updatedAt: createdAt,
      isBuiltin: false,
      isRecommended: false,
    );
  }

  /// TemplateRecord → EditorForm。
  /// 编辑器 PostProcessColor 字段为 int，从 JSON 读取时使用 [num.toInt]。
  static editor.EditorForm toEditorForm(TemplateRecord r) {
    final composition = r.composition;
    final pose = r.pose;
    final camera = r.camera;
    final sceneGuide = r.sceneGuide;
    final postProcess = r.postProcess;
    final colorJson = postProcess['color'] as Map<String, dynamic>?;

    return editor.EditorForm(
      meta: editor.EditorFormMeta(
        id: r.id,
        name: r.name,
        category: r.category,
        tags: List<String>.from(r.tags),
        description: r.description,
        referenceSource: r.referenceSource,
      ),
      composition: editor.EditorFormComposition(
        overlayType: (composition['overlayType'] as String?) ?? 'rule_of_thirds',
        aspectRatio: (composition['aspectRatio'] as String?) ?? '3:4',
        opacity: (composition['opacity'] as num?)?.toDouble() ?? 0.5,
        description: (composition['description'] as String?) ?? '',
      ),
      pose: editor.EditorFormPose(
        silhouette: _toEditorSilhouette(
          silhouetteFromJson((pose['silhouette'] as Map<String, dynamic>?) ?? {}),
        ),
        position: editor.Position(
          x: ((pose['position'] as Map<String, dynamic>?)?['x'] as num?)?.toDouble() ?? 0.5,
          y: ((pose['position'] as Map<String, dynamic>?)?['y'] as num?)?.toDouble() ?? 0.5,
        ),
        scale: (pose['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (pose['rotation'] as num?)?.toDouble() ?? 0,
        description: (pose['description'] as String?) ?? '',
      ),
      camera: editor.EditorFormCamera(
        exposureCompensation: (camera['exposureCompensation'] as num?)?.toDouble() ?? 0.0,
        isoMode: (camera['isoMode'] as String?) ?? 'auto',
        iso: (camera['iso'] as num?)?.toInt() ?? 200,
        shutterSpeed: (camera['shutterSpeed'] as String?) ?? '1/200',
        whiteBalance: (camera['whiteBalance'] as String?) ?? 'daylight',
        whiteBalanceK: (camera['whiteBalanceK'] as num?)?.toInt() ?? 5500,
        flashMode: (camera['flashMode'] as String?) ?? 'off',
        focusMode: (camera['focusMode'] as String?) ?? 'auto',
        lensSuggestion: (camera['lensSuggestion'] as String?) ?? 'main',
      ),
      sceneGuide: editor.EditorFormSceneGuide(
        lightDirection: (sceneGuide['lightDirection'] as String?) ?? '',
        shootingDistance: (sceneGuide['shootingDistance'] as String?) ?? '',
        background: (sceneGuide['background'] as String?) ?? '',
        props: (sceneGuide['props'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        bestTime: (sceneGuide['bestTime'] as String?) ?? '',
        tips: (sceneGuide['tips'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      postProcess: editor.EditorFormPostProcess(
        cropRatio: (postProcess['cropRatio'] as String?) ?? '3:4',
        color: editor.PostProcessColor(
          brightness: (colorJson?['brightness'] as num?)?.toInt() ?? 0,
          contrast: (colorJson?['contrast'] as num?)?.toInt() ?? 0,
          saturation: (colorJson?['saturation'] as num?)?.toInt() ?? 0,
          temperature: (colorJson?['temperature'] as num?)?.toInt() ?? 0,
          tint: (colorJson?['tint'] as num?)?.toInt() ?? 0,
        ),
        smoothStrength: (postProcess['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (postProcess['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (postProcess['vignette'] as num?)?.toInt() ?? 0,
        grain: (postProcess['grain'] as num?)?.toInt() ?? 0,
        lut: (postProcess['lut'] as String?) ?? 'none',
      ),
    );
  }

  // === Silhouette 序列化 ===

  /// PhotoTemplate 剪影 → JSON。
  /// builtin: 仅存 key；image: base64 data URL + filename + sizeKB；svg: inline SVG。
  static Map<String, dynamic> silhouetteToJson(SilhouetteResource s) {
    final json = <String, dynamic>{
      'type': s.type,
      'data': s.data,
    };
    if (s.filename != null) json['filename'] = s.filename;
    if (s.sizeKB != null) json['sizeKB'] = s.sizeKB;
    return json;
  }

  /// EditorForm 剪影 → JSON（与 [silhouetteToJson] 同结构）。
  static Map<String, dynamic> editorSilhouetteToJson(editor.SilhouetteResource s) {
    final json = <String, dynamic>{
      'type': s.type,
      'data': s.data,
    };
    if (s.filename != null) json['filename'] = s.filename;
    if (s.sizeKB != null) json['sizeKB'] = s.sizeKB;
    return json;
  }

  /// JSON → PhotoTemplate 剪影。
  static SilhouetteResource silhouetteFromJson(Map<String, dynamic> json) {
    return SilhouetteResource(
      type: (json['type'] as String?) ?? 'builtin',
      data: (json['data'] as String?) ?? 'none',
      filename: json['filename'] as String?,
      sizeKB: (json['sizeKB'] as num?)?.toInt(),
    );
  }

  // === 私有 helper：PhotoTemplate 子结构 → JSON ===

  static Map<String, dynamic> _compositionToJson(Composition c) {
    final json = <String, dynamic>{
      'overlayType': c.overlayType,
      'opacity': c.opacity,
      'aspectRatio': c.aspectRatio,
      'description': c.description,
    };
    if (c.gridType != null) json['gridType'] = c.gridType;
    if (c.subjectFrame != null) {
      final f = c.subjectFrame!;
      json['subjectFrame'] = {'x': f.x, 'y': f.y, 'w': f.w, 'h': f.h};
    }
    return json;
  }

  static Map<String, dynamic> _poseToJson(Pose p) {
    return <String, dynamic>{
      'silhouette': silhouetteToJson(p.silhouette),
      'position': {'x': p.position.x, 'y': p.position.y},
      'scale': p.scale,
      'rotation': p.rotation,
      'description': p.description,
    };
  }

  static Map<String, dynamic> _cameraToJson(CameraParams c) {
    final json = <String, dynamic>{
      'exposureCompensation': c.exposureCompensation,
      'iso': c.iso,
      'shutterSpeed': c.shutterSpeed,
      'whiteBalance': c.whiteBalance,
      'whiteBalanceK': c.whiteBalanceK,
      'flashMode': c.flashMode,
      'focusMode': c.focusMode,
    };
    if (c.isoMode != null) json['isoMode'] = c.isoMode;
    if (c.lensSuggestion != null) json['lensSuggestion'] = c.lensSuggestion;
    return json;
  }

  static Map<String, dynamic> _sceneGuideToJson(SceneGuide s) {
    return <String, dynamic>{
      'lightDirection': s.lightDirection,
      'shootingDistance': s.shootingDistance,
      'background': s.background,
      'props': List<String>.from(s.props),
      'bestTime': s.bestTime,
      'tips': List<String>.from(s.tips),
    };
  }

  static Map<String, dynamic> _postProcessToJson(PostProcess p) {
    return <String, dynamic>{
      'cropRatio': p.cropRatio,
      'color': {
        'brightness': p.color.brightness,
        'contrast': p.color.contrast,
        'saturation': p.color.saturation,
        'temperature': p.color.temperature,
        'tint': p.color.tint,
      },
      'smoothStrength': p.smoothStrength,
      'sharpen': p.sharpen,
      'vignette': p.vignette,
      'grain': p.grain,
      'lut': p.lut,
    };
  }

  // === 私有 helper：JSON → PhotoTemplate 子结构 ===

  static Composition _compositionFromJson(Map<String, dynamic> json) {
    final sfJson = json['subjectFrame'] as Map<String, dynamic>?;
    return Composition(
      overlayType: (json['overlayType'] as String?) ?? 'rule_of_thirds',
      gridType: json['gridType'] as String?,
      subjectFrame: sfJson == null
          ? null
          : SubjectFrame(
              x: (sfJson['x'] as num?)?.toDouble() ?? 0,
              y: (sfJson['y'] as num?)?.toDouble() ?? 0,
              w: (sfJson['w'] as num?)?.toDouble() ?? 0,
              h: (sfJson['h'] as num?)?.toDouble() ?? 0,
            ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
      aspectRatio: (json['aspectRatio'] as String?) ?? '3:4',
      description: (json['description'] as String?) ?? '',
    );
  }

  static Pose _poseFromJson(Map<String, dynamic> json) {
    final posJson = json['position'] as Map<String, dynamic>?;
    return Pose(
      silhouette: silhouetteFromJson((json['silhouette'] as Map<String, dynamic>?) ?? {}),
      position: Position(
        x: (posJson?['x'] as num?)?.toDouble() ?? 0.5,
        y: (posJson?['y'] as num?)?.toDouble() ?? 0.5,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      description: (json['description'] as String?) ?? '',
    );
  }

  static CameraParams _cameraFromJson(Map<String, dynamic> json) {
    return CameraParams(
      exposureCompensation: (json['exposureCompensation'] as num?)?.toDouble() ?? 0.0,
      iso: (json['iso'] as num?)?.toInt() ?? 200,
      shutterSpeed: (json['shutterSpeed'] as String?) ?? '1/200',
      whiteBalance: (json['whiteBalance'] as String?) ?? 'daylight',
      whiteBalanceK: (json['whiteBalanceK'] as num?)?.toInt() ?? 5500,
      flashMode: (json['flashMode'] as String?) ?? 'off',
      focusMode: (json['focusMode'] as String?) ?? 'auto',
      isoMode: json['isoMode'] as String?,
      lensSuggestion: json['lensSuggestion'] as String?,
    );
  }

  static SceneGuide _sceneGuideFromJson(Map<String, dynamic> json) {
    return SceneGuide(
      lightDirection: (json['lightDirection'] as String?) ?? '',
      shootingDistance: (json['shootingDistance'] as String?) ?? '',
      background: (json['background'] as String?) ?? '',
      props: (json['props'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      bestTime: (json['bestTime'] as String?) ?? '',
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  static PostProcess _postProcessFromJson(Map<String, dynamic> json) {
    final colorJson = json['color'] as Map<String, dynamic>?;
    return PostProcess(
      cropRatio: (json['cropRatio'] as String?) ?? '3:4',
      color: PostProcessColor(
        brightness: (colorJson?['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (colorJson?['contrast'] as num?)?.toDouble() ?? 0,
        saturation: (colorJson?['saturation'] as num?)?.toDouble() ?? 0,
        temperature: (colorJson?['temperature'] as num?)?.toDouble() ?? 0,
        tint: (colorJson?['tint'] as num?)?.toDouble() ?? 0,
      ),
      smoothStrength: (json['smoothStrength'] as num?)?.toInt() ?? 0,
      sharpen: (json['sharpen'] as num?)?.toInt() ?? 0,
      vignette: (json['vignette'] as num?)?.toInt() ?? 0,
      grain: (json['grain'] as num?)?.toInt() ?? 0,
      lut: (json['lut'] as String?) ?? 'none',
    );
  }

  // === 私有 helper：剪影类型转换 ===

  static editor.SilhouetteResource _toEditorSilhouette(SilhouetteResource s) {
    return editor.SilhouetteResource(
      type: s.type,
      data: s.data,
      filename: s.filename,
      sizeKB: s.sizeKB,
    );
  }
}
