import 'dart:async';
import 'dart:ui' as ui;

import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/db/database_provider.dart';
import '../domain/photo_template.dart';
import '../domain/scene_preset.dart';
import '../data/template_registry.dart';
import '../data/scene_presets_data.dart';
import '../../templates/services/template_mapper.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../templates/data/templates_providers.dart';
import '../../templates/data/remote_templates_providers.dart';

/// 闪光灯模式
enum CaptureFlashMode { off, on, auto, torch }

/// 拍摄页状态 providers
class CaptureState {
  CaptureState._();

  // ── 已有 providers（保留不变）──
  static final currentTemplateIdProvider = StateProvider<String?>((ref) => null);
  static final flashModeProvider = StateProvider<CaptureFlashMode>((ref) => CaptureFlashMode.off);
  static final isFullscreenProvider = StateProvider<bool>((ref) => false);
  static final showTemplateProvider = StateProvider<bool>((ref) => true);
  static final showSilhouetteProvider = StateProvider<bool>((ref) => true);
  static final lastPhotoPathProvider = StateProvider<String?>((ref) => null);
  static final cameraFacingProvider = StateProvider<String>((ref) => 'back');

  /// 试用模式：付费模板未解锁时通过 ?trial=1 进入。
  /// 仅展示模板效果：隐藏所有参数调整/工具栏、禁用快门、取景器铺水印。
  static final trialModeProvider = StateProvider<bool>((ref) => false);

  // ── 相机引擎状态（由 CameraPreview 通过 onCameraStateCreated 回调注入）──
  // 持有 camerawesome 的 CameraState 引用，用于实现真实拍照/缩放/摄像头切换/闪光灯同步。
  // 测试环境中为 null（cameraPreviewOverrideProvider 注入占位 widget，不创建真实 CameraState）。
  static final cameraStateProvider = StateProvider<CameraState?>((ref) => null);

  /// 当前缩放倍数（真实倍数，1.0 = 1x 无缩放）。由 UI 控件或双指缩放手势更新。
  static final zoomProvider = StateProvider<double>((ref) => 1.0);

  /// UI 显示用的缩放倍数（与 [zoomProvider] 保持一致，用于跨比例切换时保持视觉稳定）。
  static final apparentZoomProvider = StateProvider<double>((ref) => 1.0);

  /// 设备最大缩放倍数（真实倍数），相机就绪时写入，null 表示未查询
  static final deviceMaxZoomProvider = StateProvider<double?>((ref) => null);

  /// 设备最小缩放倍数（真实倍数），相机就绪时写入，null 表示未查询
  static final deviceMinZoomProvider = StateProvider<double?>((ref) => null);

  /// 是否支持超广角（minZoom < 1.0），相机就绪时写入
  static final supportsUltraWideProvider = StateProvider<bool>((ref) => false);

  /// 返回设备支持的缩放倍数范围（真实倍数）。
  /// 优先用查询到的设备值，否则用 fallback。
  static ZoomRange zoomRangeForFacing(String facing) {
    final maxFallback = facing == 'front' ? 2.0 : 10.0;
    return ZoomRange(1.0, maxFallback);
  }

  /// 照片比例（用户可切换）
  /// 'fullscreen' = 与取景器全屏一致（9:16 或 16:9）
  /// '4:3' = 标准 4:3 比例
  /// '1:1' = 正方形
  /// '3:4' = 竖版 3:4
  static final aspectRatioProvider = StateProvider<String>((ref) => 'fullscreen');

