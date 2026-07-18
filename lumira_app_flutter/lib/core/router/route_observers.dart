import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_names.dart';

/// 监听路由变化，用于：
/// 1. 页面切换埋点（onPush/onPop/onReplace 记录）
/// 2. 离开拍摄页时清理 template 相关状态（修复 uni-app 的状态残留 bug）
/// 3. 进入特定页面时预热数据
class LumiraRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  LumiraRouteObserver(this._ref);

  // Task 2.3 将在 _clearCaptureState 中使用 _ref 读取/重置 capture 相关 provider；
  // 当前为 stub，保留字段以避免后续破坏构造签名。
  // ignore: unused_field
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

  bool _isCapturePage(String? path) {
    if (path == null) return false;
    return path == RouteNames.capture ||
        path == RouteNames.capturePreview ||
        path == RouteNames.capturePreviewTemplate;
  }

  void _clearCaptureState() {
    // 后续 Task 2.3 会注入 captureSessionProvider 等 provider 用于清理
    // 当前 stub 仅打印日志，避免引用尚未创建的 provider
    // ignore: avoid_print
    print('[LumiraRouteObserver] Leaving capture page, clearing template state');
  }
}

/// 全局路由观察者 Provider
final lumiraRouteObserverProvider = Provider<LumiraRouteObserver>((ref) {
  return LumiraRouteObserver(ref);
});
