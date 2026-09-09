import 'dart:ui' as ui;

/// 在多个候选 asset 路径中加载 fragment program，返回首个成功者；全部失败返回 null。
///
/// 背景：`pubspec.yaml` `shaders:` 段声明的路径（本项目为
/// `assets/shaders/x.frag`）会**原样**成为编译产物（runtime-effect blob，
/// IPLR magic）的 asset key——AssetManifest 中即为 `assets/shaders/x.frag`，
/// Flutter 标准工具链（iOS/Android）与 OHOS（flutter_ohos + hvigor）行为一致。
/// 因此候选列表必须首选带 `assets/` 前缀的路径；无前缀的 `shaders/x.frag`
/// 仅作工具链行为变化时的兜底（如旧注释曾误述标准工具链去前缀的行为）。
///
/// 历史注记（2026-09-05）：本文件曾承载 PreviewBeautyShader（OHOS 取景器逐帧
/// 美颜：Ticker 逐帧 RepaintBoundary.toImage → preview_beauty.frag 单 pass），
/// 因 OHOS 上 GPU 读回单帧需数百 ms（快门冻结帧实测 455ms@1.0x）导致取景器
/// 卡顿、且半径-1 磨皮核预览不可感知，方案已整体停用（类已删除）。
/// 正式方案为原生 XComponent 实时渲染（见 docs/future-optimizations.md B3），
/// preview_beauty.frag 资产保留作 B3 算法参考。
///
/// 修复注记（2026-09-09）：此前调用方按平台分支——OHOS 用 `assets/shaders/`
/// 前缀路径（正确），iOS/Android 仅用 `shaders/` 无前缀路径（与 AssetManifest
/// 不符，加载必然失败）→ 编辑页 DetailEffectsLayer 静默回退原图，表现为
/// 「细节栏调整锐化/磨皮/暗角/颗粒无实时变化」。现统一为全平台首选带前缀路径。
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