  /// 计算目标宽高比（width / height），取景器显示与照片裁剪共用此逻辑以确保一致。
  ///
  /// 返回 null 表示 'fullscreen' 模式（应使用屏幕实际宽高比）。
  /// 方向自适应：'4:3' 在竖屏下显示为 3:4（标准相机 App 行为），
  /// '3:4' 始终为竖版 3:4（即使横屏也显示竖版长条）。
  ///
  /// 支持任意 "W:H" 格式（如 '4:5'、'16:9'、'9:16'、'2:3'），
  /// 用于模板的 cropRatio 字段。'W:H' 始终按字面比例计算（不做方向自适应），
  /// 因为模板的 cropRatio 已经表达了作者期望的最终画面方向。
  static double? computeTargetRatio(String ratioId, bool isPortrait) {
    switch (ratioId) {
      case 'fullscreen':
        return null;
      case '4:3':
        // 标准相机比例，按设备方向自适应：竖屏→3:4，横屏→4:3
        return isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
      case '1:1':
        return 1.0;
      default:
        // 解析任意 "W:H" 格式（如 '4:5'、'16:9'、'9:16'、'2:3'）
        final parts = ratioId.split(':');
        if (parts.length == 2) {
          final w = double.tryParse(parts[0]);
          final h = double.tryParse(parts[1]);
          if (w != null && h != null && w > 0 && h > 0) {
            return w / h;
          }
        }
        return null;
    }
  }

  /// 计算指定比例相对于 4:3 传感器基准的裁切系数。
  ///
  /// 原生相机行为模型（参考 harmonyos 相机缩放比调研）：
  /// - 4:3 = 基准 (1.0x)，传感器全区域输出，无裁切
  /// - 其他比例 = 裁切 + Zoom 补偿，使预览主体大小与原生相机一致
  ///
  /// 裁切系数计算：
  /// - 目标比例 <= 传感器比例（更窄/瘦长）→ 左右裁切，cropFactor = sensorRatio / targetRatio
  /// - 目标比例 > 传感器比例（更宽/扁平）→ 上下裁切，cropFactor = targetRatio / sensorRatio
  ///
  /// 示例（竖屏，传感器 3:4 = 0.75）：
  /// - 4:3 (0.75) → 1.0（基准）
  /// - 1:1 (1.0) → 1.333（上下裁切）
  /// - 全屏 9:19.5 (0.46) → 1.625（左右裁切）
  ///
  /// 此系数用于在切换比例时调整 zoom，始终基于 4:3 = 1.0 基准计算，避免累积漂移。
  static double computeCropFactor(String ratioId, bool isPortrait, double screenRatio) {
    // 传感器物理比例 4:3，竖屏下为 3:4
    final sensorRatio = isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
    final targetRatio = computeTargetRatio(ratioId, isPortrait) ?? screenRatio;

    if (targetRatio <= sensorRatio) {
      // 目标比例比传感器"窄"（更瘦长）→ 左右裁切
      return sensorRatio / targetRatio;
    } else {
      // 目标比例比传感器"宽"（更扁平）→ 上下裁切
      return targetRatio / sensorRatio;
    }
  }

  // ── 新增：模板编辑状态 ──

  /// 所有模板列表（系统 + 自定义 + 后端动态）
  /// 系统模板来自 TemplateRegistry（同步），自定义与远程模板来自 TemplatesDao（异步）。
  /// 远程模板全量同步后仅含 meta（5 段 JSON 为空），此处按需拉取完整内容补全，
  /// 确保 silhouette/pose 等数据在拍摄页可用。
  ///
  /// 通过 `ref.watch(remoteTemplatesSyncProvider)` 建立依赖，当同步完成时自动重新评估，
  /// 确保远程模板出现在列表后模板条可自动刷新。
  /// DAO 加载失败时降级为仅系统模板。
  static final allTemplatesProvider =
      FutureProvider<List<PhotoTemplate>>((ref) async {
    // 建立对远程模板同步的依赖 — 同步完成后自动重新评估，不需要 await
    // 同步本身在 CapturePage.initState 中触发
    ref.watch(remoteTemplatesSyncProvider);

    // 系统模板（同步，立即可用）
    final systemTemplates = TemplateRegistry.allTemplates;

    // 自定义 + 远程模板（异步）
    try {
      final dao = await ref.watch(templatesDaoProvider.future);
      final customAndRemoteRecords = await dao.getCustomAndRemote();
      final customAndRemoteTemplates = <PhotoTemplate>[];
      for (final r in customAndRemoteRecords) {
        try {
          // 远程模板仅含 meta（5 段 JSON 为空）时，按需拉取完整内容
          // 确保 pose（含 silhouette）、composition 等数据在拍摄页可直接使用
          if (r.source == 'remote' &&
              (r.composition.isEmpty || r.pose.isEmpty)) {
            try {
              final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
              final dto = await repo.fetchDetail(r.id);
              final record = TemplateMapper.detailToRecord(dto);
              await dao.upsert(record);
              final refreshed = await dao.getById(r.id);
              if (refreshed != null) {
                customAndRemoteTemplates.add(TemplateMapper.toPhotoTemplate(refreshed));
                continue;
              }
            } catch (e) {
              debugPrint('[capture] allTemplatesProvider: remote detail fetch failed for ${r.id}: $e');
            }
          }
          customAndRemoteTemplates.add(TemplateMapper.toPhotoTemplate(r));
        } catch (e) {
          debugPrint('[capture] allTemplatesProvider: skipping malformed template ${r.id}: $e');
        }
      }
      return [...systemTemplates, ...customAndRemoteTemplates];
    } catch (e) {
      // DAO 不可用时降级为仅系统模板
      debugPrint('[capture] allTemplatesProvider: DAO load failed, fallback to system only: $e');
      return systemTemplates;
    }
  });

