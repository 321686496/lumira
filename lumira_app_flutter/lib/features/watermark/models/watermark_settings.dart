/// 水印管理页布局：list（单列）/ grid（双列）
enum WatermarkManageLayout { list, grid }

/// 水印设置（运行时状态，可由用户在设置页或水印选择页切换）。
///
/// `enabled` 控制总开关；`activeTemplateId` 为当前选中的模板 id（预置或自定义）；
/// `animationEnabled` 控制水印入场动画（后续 UI 任务使用）；
/// `manageLayout` 控制水印管理页布局（单列/双列）。
class WatermarkSettings {
  final bool enabled;
  final String? activeTemplateId;
  final bool animationEnabled;
  final WatermarkManageLayout manageLayout;

  const WatermarkSettings({
    this.enabled = true,
    this.activeTemplateId,
    this.animationEnabled = true,
    this.manageLayout = WatermarkManageLayout.list,
  });

  /// copyWith：传 `clearTemplate: true` 时将 [activeTemplateId] 置为 null。
  WatermarkSettings copyWith({
    bool? enabled,
    String? activeTemplateId,
    bool? animationEnabled,
    WatermarkManageLayout? manageLayout,
    bool clearTemplate = false,
  }) {
    return WatermarkSettings(
      enabled: enabled ?? this.enabled,
      activeTemplateId:
          clearTemplate ? null : (activeTemplateId ?? this.activeTemplateId),
      animationEnabled: animationEnabled ?? this.animationEnabled,
      manageLayout: manageLayout ?? this.manageLayout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'activeTemplateId': activeTemplateId,
      'animationEnabled': animationEnabled,
      'manageLayout': manageLayout.name,
    };
  }

  factory WatermarkSettings.fromJson(Map<String, dynamic> json) {
    return WatermarkSettings(
      enabled: (json['enabled'] as bool?) ?? true,
      activeTemplateId: json['activeTemplateId'] as String?,
      animationEnabled: (json['animationEnabled'] as bool?) ?? true,
      manageLayout: _parseLayout(json['manageLayout'] as String?),
    );
  }

  static WatermarkManageLayout _parseLayout(String? value) {
    switch (value) {
      case 'grid':
        return WatermarkManageLayout.grid;
      case 'list':
      default:
        return WatermarkManageLayout.list;
    }
  }
}
