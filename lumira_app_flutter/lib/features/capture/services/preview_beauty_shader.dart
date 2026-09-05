import 'dart:ui' as ui;

/// 在多个候选 asset 路径中加载 fragment program，返回首个成功者；全部失败返回 null。
///
/// 背景：Flutter 标准工具会把 `pubspec.yaml` `shaders:` 的编译产物（runtime-effect
/// blob，IPLR magic）放到 `flutter_assets/shaders/`，因此 `fromAsset('shaders/x.frag')`
/// 可直接加载。但 OHOS（flutter_ohos + hvigor）工具链把 app 的编译 blob 放到了
/// `flutter_assets/assets/shaders/`（沿用了 pubspec 源相对路径），导致标准路径缺失、
/// 加载抛异常 → shader 加载失败。
///
/// 因此 OHOS 侧需优先用 `assets/shaders/x.frag` 兜底；iOS/Android 无需额外候选。
///
/// 历史注记（2026-09-05）：本文件曾承载 PreviewBeautyShader（OHOS 取景器逐帧
/// 美颜：Ticker 逐帧 RepaintBoundary.toImage → preview_beauty.frag 单 pass），
/// 因 OHOS 上 GPU 读回单帧需数百 ms（快门冻结帧实测 455ms@1.0x）导致取景器
/// 卡顿、且半径-1 磨皮核预览不可感知，方案已整体停用（类已删除）。
/// 正式方案为原生 XComponent 实时渲染（见 docs/future-optimizations.md B3），
/// preview_beauty.frag 资产保留作 B3 算法参考。
Future<ui.FragmentProgram?> loadFragmentProgramFromCandidates(
  List<String> paths,
) async {
  for (final path in paths) {
    try {
      return await ui.FragmentProgram.fromAsset(path);
    } catch (_) {
      // 尝试下一个候选路径
    }
  }
  return null;
}