  /// 模板缓存（ID → PhotoTemplate）
  /// 从 allTemplatesProvider 结果构建 Map，供 originalTemplateProvider 快速查找
  /// 降级策略：加载中时仅含系统模板
  static final templateCacheProvider =
      Provider<Map<String, PhotoTemplate>>((ref) {
    final asyncValue = ref.watch(allTemplatesProvider);
    // 系统模板始终可用（降级基线）
    final systemMap = {
      for (final t in TemplateRegistry.allTemplates) t.meta.id: t
    };
    return asyncValue.maybeWhen(
      data: (templates) => {
        for (final t in templates) t.meta.id: t
      },
      orElse: () => systemMap,
    );
  });

  /// 排序后的模板列表（按使用频率 + 用户偏好）
  /// 排序优先级：
  /// 1. 使用频率降序（gallery_items 中 template_id 出现次数）
  /// 2. 用户偏好匹配（category == topCategory 优先）
  /// 3. 名称字母序兜底
  static final sortedTemplatesProvider =
      FutureProvider<List<PhotoTemplate>>((ref) async {
    // 获取所有模板（系统 + 自定义）
    final templates = await ref.watch(allTemplatesProvider.future);

    // 获取使用频率
    Map<String, int> usageCounts = {};
    String topCategory = '';
    try {
      final galleryDao = await ref.watch(galleryDaoProvider.future);
      usageCounts = await galleryDao.countByTemplate();

      // 获取用户偏好（用 ref.watch 建立依赖，使偏好变化时触发重排序）
      final pref = await ref.watch(userPreferenceProvider.future);
      topCategory = pref.topCategory;
    } catch (e) {
      // DAO 不可用时降级为无排序（按默认顺序）
      debugPrint('[capture] sortedTemplatesProvider: stats load failed, fallback to unsorted: $e');
      return templates;
    }

    // 排序
    final sorted = List<PhotoTemplate>.from(templates);
    sorted.sort((a, b) {
      final countA = usageCounts[a.meta.id] ?? 0;
      final countB = usageCounts[b.meta.id] ?? 0;
      // 1. 使用频率降序
      if (countA != countB) return countB.compareTo(countA);
      // 2. 用户偏好匹配优先
      final matchA = a.meta.category == topCategory ? 1 : 0;
      final matchB = b.meta.category == topCategory ? 1 : 0;
      if (matchA != matchB) return matchB.compareTo(matchA);
      // 3. 名称字母序兜底
      return a.meta.name.compareTo(b.meta.name);
    });
    return sorted;
  });

