import '../../../core/config/app_config.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../capture/domain/photo_template.dart';
import '../data/builtin_silhouettes.dart';
import '../data/templates_editor_mock_data.dart' as editor;
import '../data/remote_template_dto.dart';

/// 模板领域对象与 [TemplateRecord] / [editor.EditorForm] 之间的双向映射。
///
/// 同时承担剪影资源（[SilhouetteResource] / [editor.SilhouetteResource]）的自包含序列化：
/// builtin 仅存 key，image 存 base64 data URL，svg 存 inline SVG。
class TemplateMapper {
  TemplateMapper._();

  // === PhotoTemplate ↔ TemplateRecord ===

  /// PhotoTemplate → TemplateRecord。
  /// 注意：新建记录默认 [TemplateRecord.isBuiltin] / [TemplateRecord.isRecommended]
  /// 均为 false（导入或用户自建模板均不是内置模板）。
  /// 内置模板种子化时通过 [isBuiltin] / [isRecommended] 参数覆盖。
  static TemplateRecord toRecord(
    PhotoTemplate tpl, {
    required int createdAt,
    bool isBuiltin = false,
    bool isRecommended = false,
  }) {
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
      coverData: tpl.meta.coverData,
      description: tpl.meta.description,
      referenceSource: tpl.meta.referenceSource,
      composition: _compositionToJson(tpl.composition),
      pose: _poseToJson(tpl.pose),
      camera: _cameraToJson(tpl.camera),
      sceneGuide: _sceneGuideToJson(tpl.sceneGuide),
      postProcess: _postProcessToJson(tpl.postProcess),
      createdAt: createdAt,
      updatedAt: createdAt,
      isBuiltin: isBuiltin,
      isRecommended: isRecommended,
    );
  }

  /// 远程模板 meta DTO → TemplateRecord。
  ///
  /// 用于 [remoteTemplatesSyncProvider] 拉取后端 list 后 upsert 到 sqflite。
  /// 5 段内容 JSON（composition/pose/camera/sceneGuide/postProcess）设为空 Map，
  /// 详情按需拉取时由 [detailToRecord] 覆盖填充。
  /// source 固定为 'remote'，isBuiltin/isRecommend 均为 false（后端动态模板不是系统内置）。
  /// cover 字段使用后端 coverUrl（绝对或相对 URL），coverData 留空（不预下载 base64）。
  static TemplateRecord metaToRecord(RemoteTemplateMetaDto meta) {
    return TemplateRecord(
      id: meta.id,
      name: meta.name,
      author: meta.author,
      version: meta.version,
      category: meta.category,
      classification: <String, dynamic>{
        'type': meta.classification.type,
        'style': meta.classification.style,
        'method': meta.classification.method,
      },
      tags: List<String>.from(meta.tags),
      tagIds: List<String>.from(meta.tagIds),
      price: meta.price,
      cover: meta.coverUrl,
      coverData: null,
      description: meta.description,
      referenceSource: meta.referenceSource,
      composition: const <String, dynamic>{},
      pose: const <String, dynamic>{},
      camera: const <String, dynamic>{},
      sceneGuide: const <String, dynamic>{},
      postProcess: const <String, dynamic>{},
      createdAt: meta.updatedAt,
      updatedAt: meta.updatedAt,
      isBuiltin: false,
      isRecommended: false,
      source: 'remote',
    );
  }

  /// 远程模板完整内容 DTO → TemplateRecord。
  ///
  /// 用于 [remoteTemplateDetailProvider] 详情按需拉取时 upsert 到 sqflite。
  /// 在 meta 基础上覆盖 5 段内容 JSON，使详情页能从本地缓存读取完整内容。
  /// createdAt 保留 meta.updatedAt（与列表同步时一致，便于 prune 判定）。
  static TemplateRecord detailToRecord(RemoteTemplateDetailDto detail) {
    // RemoteTemplateDetailDto 与 RemoteTemplateMetaDto 字段重叠但非继承关系，
    // 此处构造一个 meta DTO 复用 metaToRecord 逻辑，避免字段映射重复。
    final meta = RemoteTemplateMetaDto(
      id: detail.id,
      name: detail.name,
      author: detail.author,
      version: detail.version,
      category: detail.category,
      price: detail.price,
      coverUrl: detail.coverUrl,
      description: detail.description,
      referenceSource: detail.referenceSource,
      tags: detail.tags,
      tagIds: detail.tagIds,
      classification: detail.classification,
      sortOrder: detail.sortOrder,
      updatedAt: detail.updatedAt,
    );
    final metaRecord = metaToRecord(meta);
    return metaRecord.copyWith(
      composition: detail.composition,
      pose: detail.pose,
      camera: detail.camera,
      sceneGuide: detail.sceneGuide,
      postProcess: detail.postProcess,
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
        cover: normalizeAssetUrl(r.cover),
        coverData: r.coverData,
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
  ///
  /// 与 domain 对齐的新增字段序列化：
  /// - meta.coverImage → coverData（base64 data URL）
  /// - composition.gridType / subjectFrame
  /// - camera.lensType
  /// - postProcess.color.highlights/shadows/blackPoint/clarity/vibrance/brilliance（可空）
  /// - postProcess.systemFilter（可空）
  /// - fillLight（启用时序列化到 postProcess.fillLight 子对象）
  static TemplateRecord fromEditorForm(editor.EditorForm form, {String? id, required int createdAt}) {
    final postProcessJson = <String, dynamic>{
      'cropRatio': form.postProcess.cropRatio,
      'color': <String, dynamic>{
        'brightness': form.postProcess.color.brightness,
        'contrast': form.postProcess.color.contrast,
        'saturation': form.postProcess.color.saturation,
        'temperature': form.postProcess.color.temperature,
        'tint': form.postProcess.color.tint,
        if (form.postProcess.color.highlights != null)
          'highlights': form.postProcess.color.highlights,
        if (form.postProcess.color.shadows != null)
          'shadows': form.postProcess.color.shadows,
        if (form.postProcess.color.blackPoint != null)
          'blackPoint': form.postProcess.color.blackPoint,
        if (form.postProcess.color.clarity != null)
          'clarity': form.postProcess.color.clarity,
        if (form.postProcess.color.vibrance != null)
          'vibrance': form.postProcess.color.vibrance,
        if (form.postProcess.color.brilliance != null)
          'brilliance': form.postProcess.color.brilliance,
      },
      'smoothStrength': form.postProcess.smoothStrength,
      'sharpen': form.postProcess.sharpen,
      'vignette': form.postProcess.vignette,
      'grain': form.postProcess.grain,
      'lut': form.postProcess.lut,
      if (form.postProcess.systemFilter != null)
        'systemFilter': form.postProcess.systemFilter,
    };
    // 补光灯：启用时序列化到 postProcess.fillLight 子对象
    if (form.fillLight != null && form.fillLight!.enabled) {
      postProcessJson['fillLight'] = <String, dynamic>{
        'enabled': form.fillLight!.enabled,
        'color': form.fillLight!.color,
        'intensity': form.fillLight!.intensity,
      };
    }

    final compositionJson = <String, dynamic>{
      'overlayType': form.composition.overlayType,
      'aspectRatio': form.composition.aspectRatio,
      'opacity': form.composition.opacity,
      'description': form.composition.description,
      if (form.composition.gridType != null)
        'gridType': form.composition.gridType,
      if (form.composition.subjectFrame != null)
        'subjectFrame': <String, dynamic>{
          'x': form.composition.subjectFrame!.x,
          'y': form.composition.subjectFrame!.y,
          'w': form.composition.subjectFrame!.w,
          'h': form.composition.subjectFrame!.h,
        },
    };

    final cameraJson = <String, dynamic>{
      'exposureCompensation': form.camera.exposureCompensation,
      'isoMode': form.camera.isoMode,
      'iso': form.camera.iso,
      'shutterSpeed': form.camera.shutterSpeed,
      'whiteBalance': form.camera.whiteBalance,
      'whiteBalanceK': form.camera.whiteBalanceK,
      'flashMode': form.camera.flashMode,
      'focusMode': form.camera.focusMode,
      'lensSuggestion': form.camera.lensSuggestion,
      if (form.camera.lensType != null) 'lensType': form.camera.lensType,
    };

    final classificationJson = <String, dynamic>{
      'type': form.meta.category,
      'style': form.meta.style ?? '',
      'method': form.meta.method ?? '',
    };

    return TemplateRecord(
      id: id ?? form.meta.id,
      name: form.meta.name,
      author: 'Lumira',
      version: '1.0.0',
      category: form.meta.category,
      classification: classificationJson,
      tags: List<String>.from(form.meta.tags),
      tagIds: const [],
      price: 0,
      cover: '',
      coverData: form.meta.coverImage,
      description: form.meta.description,
      referenceSource: form.meta.referenceSource,
      composition: compositionJson,
      pose: <String, dynamic>{
        'silhouette': editorSilhouetteToJson(form.pose.silhouette),
        'position': {'x': form.pose.position.x, 'y': form.pose.position.y},
        'scale': form.pose.scale,
        'rotation': form.pose.rotation,
        'description': form.pose.description,
      },
      camera: cameraJson,
      sceneGuide: <String, dynamic>{
        'lightDirection': form.sceneGuide.lightDirection,
        'shootingDistance': form.sceneGuide.shootingDistance,
        'background': form.sceneGuide.background,
        'props': List<String>.from(form.sceneGuide.props),
        'bestTime': form.sceneGuide.bestTime,
        'tips': List<String>.from(form.sceneGuide.tips),
      },
      postProcess: postProcessJson,
      createdAt: createdAt,
      updatedAt: createdAt,
      isBuiltin: false,
      isRecommended: false,
      source: 'custom',
    );
  }

  /// TemplateRecord → EditorForm。
  /// 与 domain 对齐：PostProcessColor 字段为 double（旧数据 int 会被 num.toDouble 兜底）。
  /// 新增字段（gridType/subjectFrame/lensType/highlights/.../systemFilter/fillLight）
  /// 缺失时回退到 null 默认值，向后兼容旧模板数据。
  static editor.EditorForm toEditorForm(TemplateRecord r) {
    final composition = r.composition;
    final pose = r.pose;
    final camera = r.camera;
    final sceneGuide = r.sceneGuide;
    final postProcess = r.postProcess;
    final colorJson = postProcess['color'] as Map<String, dynamic>?;
    final fillLightJson = postProcess['fillLight'] as Map<String, dynamic>?;
    final sfJson = composition['subjectFrame'] as Map<String, dynamic>?;

    return editor.EditorForm(
      meta: editor.EditorFormMeta(
        id: r.id,
        name: r.name,
        category: r.category,
        tags: List<String>.from(r.tags),
        description: r.description,
        referenceSource: r.referenceSource,
        style: (r.classification['style'] as String?)?.isNotEmpty == true
            ? r.classification['style'] as String
            : null,
        method: (r.classification['method'] as String?)?.isNotEmpty == true
            ? r.classification['method'] as String
            : null,
        coverImage: r.coverData,
      ),
      composition: editor.EditorFormComposition(
        overlayType: (composition['overlayType'] as String?) ?? 'rule_of_thirds',
        gridType: composition['gridType'] as String?,
        subjectFrame: sfJson == null
            ? null
            : SubjectFrame(
                x: (sfJson['x'] as num?)?.toDouble() ?? 0,
                y: (sfJson['y'] as num?)?.toDouble() ?? 0,
                w: (sfJson['w'] as num?)?.toDouble() ?? 0,
                h: (sfJson['h'] as num?)?.toDouble() ?? 0,
              ),
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
        lensType: camera['lensType'] as String?,
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
          brightness: (colorJson?['brightness'] as num?)?.toDouble() ?? 0.0,
          contrast: (colorJson?['contrast'] as num?)?.toDouble() ?? 0.0,
          saturation: (colorJson?['saturation'] as num?)?.toDouble() ?? 0.0,
          temperature: (colorJson?['temperature'] as num?)?.toDouble() ?? 0.0,
          tint: (colorJson?['tint'] as num?)?.toDouble() ?? 0.0,
          highlights: (colorJson?['highlights'] as num?)?.toDouble(),
          shadows: (colorJson?['shadows'] as num?)?.toDouble(),
          blackPoint: (colorJson?['blackPoint'] as num?)?.toDouble(),
          clarity: (colorJson?['clarity'] as num?)?.toDouble(),
          vibrance: (colorJson?['vibrance'] as num?)?.toDouble(),
          brilliance: (colorJson?['brilliance'] as num?)?.toDouble(),
        ),
        smoothStrength: (postProcess['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (postProcess['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (postProcess['vignette'] as num?)?.toInt() ?? 0,
        grain: (postProcess['grain'] as num?)?.toInt() ?? 0,
        lut: (postProcess['lut'] as String?) ?? 'none',
        systemFilter: postProcess['systemFilter'] as String?,
      ),
      fillLight: fillLightJson == null
          ? null
          : editor.EditorFormFillLight(
              enabled: (fillLightJson['enabled'] as bool?) ?? false,
              color: (fillLightJson['color'] as num?)?.toInt() ?? 0xFFFFE5B4,
              intensity: (fillLightJson['intensity'] as num?)?.toDouble() ?? 0.8,
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
  /// 优先读 data 字段，为空或 'none' 时回退到 url 字段（后端兼容字段）。
  /// 若 type 为 builtin 但 data 实际是 http URL（后端上传剪影时未更新 type），自动修正为 image。
  static SilhouetteResource silhouetteFromJson(Map<String, dynamic> json) {
    var type = (json['type'] as String?) ?? 'builtin';
    var data = (json['data'] as String?) ?? '';
    // data 为空或 'none' 时，尝试从 url 字段获取（后端 silhouette 对象同时含 url 和 data）
    if (data.isEmpty || data == 'none') {
      data = (json['url'] as String?) ?? '';
    }
    data = normalizeAssetUrl(data.isNotEmpty ? data : 'none');
    // 后端 bug 修复：上传剪影图片时可能未更新 type，仍为 builtin
    // 若 data 是 http URL 但 type 不是 image，自动修正为 image
    if (type != 'image' &&
        (data.startsWith('http://') || data.startsWith('https://'))) {
      type = 'image';
    }
    return SilhouetteResource(
      type: type,
      data: data,
      filename: json['filename'] as String?,
      sizeKB: (json['sizeKB'] as num?)?.toInt(),
    );
  }

  /// 规范化静态资源 URL：本地缓存的旧数据可能以 localhost/127.0.0.1 为前缀
  /// （后端 BACKEND_PUBLIC_URL 配置前写入），用 [AppConfig.baseUrl] 推导的
  /// 服务 origin 替换，保证图片/剪影在 App 端可加载。
  /// 也处理相对路径（以 / 开头）：自动补全服务 origin，避免 TemplateCoverImage
  /// 和 PoseSilhouette 因 URL 不满足 startsWith('http') 而无法加载。
  static String normalizeAssetUrl(String url) {
    // 相对路径：补全服务器 origin
    if (url.startsWith('/')) {
      final base = Uri.tryParse(AppConfig.baseUrl);
      if (base != null && base.host.isNotEmpty) {
        final origin =
            '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
        return '$origin$url';
      }
    }
    if (!url.startsWith('http://localhost') &&
        !url.startsWith('http://127.0.0.1') &&
        !url.startsWith('https://localhost') &&
        !url.startsWith('https://127.0.0.1')) {
      return url;
    }
    final base = Uri.tryParse(AppConfig.baseUrl);
    if (base == null || base.host.isEmpty) return url;
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    // 取 url 中主机之后的路径部分（如 /uploads/templates/x/cover.jpg）
    final schemeEnd = url.indexOf('://') + 3;
    final pathIdx = url.indexOf('/', schemeEnd);
    final path = pathIdx >= 0 ? url.substring(pathIdx) : '/';
    return '$origin$path';
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

  // === 导入 JSON → TemplateRecord ===

  /// 从导入的 JSON 构造 TemplateRecord
  /// 自动嗅探格式：
  ///   - json['format'] == 'pptpl' 或 json['composition']?.containsKey('subjectFrame') → 完整 pptpl
  ///   - 否则 → 简化 lumira
  /// 内置剪影 key 不存在于白名单时降级为 'none'，并记录 warning 日志
  static TemplateRecord recordFromImportedJson(
    Map<String, dynamic> json, {
    required int createdAt,
  }) {
    final isPptpl = _sniffPptpl(json);
    final meta = (json['meta'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final id = (meta['id'] as String?) ?? 'imported_$createdAt';
    final name = (meta['name'] as String?) ?? '未命名模板';
    final author = (meta['author'] as String?) ?? 'imported';
    final category = (meta['category'] as String?) ?? 'still-life';
    final tags = (meta['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final tagIds =
        (meta['tagIds'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final price = (meta['price'] as num?)?.toInt() ?? 0;
    final cover = (meta['cover'] as String?) ?? '';
    final coverData = (meta['coverData'] as String?) ??
        (cover.startsWith('data:') ? cover : null);
    final description = (meta['description'] as String?) ?? '';
    final referenceSource = (meta['referenceSource'] as String?) ?? '';

    Map<String, dynamic> composition;
    Map<String, dynamic> pose;
    Map<String, dynamic> camera;
    Map<String, dynamic> sceneGuide;
    Map<String, dynamic> postProcess;

    if (isPptpl) {
      composition =
          (json['composition'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      pose = _normalizePose((json['pose'] as Map<String, dynamic>?) ?? {});
      camera = (json['camera'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      sceneGuide =
          (json['sceneGuide'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      postProcess = (json['postProcess'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
    } else {
      // lumira 简化格式：仅 meta + camera + composition.overlayType，其余填默认
      final cam =
          (json['camera'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final comp =
          (json['composition'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      composition = {
        'overlayType': comp['overlayType'] ?? 'rule_of_thirds',
      };
      pose = <String, dynamic>{
        'silhouette': {'type': 'builtin', 'data': 'none'},
        'position': {'x': 0.5, 'y': 0.5},
        'scale': 1.0,
        'rotation': 0,
      };
      camera = cam;
      sceneGuide = <String, dynamic>{};
      postProcess = <String, dynamic>{'cropRatio': '3:4', 'lut': 'none'};
    }

    // 剪影降级：builtin key 不在白名单 → 'none'
    pose = _degradeSilhouetteIfNeeded(pose);

    return TemplateRecord(
      id: id,
      name: name,
      author: author,
      version: '1.0.0',
      category: category,
      classification: <String, dynamic>{},
      tags: tags,
      tagIds: tagIds,
      price: price,
      cover: cover,
      coverData: coverData,
      description: description,
      referenceSource: referenceSource,
      composition: composition,
      pose: pose,
      camera: camera,
      sceneGuide: sceneGuide,
      postProcess: postProcess,
      createdAt: createdAt,
      updatedAt: createdAt,
      isBuiltin: false,
      isRecommended: false,
      // 导入的模板属于用户自定义模板（否则默认 source='builtin'，
      // 会导致 getCustomOnly/getCustomAndRemote 查询不到，列表不显示）
      source: 'custom',
    );
  }

  /// 嗅探是否为完整 pptpl 格式
  static bool _sniffPptpl(Map<String, dynamic> json) {
    final format = json['format'] as String?;
    if (format == 'pptpl') return true;
    final comp = json['composition'];
    if (comp is Map<String, dynamic> && comp.containsKey('subjectFrame')) {
      return true;
    }
    return false;
  }

  /// 规范化 pose 字段，确保 silhouette / position / scale / rotation 存在
  static Map<String, dynamic> _normalizePose(Map<String, dynamic> pose) {
    final silhouette =
        pose['silhouette'] as Map<String, dynamic>? ?? <String, dynamic>{
      'type': 'builtin',
      'data': 'none',
    };
    final position =
        pose['position'] as Map<String, dynamic>? ?? <String, dynamic>{
      'x': 0.5,
      'y': 0.5,
    };
    return {
      'silhouette': silhouette,
      'position': position,
      'scale': pose['scale'] ?? 1.0,
      'rotation': pose['rotation'] ?? 0,
    };
  }

  /// 内置剪影 key 不存在于白名单时降级为 'none'
  /// 白名单来源：BuiltinSilhouettes.keys（真实剪影库 12 key）
  static Map<String, dynamic> _degradeSilhouetteIfNeeded(
      Map<String, dynamic> pose) {
    final silhouette = pose['silhouette'];
    if (silhouette is! Map<String, dynamic>) return pose;
    if (silhouette['type'] != 'builtin') return pose;

    final key = silhouette['data'] as String?;
    if (key == null || key == 'none') return pose;
    if (!kBuiltinSilhouetteKeys.contains(key)) {
      // ignore: avoid_print
      print('Warning: builtin silhouette key "$key" not found in library, '
          'degrading to "none"');
      return {
        ...pose,
        'silhouette': {'type': 'builtin', 'data': 'none'},
      };
    }
    return pose;
  }
}
