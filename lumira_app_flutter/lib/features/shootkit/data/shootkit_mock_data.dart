/// ShootKit 组合编辑器 mock 数据（Task 2.12）
///
/// 视觉规格来源：
/// - lumira-app/src/pages/shootkit/editor.vue (273 行)
/// - lumira-app/src/composables/useShootKit.ts（ShootKit 数据结构 + CRUD）
/// - lumira-app/src/types/template.ts（CameraParams / ShootKit 类型定义）
///
/// 数据模型说明：
/// - [Kit]：完整 ShootKit 实体（含 overrides / 时间戳 / 使用计数）
///   与 `capture_scene_mock_data.dart` 中的简化 `ShootKit` 不同（后者仅含 4 字段，
///   供 scene-manage Tab 3 列表展示用）。此处 `Kit` 为编辑器页所用完整版本。
/// - [CameraOverrides]：对应 uni-app `Partial<CameraParams>`，仅含 editor.vue
///   实际暴露的 3 个字段（EV / WB(K) / ISO），其余字段不暴露。
class CameraOverrides {
  const CameraOverrides({
    this.exposureCompensation,
    this.whiteBalanceK,
    this.iso,
  });

  /// EV 曝光补偿（-3 ~ 3，step 0.05）。null 表示未覆盖
  final double? exposureCompensation;

  /// 白平衡色温 K（2000 ~ 10000，step 50）。null 表示未覆盖
  final int? whiteBalanceK;

  /// ISO（100 ~ 6400，step 50）。null 表示未覆盖（AUTO）
  final int? iso;

  /// 是否所有参数都未设置（用于判断 overrides 是否为空）
  bool get isEmpty =>
      exposureCompensation == null && whiteBalanceK == null && iso == null;

  /// 是否任意参数已设置（对应 uni-app `hasOverrides` 判断）
  bool get isNotEmpty => !isEmpty;

  CameraOverrides copyWith({
    double? exposureCompensation,
    int? whiteBalanceK,
    int? iso,
    bool clearExposure = false,
    bool clearWb = false,
    bool clearIso = false,
  }) {
    return CameraOverrides(
      exposureCompensation:
          clearExposure ? null : (exposureCompensation ?? this.exposureCompensation),
      whiteBalanceK: clearWb ? null : (whiteBalanceK ?? this.whiteBalanceK),
      iso: clearIso ? null : (iso ?? this.iso),
    );
  }

  static const CameraOverrides empty = CameraOverrides();
}

/// ShootKit 完整实体（对应 uni-app `ShootKit` 类型）
///
/// 字段来源：lumira-app/src/composables/useShootKit.ts
/// 注意：与 `capture_scene_mock_data.dart` 中的简化 `ShootKit` 类不同，
/// 此处 `Kit` 包含 overrides / 时间戳 / 使用计数等完整字段，供编辑器页使用。
class Kit {
  const Kit({
    required this.id,
    required this.name,
    required this.sceneId,
    required this.templateId,
    this.overrides = CameraOverrides.empty,
    required this.createdAt,
    required this.updatedAt,
    this.useCount = 0,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String sceneId;
  final String templateId;
  final CameraOverrides overrides;
  final int createdAt;
  final int updatedAt;
  final int useCount;
  final int? lastUsedAt;

  Kit copyWith({
    String? name,
    String? sceneId,
    String? templateId,
    CameraOverrides? overrides,
    int? updatedAt,
    int? useCount,
    int? lastUsedAt,
  }) {
    return Kit(
      id: id,
      name: name ?? this.name,
      sceneId: sceneId ?? this.sceneId,
      templateId: templateId ?? this.templateId,
      overrides: overrides ?? this.overrides,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

/// ShootKit 编辑器 mock 数据
///
/// 数据来源：
/// - lumira-app/src/composables/useShootKit.ts（CRUD + 持久化逻辑）
/// - lumira-app/src/data/scenePresets.ts（场景列表，复用 CaptureSceneMockData.allScenes）
/// - lumira-app/src/data/templates/index.ts（模板列表，复用 TemplatesMockData.otherTemplates）
///
/// 简化决策（mock 阶段）：
/// - 不接入 localStorage 持久化，内存中维护 kits 列表
/// - createKit / updateKit 直接修改内存 List（由页面 StatefulWidget 持有）
/// - getKitById 提供按 id 查找已有组合的能力（供编辑模式加载）
class ShootKitMockData {
  ShootKitMockData._();

  /// 已有组合列表（mock：1 个，与 capture_scene_mock_data.dart 中 kit_001 对齐）
  ///
  /// 注意：templateId 使用 'street_bw' 以匹配 TemplatesMockData.otherTemplates[0].id，
  /// 这样编辑模式下加载 kit_001 时，模板网格中对应模板会显示选中态。
  static final List<Kit> kits = [
    const Kit(
      id: 'kit_001',
      name: '咖啡馆人像套件',
      sceneId: 'cafe-window',
      templateId: 'street_bw',
      overrides: CameraOverrides(
        exposureCompensation: 0.5,
        whiteBalanceK: 5500,
        iso: 200,
      ),
      createdAt: 1717000000000,
      updatedAt: 1717100000000,
      useCount: 3,
      lastUsedAt: 1717100000000,
    ),
  ];

  /// 按 id 查找组合 — 对应 uni-app `getKitDetail(id, templates).kit`
  static Kit? getKitById(String id) {
    for (final k in kits) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// 创建新组合 — 对应 uni-app `createKit(data)`
  /// 返回新创建的 id（mock：直接修改内存 List）
  static String createKit({
    required String name,
    required String sceneId,
    required String templateId,
    CameraOverrides overrides = CameraOverrides.empty,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'kit_${now}_${name.hashCode.toRadixString(36).substring(0, 6)}';
    kits.insert(
      0,
      Kit(
        id: id,
        name: name,
        sceneId: sceneId,
        templateId: templateId,
        overrides: overrides,
        createdAt: now,
        updatedAt: now,
        useCount: 0,
      ),
    );
    return id;
  }

  /// 更新组合 — 对应 uni-app `updateKit(id, data)`
  static void updateKit(String id, {
    String? name,
    String? sceneId,
    String? templateId,
    CameraOverrides? overrides,
  }) {
    final idx = kits.indexWhere((k) => k.id == id);
    if (idx >= 0) {
      kits[idx] = kits[idx].copyWith(
        name: name,
        sceneId: sceneId,
        templateId: templateId,
        overrides: overrides,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// 重置为初始状态（仅测试用，避免跨用例污染）
  static void reset() {
    kits.clear();
    kits.add(
      const Kit(
        id: 'kit_001',
        name: '咖啡馆人像套件',
        sceneId: 'cafe-window',
        templateId: 'street_bw',
        overrides: CameraOverrides(
          exposureCompensation: 0.5,
          whiteBalanceK: 5500,
          iso: 200,
        ),
        createdAt: 1717000000000,
        updatedAt: 1717100000000,
        useCount: 3,
        lastUsedAt: 1717100000000,
      ),
    );
  }
}
