import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/capture/data/capture_state.dart';
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

    // 离开拍摄页（capture/preview/preview-template）时清理模板状态
    // 修复 uni-app 中"退出拍摄页后 currentTemplateId 残留影响后续自由拍摄"的 bug
    if (_isCapturePage(fromPath) && !_isCapturePage(toPath)) {
      _clearCaptureState();
    }
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
  static const _capturePaths = <String>{
    RouteNames.capture,           // '/capture'
    RouteNames.capturePreview,    // '/capture/preview'
    RouteNames.capturePreviewTemplate, // '/capture/preview-template'
  };

  static const _captureNames = <String>{
    'capture',
    'capturePreview',
    'capturePreviewTemplate',
  };

  bool _isCapturePage(String? pathOrName) {
    if (pathOrName == null) return false;
    return _capturePaths.contains(pathOrName) || _captureNames.contains(pathOrName);
  }

  void _clearCaptureState() {
    // Forced fix: CaptureState.resetAll 接收 ProviderContainer（见 capture_state.dart 注释）
    CaptureState.resetAll(_ref.container);
  }
}

/// 全局路由观察者 Provider
final lumiraRouteObserverProvider = Provider<LumiraRouteObserver>((ref) {
  return LumiraRouteObserver(ref);
});