  /// 工具栏展示的模板列表：把「当前使用的模板」提到第一位。
  /// 基于 [sortedTemplatesProvider]（使用频率排序）同步派生：
  /// - currentTemplateId 为空 → 直接返回排序列表（自由拍摄）
  /// - 当前模板在列表中 → 移到第一位
  /// - 当前模板不在列表中（如 URL 参数进入且 DAO 未加载）→ 从 [originalTemplateProvider] 解析并前置
  /// 纯同步，切换模板时不会触发异步重排，避免列表闪动。
  static final toolbarTemplatesProvider =
      Provider<List<PhotoTemplate>>((ref) {
    final currentId = ref.watch(currentTemplateIdProvider);
    final sorted = ref.watch(sortedTemplatesProvider).maybeWhen(
          data: (list) => list,
          loading: () => TemplateRegistry.allTemplates,
          error: (_, __) => TemplateRegistry.allTemplates,
          orElse: () => TemplateRegistry.allTemplates,
        );
    if (currentId == null) return sorted;

    final result = List<PhotoTemplate>.from(sorted);
    final index = result.indexWhere((t) => t.meta.id == currentId);
    if (index >= 0) {
      final tpl = result.removeAt(index);
      result.insert(0, tpl);
    } else {
      final original = ref.watch(originalTemplateProvider);
      if (original != null && original.meta.id == currentId) {
        result.insert(0, original);
      }
    }
    return result;
  });

  /// 原始模板（只读，派生自 currentTemplateIdProvider）
  /// 先查 TemplateRegistry（系统模板，同步快路径）
  /// 未找到 → 查 templateCacheProvider（含自定义模板的运行时缓存）
  /// 仍未找到或 silhouette 为空 → 若为远程模板（srv_ 前缀），按需拉取详情
  static final originalTemplateProvider = Provider<PhotoTemplate?>((ref) {
    final id = ref.watch(currentTemplateIdProvider);
    if (id == null) return null;
    // 快路径：系统模板（同步）
    final builtin = TemplateRegistry.getTemplate(id);
    if (builtin != null) return builtin;
    // 慢路径：自定义/远程模板（从预加载缓存读取）
    final cached = ref.watch(templateCacheProvider)[id];
    // 缓存中有完整模板（silhouette 非 none）→ 直接返回
    if (cached != null && cached.pose.silhouette.data != 'none') {
      return cached;
    }
    // 远程模板未在缓存中或 silhouette 为空时，按需拉取详情
    // remoteTemplateDetailProvider 会 fetchDetail → upsert DAO → 返回 PhotoTemplate
    // 拉取完成后此 Provider 自动重新评估（因为 watch 了 family provider）
    if (id.startsWith('srv_')) {
      final asyncDetail = ref.watch(remoteTemplateDetailProvider(id));
      return asyncDetail.maybeWhen(
        data: (tpl) => tpl ?? cached,
        orElse: () => cached,
      );
    }
    return cached;
  });

  /// 可编辑模板副本（参数面板的所有修改都写到这里）
  /// 当 currentTemplateIdProvider 变化时，自动重置为新模板的副本
  /// （StateProvider 的 initializer 在依赖 invalidation 时重新执行）
  static final editableTemplateProvider = StateProvider<PhotoTemplate?>((ref) {
    final original = ref.watch(originalTemplateProvider);
    return original?.copyWith();
  });

  /// applied = editableTemplate 与 originalTemplate 是否完全一致
  /// true 表示用户没有修改任何参数（或已重置）
  static final appliedProvider = Provider<bool>((ref) {
    final original = ref.watch(originalTemplateProvider);
    final editable = ref.watch(editableTemplateProvider);
    if (original == null || editable == null) return false;
    return original == editable;
  });

  // ── 新增：模式开关 ──

  /// 原相机模式（禁用所有滤镜和后期）
  static final rawModeProvider = StateProvider<bool>((ref) => false);

  /// 参数面板展开状态
  static final panelExpandedProvider = StateProvider<bool>((ref) => false);

  /// 滤镜选择器可见状态
  static final filterPickerVisibleProvider = StateProvider<bool>((ref) => false);

  /// 滤镜预览图（取景器实时帧的 ui.Image）
  /// 由 FilterPicker 在抽屉展开时通过 RepaintBoundary 高频捕获并直接存储 ui.Image，
  /// 每张滤镜卡片通过 RawImage 显示，跳过 PNG 编码/解码，实现流畅实时预览。
  static final filterPreviewImageProvider = StateProvider<ui.Image?>((ref) => null);

