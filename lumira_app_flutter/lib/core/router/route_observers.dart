import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/capture/data/capture_state.dart';
import '../../features/capture/services/camera_service_provider.dart';
import 'route_names.dart';

/// 监听路由变化，用于：
/// 1. 页面切换埋点（onPush/onPop/onReplace 记录）
/// 2. 离开拍摄页时清理 template 相关状态（修复 uni-app 的状态残留 bug）
/// 3. 进入特定页面时预热数据
class LumiraRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  LumiraRouteObserver(this._ref);

  final Ref _ref;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(previousRoute, route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handleRouteChange(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null && newRoute != null) {
      _handleRouteChange(oldRoute, newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _handleRouteRemoved(route);
  }

  void _handleRouteChange(Route<dynamic>? from, Route<dynamic>? to) {
    // 关键修复：DropdownButton / showModalBottomSheet / showDialog 等弹出的 PopupRoute
    // 不是 PageRoute，会被 _extractPath 返回 null，从而被误判为"离开拍摄页"，
    // 触发 resetAll 清空 currentTemplateId 等状态，导致页面"重置"。
    // 修复方法：只在 from 和 to 都是 PageRoute 时才判断是否真的离开了拍摄页。
    if (from is! PageRoute || to is! PageRoute) {
      return;
    }

    final fromPath = _extractPath(from);
    final toPath = _extractPath(to);
    final fromCapture = _isCapturePage(fromPath);
    final toCapture = _isCapturePage(toPath);

    // 离开拍摄页（capture/preview/preview-template）到非拍摄页时：
    // 1. 清理模板状态；2. 显式释放相机。
    // 修复 Bug：GoRouter 默认让被覆盖的路由 maintainState（retain 不销毁），
    // 相机由 CameraPreview 内的 CameraAwesomeBuilder 持有，页面仅被覆盖时其 dispose
    // 不会触发 → 退出拍摄页后原生相机一直被占用。这里在路由层面显式释放。
    if (fromCapture && !toCapture) {
      _clearCaptureState();
      _releaseCamera();
      return;
    }

    // 从非拍摄页返回拍摄页：通知拍摄页重建相机预览。
    // 若返回的是被 retain 的旧拍摄页（未销毁），相机已在离开时被释放，
    // 需要用版本号触发其重建 CameraAwesomeBuilder 以恢复取景器。
    if (!fromCapture && toCapture) {
      _renewCamera();
    }
  }

  /// go() 的整栈替换：被替换路由走 didRemove（而非 didPop）。
  /// 若移除的是拍摄页，且替换后栈顶不再是拍摄页，则释放相机并清理状态。
  /// 修复 Bug：退出拍摄页用 context.go(home) 时只触发 didRemove，
  /// 相机不释放导致系统相机一直被占用。
  void _handleRouteRemoved(Route<dynamic> route) {
    if (route is! PageRoute) return;
    if (!_isCapturePage(_extractPath(route))) return;

    // 延迟到微任务：整栈替换完成后读取目标栈栈顶，
    // 避免拍摄页之间 go() 跳转时误释放相机。
    Future.microtask(() {
      final currentName = _currentTopPageName();
      if (!_isCapturePage(currentName)) {
        _clearCaptureState();
        _releaseCamera();
      }
    });
  }

  /// 当前导航栈顶页面名（navigator 的 pages 已反映替换后的目标栈）。
  String? _currentTopPageName() {
    final nav = rootNavigatorKey.currentState;
    final pages = nav?.widget.pages;
    if (pages == null || pages.isEmpty) return null;
    return pages.last.name;
  }

  /// 离开拍摄页时释放相机（CameraService.dispose → CamerawesomePlugin.stop）。
  /// 注意：不关闭服务内的 ready controller，保证再次进入拍摄页时就绪流仍可用。
  void _releaseCamera() {
    Future.microtask(() {
      try {
        _ref.read(cameraServiceProvider).dispose();
      } catch (e) {
        debugPrint('[camera] 路由离开拍摄页释放相机失败: $e');
      }
    });
  }

  /// 返回拍摄页时递增相机续命版本号，触发拍摄页重建相机预览。
  void _renewCamera() {
    Future.microtask(() {
      _ref.read(CaptureState.cameraRenewVersionProvider.notifier).state++;
    });
  }

  String? _extractPath(Route<dynamic>? route) {
    if (route is PageRoute) {
      final settings = route.settings;
      if (settings.name != null) {
        return settings.name;
      }
    }
    return null;
  }

  /// 拍摄页路径与名称集合
  /// go_router 6.5.9 在 GoRoute 设置了 name: 时，settings.name 返回 NAME（如 'capture'）
  /// 而非 PATH（如 '/capture'）。_isCapturePage 同时匹配两者。
  /// 修复 Minor finding #1。
  ///
  /// 除拍摄页本体外，还包含拍摄页常见的「临时子页」——它们是从拍摄页 push 上来、
  /// 用户会返回继续拍摄的页面（如付费模板的详情/解锁页）。这些页面本身不持有相机，
  /// 但从拍摄页进入时并不会「真正离开」，返回后应沿用进入前的全部拍摄参数与朝向；
  /// 因此把它们一并视为 capture 子流，避免触发 resetAll / 释放相机。
  static const _capturePaths = <String>{
    RouteNames.capture,           // '/capture'
    RouteNames.capturePreview,    // '/capture/preview'
    RouteNames.capturePreviewTemplate, // '/capture/preview-template'
    RouteNames.templatesDetail,   // '/templates/detail'（付费模板详情）
    RouteNames.templatesUnlock,   // '/templates/unlock'（付费模板解锁）
  };

  static const _captureNames = <String>{
    'capture',
    'capturePreview',
    'capturePreviewTemplate',
    'templatesDetail',
    'templatesUnlock',
  };

  bool _isCapturePage(String? pathOrName) {
    if (pathOrName == null) return false;
    return _capturePaths.contains(pathOrName) || _captureNames.contains(pathOrName);
  }

  void _clearCaptureState() {
    // 延迟到下一帧执行，避免在 widget tree build 期间修改 provider。
    // didPush 等路由回调在 build 阶段触发，直接调用 resetAll 修改 provider 会抛出
    // "Tried to modify a provider while the widget tree was building" 错误。
    Future.microtask(() => CaptureState.resetAll(_ref.container));
  }
}

/// 全局路由观察者 Provider
final lumiraRouteObserverProvider = Provider<LumiraRouteObserver>((ref) {
  return LumiraRouteObserver(ref);
});