  /// 底部可折叠面板展开状态
  static final bottomPanelExpandedProvider = StateProvider<bool>((ref) => false);

  // ── 新增：场景 ──

  /// 当前选中的场景预设 ID
  static final activeScenePresetIdProvider = StateProvider<String?>((ref) => null);

  /// 当前场景对应的完整滤镜配方（包含 lut 和 systemFilter）
  /// 由 ScenePresetStrip 选中场景时设置，CameraPreview 通过 watch 应用到取景器
  static final activeSceneFilterProvider =
      Provider<SceneFilter?>((ref) {
    final id = ref.watch(activeScenePresetIdProvider);
    if (id == null) return null;
    final preset = ScenePresetsData.getScenePreset(id);
    return preset?.filter;
  });

  /// 自由拍摄模式下的相机参数（无模板时使用）
  /// 解耦 ParamPanel 与 editableTemplate，使自由模式也能调参
  static final freeModeCameraProvider =
      StateProvider<CameraParams>((ref) => const CameraParams());

  /// 自由拍摄模式下的后期参数（无模板时使用）
  /// 包含色彩、细节、LUT、systemFilter 等所有 postProcess 参数
  static final freeModePostProcessProvider =
      StateProvider<PostProcess>((ref) => const PostProcess(color: PostProcessColor()));

  /// 自由拍摄模式下的构图参数（无模板时使用）
  static final freeModeCompositionProvider =
      StateProvider<Composition>((ref) => const Composition());

  /// 套用模板时顶部的可折叠模板信息卡是否被用户隐藏（持久化到 user_settings）。
  /// true=隐藏；false=显示（默认）。用户点了隐藏后，下次进入拍摄页保持隐藏。
  static final templateInfoCardHiddenProvider = StateProvider<bool>((ref) => false);

  // ── 自由模式参数持久化（防抖写入 DAO）──

  /// 防抖 Timer：参数变更后 500ms 无新变更才写入 DAO
  static Timer? _cameraPersistTimer;
  static Timer? _postProcessPersistTimer;
  static Timer? _compositionPersistTimer;

  /// 从 DAO 加载自由模式参数到对应 provider（拍摄页 initState 调用）
  static Future<void> loadFreeModeParams(ProviderContainer container) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      final camera = await dao.getFreeModeCamera();
      final postProcess = await dao.getFreeModePostProcess();
      final composition = await dao.getFreeModeComposition();
      if (camera != null) {
        container.read(freeModeCameraProvider.notifier).state = camera;
      }
      if (postProcess != null) {
        container.read(freeModePostProcessProvider.notifier).state = postProcess;
      }
      if (composition != null) {
        container.read(freeModeCompositionProvider.notifier).state = composition;
      }
    } catch (e) {
      // 加载失败静默降级，使用默认值
      debugPrint('[capture] loadFreeModeParams failed: $e');
    }
  }

  // ── 拍摄页偏好持久化（前后置摄像头 + 照片比例）──

  /// 从 DAO 加载持久化的拍摄页偏好（前后置摄像头 + 照片比例）到对应 provider。
  /// 必须在相机初始化前调用（capture_page initState），保证首次进入即生效。
  static Future<void> loadCameraPrefs(ProviderContainer container) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      final facing = await dao.getCameraFacing();
      if (facing != null) {
        container.read(cameraFacingProvider.notifier).state = facing;
      }
      final ratio = await dao.getAspectRatio();
      if (ratio != null) {
        container.read(aspectRatioProvider.notifier).state = ratio;
      }
    } catch (e) {
      // 加载失败静默降级，使用默认值
      debugPrint('[capture] loadCameraPrefs failed: $e');
    }
  }

  /// 持久化前后置摄像头选择（用户切换摄像头时调用）
  static Future<void> persistCameraFacing(
    ProviderContainer container,
    String facing,
  ) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      await dao.setCameraFacing(facing);
    } catch (e) {
      // 持久化失败静默，不影响本次拍摄
      debugPrint('[capture] persist camera facing failed: $e');
    }
  }

  /// 持久化照片比例选择（用户手动切换比例时调用）
  static Future<void> persistAspectRatio(
    ProviderContainer container,
    String ratio,
  ) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      await dao.setAspectRatio(ratio);
    } catch (e) {
      // 持久化失败静默，不影响本次拍摄
      debugPrint('[capture] persist aspect ratio failed: $e');
    }
  }

  /// 从 DAO 加载模板信息卡是否被隐藏到 provider（capture_page initState 调用）。
  /// 保证用户上次点了“隐藏”后，下次进入拍摄页时保持隐藏。
  static Future<void> loadTemplateInfoCardPreference(
    ProviderContainer container,
  ) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      final hidden = await dao.getTemplateInfoCardHidden();
      container.read(templateInfoCardHiddenProvider.notifier).state = hidden;
    } catch (e) {
      // 加载失败静默降级，保持默认显示
      debugPrint('[capture] loadTemplateInfoCardPreference failed: $e');
    }
  }

  /// 持久化模板信息卡显示偏好（用户点击隐藏/重新显示时调用）
  static Future<void> persistTemplateInfoCardHidden(
    ProviderContainer container,
    bool hidden,
  ) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      await dao.setTemplateInfoCardHidden(hidden);
    } catch (e) {
      // 持久化失败静默，不影响本次拍摄
      debugPrint('[capture] persist template info card hidden failed: $e');
    }
  }

  /// 防抖持久化相机参数（500ms 内多次变更只写一次）
  static void _scheduleCameraPersist(ProviderContainer container) {
    _cameraPersistTimer?.cancel();
    _cameraPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModeCameraProvider);
        await dao.setFreeModeCamera(value);
      } catch (e) {
        debugPrint('[capture] persist camera failed: $e');
      }
    });
  }

  /// 防抖持久化后期参数
  static void _schedulePostProcessPersist(ProviderContainer container) {
    _postProcessPersistTimer?.cancel();
    _postProcessPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModePostProcessProvider);
        await dao.setFreeModePostProcess(value);
      } catch (e) {
        debugPrint('[capture] persist postProcess failed: $e');
      }
    });
  }

  /// 防抖持久化构图参数
  static void _scheduleCompositionPersist(ProviderContainer container) {
    _compositionPersistTimer?.cancel();
    _compositionPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModeCompositionProvider);
        await dao.setFreeModeComposition(value);
      } catch (e) {
        debugPrint('[capture] persist composition failed: $e');
      }
    });
  }

  /// 统一的可编辑相机参数（无论是否有模板，都返回当前生效的 CameraParams）
  /// ParamPanel 等组件通过此 provider 读取，避免 editable==null 时无法调参
  static final effectiveCameraProvider = Provider<CameraParams>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.camera;
    return ref.watch(freeModeCameraProvider);
  });

  /// 统一的可编辑后期参数（无论是否有模板）
  static final effectivePostProcessProvider = Provider<PostProcess>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.postProcess;
    return ref.watch(freeModePostProcessProvider);
  });

  /// 统一的可编辑构图参数（无论是否有模板）
  static final effectiveCompositionProvider = Provider<Composition>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.composition;
    return ref.watch(freeModeCompositionProvider);
  });

  /// 统一的可编辑场景指南（无论是否有模板，自由模式返回空 SceneGuide）
  static final effectiveSceneGuideProvider = Provider<SceneGuide>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    return editable?.sceneGuide ?? const SceneGuide();
  });

  /// 统一更新相机参数的辅助方法
  /// 有模板时更新 editableTemplate，无模板时更新 freeModeCamera
  static void updateCamera(WidgetRef ref, CameraParams Function(CameraParams) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(camera: updater(editable.camera));
    } else {
      final current = ref.read(freeModeCameraProvider);
      ref.read(freeModeCameraProvider.notifier).state = updater(current);
      _scheduleCameraPersist(
          ProviderScope.containerOf(ref.context, listen: false));
    }
  }

  /// 将场景推荐滤镜套用到当前后期参数。
  /// 有模板时基于 editableTemplate 的 postProcess 叠加，无模板时写 freeModePostProcessProvider。
  /// 供场景条点击 / 场景路由进入两种入口复用，保证「套用场景即自动套用推荐滤镜」。
  static void applySceneFilter(WidgetRef ref, SceneFilter filter) {
    final current = ref.read(freeModePostProcessProvider);
    ref.read(freeModePostProcessProvider.notifier).state = current.copyWith(
      lut: filter.lut,
      systemFilter: filter.systemFilter,
    );
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state = editable.copyWith(
        postProcess: editable.postProcess.copyWith(
          lut: filter.lut,
          systemFilter: filter.systemFilter,
        ),
      );
    }
  }

  /// 统一更新后期参数的辅助方法
  static void updatePostProcess(WidgetRef ref, PostProcess Function(PostProcess) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(postProcess: updater(editable.postProcess));
    } else {
      final current = ref.read(freeModePostProcessProvider);
      ref.read(freeModePostProcessProvider.notifier).state = updater(current);
      _schedulePostProcessPersist(
          ProviderScope.containerOf(ref.context, listen: false));
    }
  }

  /// 统一更新构图参数的辅助方法
  static void updateComposition(WidgetRef ref, Composition Function(Composition) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(composition: updater(editable.composition));
    } else {
      final current = ref.read(freeModeCompositionProvider);
      ref.read(freeModeCompositionProvider.notifier).state = updater(current);
      _scheduleCompositionPersist(
          ProviderScope.containerOf(ref.context, listen: false));
    }
  }

  /// 重置自由模式所有参数为默认值并立即持久化
  static void resetFreeModeParams(WidgetRef ref) {
    ref.read(freeModeCameraProvider.notifier).state = const CameraParams();
    ref.read(freeModePostProcessProvider.notifier).state =
        const PostProcess(color: PostProcessColor());
    ref.read(freeModeCompositionProvider.notifier).state = const Composition();
    _cameraPersistTimer?.cancel();
    _postProcessPersistTimer?.cancel();
    _compositionPersistTimer?.cancel();
    final container = ProviderScope.containerOf(ref.context, listen: false);
    _scheduleCameraPersist(container);
    _schedulePostProcessPersist(container);
    _scheduleCompositionPersist(container);
  }

  // ── 新增：水平仪 ──

  static final levelEnabledProvider = StateProvider<bool>((ref) => true);
  static final levelAngleProvider = StateProvider<double>((ref) => 0.0);

  // ── 新增：工具栏状态 ──

  /// 当前激活的工具栏 tab：null=收起, 'templates'|'scenes'|'params'|'fillLight'
  /// 默认 null：进入拍摄页时抽屉收起，仅显示一排工具栏
  static final activeToolProvider = StateProvider<String?>((ref) => null);

  /// 模板工具抽屉是否展开为「显示更多」大面板（约 60% 页面高度 + 搜索框）。
  /// false = 显示横向模板条（前 10 个 + 显示更多按钮）；true = 展开大面板。
  static final templateDrawerExpandedProvider = StateProvider<bool>((ref) => false);

  // ── 新增：补光（Fill Light）状态 ──

  /// 补光是否启用（默认关闭）
  static final fillLightEnabledProvider = StateProvider<bool>((ref) => false);

  /// 补光颜色（默认暖白 #FFE5B4）
  static final fillLightColorProvider =
      StateProvider<Color>((ref) => const Color(0xFFFFE5B4));

  /// 补光强度 [0.1, 1.5]，默认 0.8（>1.0 时颜色向白色混合，更亮）
  static final fillLightIntensityProvider =
      StateProvider<double>((ref) => 0.8);

  /// 悬浮取景器窗口缩放比例 [0.3, 1.0]，默认 0.5
  /// 补光开启时取景器缩小为悬浮窗口，用户可在控制面板中调整大小
  static final fillLightViewfinderScaleProvider =
      StateProvider<double>((ref) => 0.5);

  /// 悬浮取景器窗口位置偏移（相对于屏幕中心的偏移量）
  /// 用户可拖动窗口调整位置
  static final fillLightViewfinderOffsetProvider =
      StateProvider<Offset>((ref) => Offset.zero);

  /// 统一的补光状态快照，供 PhotoPostProcessor 消费
  /// 当 fillLightEnabled=false 时返回 null
  static final fillLightStateProvider = Provider<FillLightState?>((ref) {
    if (!ref.watch(fillLightEnabledProvider)) return null;
    return FillLightState(
      color: ref.watch(fillLightColorProvider),
      intensity: ref.watch(fillLightIntensityProvider),
    );
  });

  // ── 新增：拍摄组合（内存态，Phase 1 不持久化）──

  static final kitsProvider = StateProvider<List<Object>>((ref) => []);

  /// 重置所有拍摄页状态
  static void resetAll(ProviderContainer container) {
    // 已有
    container.read(currentTemplateIdProvider.notifier).state = null;
    container.read(flashModeProvider.notifier).state = CaptureFlashMode.off;
    container.read(isFullscreenProvider.notifier).state = false;
    container.read(showTemplateProvider.notifier).state = true;
    container.read(showSilhouetteProvider.notifier).state = true;
    container.read(lastPhotoPathProvider.notifier).state = null;
    container.read(cameraFacingProvider.notifier).state = 'back';
    container.read(trialModeProvider.notifier).state = false;
    // 新增
    container.read(rawModeProvider.notifier).state = false;
    container.read(panelExpandedProvider.notifier).state = false;
    container.read(filterPickerVisibleProvider.notifier).state = false;
    container.read(filterPreviewImageProvider.notifier).state = null;
    container.read(bottomPanelExpandedProvider.notifier).state = false;
    container.read(activeScenePresetIdProvider.notifier).state = null;
    container.read(levelEnabledProvider.notifier).state = true;
    container.read(levelAngleProvider.notifier).state = 0.0;
    container.read(kitsProvider.notifier).state = [];
    // 引擎状态与缩放
    container.read(cameraStateProvider.notifier).state = null;
    container.read(zoomProvider.notifier).state = 1.0;
    container.read(apparentZoomProvider.notifier).state = 1.0;
    container.read(aspectRatioProvider.notifier).state = 'fullscreen';
    // 自由模式参数
    container.read(freeModeCameraProvider.notifier).state = const CameraParams();
    container.read(freeModePostProcessProvider.notifier).state =
        const PostProcess(color: PostProcessColor());
    container.read(freeModeCompositionProvider.notifier).state = const Composition();
    // editableTemplateProvider 和 appliedProvider 是派生的，不需要显式重置
    // （当 currentTemplateIdProvider 设为 null 时，originalTemplateProvider 返回 null，
    //  editableTemplateProvider 会自动重置为 null）
    // 工具栏与补光状态
    container.read(activeToolProvider.notifier).state = null;
    container.read(templateDrawerExpandedProvider.notifier).state = false;
    container.read(fillLightEnabledProvider.notifier).state = false;
    container.read(fillLightColorProvider.notifier).state =
        const Color(0xFFFFE5B4);
    container.read(fillLightIntensityProvider.notifier).state = 0.8;
    container.read(fillLightViewfinderScaleProvider.notifier).state = 0.5;
    container.read(fillLightViewfinderOffsetProvider.notifier).state =
        Offset.zero;
  }
}

/// 缩放范围（最小与最大倍数）
class ZoomRange {
  const ZoomRange(this.min, this.max);

  final double min;
  final double max;
}

/// 补光状态快照
/// 由 [CaptureState.fillLightStateProvider] 提供，供 [PhotoPostProcessor] 消费
class FillLightState {
  const FillLightState({required this.color, required this.intensity});

  final Color color;

  /// 强度 [0.1, 1.0]
  final double intensity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FillLightState &&
          runtimeType == other.runtimeType &&
          color.value == other.color.value &&
          intensity == other.intensity;

  @override
  int get hashCode => color.value.hashCode ^ intensity.hashCode;

  @override
  String toString() => 'FillLightState(color=$color, intensity=$intensity)';
}
